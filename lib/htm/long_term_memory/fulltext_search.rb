# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Full-text search using PostgreSQL tsvector and pg_trgm
    #
    # Performs keyword-based search using:
    # - PostgreSQL full-text search (tsvector/tsquery) for stemmed word matching
    # - Trigram fuzzy matching (pg_trgm) for typos and partial words
    # - Combined scoring: tsvector matches rank higher, trigram provides fallback
    #
    # Results are cached for performance.
    #
    # Security: All queries use parameterized placeholders to prevent SQL injection.
    #
    module FulltextSearch
      # Maximum results to prevent DoS via unbounded queries
      MAX_FULLTEXT_LIMIT = 1000

      # Minimum trigram similarity threshold (0.0-1.0)
      # Lower = more fuzzy matches, higher = stricter matching
      TRIGRAM_SIMILARITY_THRESHOLD = 0.1

      # Score boost for tsvector matches over trigram matches
      # Ensures exact word matches rank above fuzzy matches
      TSVECTOR_SCORE_BOOST = 1.0

      # Full-text search
      #
      # @param timeframe [Range] Time range to search
      # @param query [String] Search query
      # @param limit [Integer] Maximum results (capped at MAX_FULLTEXT_LIMIT)
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search_fulltext(timeframe:, query:, limit:, metadata: {})
        # Enforce limit to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_FULLTEXT_LIMIT].min

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = @cache.fetch(:fulltext, timeframe, query, safe_limit, metadata) do
          search_fulltext_uncached(
            timeframe: timeframe,
            query: query,
            limit: safe_limit,
            metadata: metadata
          )
        end
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        HTM::Telemetry.search_latency.record(elapsed_ms, attributes: { 'strategy' => 'fulltext' })
        result
      end

      private

      # Uncached full-text search combining tsvector and trigram matching
      #
      # Uses UNION to combine:
      # 1. tsvector matches (stemmed words, high priority)
      # 2. trigram matches (fuzzy/partial, lower priority fallback)
      #
      # Deduplicates by taking highest score per node.
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
      # @param query [String] Search query
      # @param limit [Integer] Maximum results
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search_fulltext_uncached(timeframe:, query:, limit:, metadata: {})
        # Build filter conditions
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata)

        additional_conditions = []
        additional_conditions << timeframe_condition if timeframe_condition
        additional_conditions << metadata_condition if metadata_condition
        additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

        # Combined tsvector + trigram search
        # tsvector matches get boosted score, trigram provides fuzzy fallback
        # Note: Using ? placeholders for Sequel compatibility
        sql = <<~SQL
          WITH tsvector_matches AS (
            -- Primary: tsvector full-text search (stemmed word matching)
            SELECT id, content, access_count, created_at, token_count,
                   (? + ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?))) as score,
                   'tsvector' as match_type
            FROM nodes
            WHERE deleted_at IS NULL
            AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
            #{additional_sql}
          ),
          trigram_matches AS (
            -- Fallback: trigram fuzzy matching (typos, partial words)
            SELECT id, content, access_count, created_at, token_count,
                   similarity(content, ?) as score,
                   'trigram' as match_type
            FROM nodes
            WHERE deleted_at IS NULL
            AND similarity(content, ?) >= ?
            AND id NOT IN (SELECT id FROM tsvector_matches)
            #{additional_sql}
          ),
          combined AS (
            SELECT * FROM tsvector_matches
            UNION ALL
            SELECT * FROM trigram_matches
          )
          SELECT id, content, access_count, created_at, token_count,
                 MAX(score) as rank, match_type
          FROM combined
          GROUP BY id, content, access_count, created_at, token_count, match_type
          ORDER BY rank DESC
          LIMIT ?
        SQL

        result = HTM.db.fetch(
          sql,
          TSVECTOR_SCORE_BOOST,           # boost for tsvector
          query,                           # query for ts_rank
          query,                           # query for plainto_tsquery
          query,                           # query for similarity (trigram)
          query,                           # query for similarity condition
          TRIGRAM_SIMILARITY_THRESHOLD,    # similarity threshold
          limit                            # limit
        ).all

        # Track access for retrieved nodes
        node_ids = result.map { |r| r[:id] }
        track_access(node_ids)

        # Convert to hash with string keys for compatibility
        result.map { |r| r.transform_keys(&:to_s) }
      end
    end
  end
end
