# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Hybrid search combining full-text and vector similarity
    #
    # Performs combined search using:
    # 1. Full-text search for content matching
    # 2. Tag matching for categorical relevance
    # 3. Vector similarity for semantic ranking
    #
    # Nodes without embeddings are included with a default similarity score,
    # allowing newly created nodes to appear immediately before background
    # jobs complete their embedding generation.
    #
    # Results are cached for performance.
    #
    # Security: All queries use parameterized placeholders to prevent SQL injection.
    #
    module HybridSearch
      # Maximum results to prevent DoS via unbounded queries
      MAX_HYBRID_LIMIT = 1000
      MAX_PREFILTER_LIMIT = 5000

      # Hybrid search (full-text + vector)
      #
      # @param timeframe [Range] Time range to search
      # @param query [String] Search query
      # @param limit [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
      # @param embedding_service [Object] Service to generate embeddings
      # @param prefilter_limit [Integer] Candidates to consider (default: 100, capped at MAX_PREFILTER_LIMIT)
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100, metadata: {})
        # Enforce limits to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_HYBRID_LIMIT].min
        safe_prefilter = [[prefilter_limit.to_i, 1].max, MAX_PREFILTER_LIMIT].min

        @cache.fetch(:hybrid, timeframe, query, safe_limit, safe_prefilter, metadata) do
          search_hybrid_uncached(
            timeframe: timeframe,
            query: query,
            limit: safe_limit,
            embedding_service: embedding_service,
            prefilter_limit: safe_prefilter,
            metadata: metadata
          )
        end
      end

      private

      # Threshold for skipping tag extraction (as ratio of limit)
      # If fulltext returns >= this ratio of requested results, skip expensive tag extraction
      TAG_EXTRACTION_THRESHOLD = 0.5

      # Uncached hybrid search
      #
      # Generates query embedding client-side, then combines:
      # 1. Full-text search for content matching
      # 2. Tag matching for categorical relevance (lazy - skipped if fulltext sufficient)
      # 3. Vector similarity for semantic ranking
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
      # @param query [String] Search query
      # @param limit [Integer] Maximum results
      # @param embedding_service [Object] Service to generate query embedding
      # @param prefilter_limit [Integer] Candidates to consider
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes with similarity and tag_boost scores
      #
      def search_hybrid_uncached(timeframe:, query:, limit:, embedding_service:, prefilter_limit:, metadata: {})
        # Generate query embedding client-side
        query_embedding = embedding_service.embed(query)

        # Validate embedding before use
        unless query_embedding.is_a?(Array) && query_embedding.any?
          HTM.logger.error("Invalid embedding returned from embedding service")
          return []
        end

        # Pad embedding to 2000 dimensions if needed
        padded_embedding = HTM::SqlBuilder.pad_embedding(query_embedding)

        # Sanitize embedding for safe SQL use (validates all values are numeric)
        embedding_str = HTM::SqlBuilder.sanitize_embedding(padded_embedding)

        # Build filter conditions (with table alias for CTEs)
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe, table_alias: 'n')
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata, table_alias: 'n')

        additional_conditions = []
        additional_conditions << timeframe_condition if timeframe_condition
        additional_conditions << metadata_condition if metadata_condition
        additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

        # Same for non-aliased queries
        timeframe_condition_bare = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition_bare = HTM::SqlBuilder.metadata_condition(metadata)

        additional_conditions_bare = []
        additional_conditions_bare << timeframe_condition_bare if timeframe_condition_bare
        additional_conditions_bare << metadata_condition_bare if metadata_condition_bare
        additional_sql_bare = additional_conditions_bare.any? ? "AND #{additional_conditions_bare.join(' AND ')}" : ""

        # OPTIMIZATION: Lazy tag extraction
        # Only extract tags if fulltext results are insufficient.
        # This skips the expensive LLM call (~500-3000ms) when fulltext alone
        # provides enough results.
        fulltext_count = count_fulltext_matches(
          query: query,
          additional_sql_bare: additional_sql_bare,
          limit: prefilter_limit
        )

        # Only call expensive tag extraction if fulltext results are below threshold
        matching_tags = if fulltext_count < (limit * TAG_EXTRACTION_THRESHOLD)
          find_query_matching_tags(query)
        else
          []
        end

        # Build the hybrid query
        # NOTE: Hybrid search includes nodes without embeddings using a default
        # similarity score of 0.5. This allows newly created nodes to appear in
        # search results immediately (via fulltext matching) before their embeddings
        # are generated by background jobs.

        result = if matching_tags.any?
          search_hybrid_with_tags(
            query: query,
            embedding_str: embedding_str,
            matching_tags: matching_tags,
            additional_sql: additional_sql,
            prefilter_limit: prefilter_limit,
            limit: limit
          )
        else
          search_hybrid_without_tags(
            query: query,
            embedding_str: embedding_str,
            additional_sql_bare: additional_sql_bare,
            prefilter_limit: prefilter_limit,
            limit: limit
          )
        end

        # Track access for retrieved nodes
        node_ids = result.map { |r| r['id'] }
        track_access(node_ids)

        result.to_a
      end

      # Count fulltext matches quickly (for lazy tag extraction decision)
      #
      # @param query [String] Search query
      # @param additional_sql_bare [String] Additional SQL conditions
      # @param limit [Integer] Maximum to count up to
      # @return [Integer] Number of fulltext matches (capped at limit)
      #
      def count_fulltext_matches(query:, additional_sql_bare:, limit:)
        sql = <<~SQL
          SELECT COUNT(*) FROM (
            SELECT 1 FROM nodes
            WHERE deleted_at IS NULL
            AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
            #{additional_sql_bare}
            LIMIT ?
          ) AS limited_count
        SQL

        result = ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.sanitize_sql_array([sql, query, limit])
        )
        result.to_i
      end

      # Hybrid search with tag matching
      #
      # Uses parameterized queries and LEFT JOIN for efficient tag boosting.
      #
      # @param query [String] Search query
      # @param embedding_str [String] Sanitized embedding string
      # @param matching_tags [Array<String>] Tags matching the query
      # @param additional_sql [String] Additional SQL conditions
      # @param prefilter_limit [Integer] Candidates to consider
      # @param limit [Integer] Maximum results
      # @return [ActiveRecord::Result] Query results
      #
      def search_hybrid_with_tags(query:, embedding_str:, matching_tags:, additional_sql:, prefilter_limit:, limit:)
        # Build tag placeholders for parameterized query
        tag_placeholders = matching_tags.map { '?' }.join(', ')
        tag_count = matching_tags.length.to_f

        # Use parameterized query with proper placeholder binding
        # LEFT JOIN replaces correlated subquery for O(n) instead of O(n²)
        sql = <<~SQL
          WITH fulltext_candidates AS (
            -- Nodes matching full-text search (with or without embeddings)
            SELECT n.id, n.content, n.access_count, n.created_at, n.token_count, n.embedding
            FROM nodes n
            WHERE n.deleted_at IS NULL
            AND to_tsvector('english', n.content) @@ plainto_tsquery('english', ?)
            #{additional_sql}
            LIMIT ?
          ),
          tag_candidates AS (
            -- Nodes matching relevant tags (with or without embeddings)
            SELECT n.id, n.content, n.access_count, n.created_at, n.token_count, n.embedding
            FROM nodes n
            JOIN node_tags nt ON nt.node_id = n.id
            JOIN tags t ON t.id = nt.tag_id
            WHERE n.deleted_at IS NULL
            AND t.name IN (#{tag_placeholders})
            #{additional_sql}
            LIMIT ?
          ),
          all_candidates AS (
            SELECT * FROM fulltext_candidates
            UNION
            SELECT * FROM tag_candidates
          ),
          tag_counts AS (
            -- Pre-compute tag counts using JOIN instead of correlated subquery
            SELECT nt.node_id, COUNT(DISTINCT t.name)::float AS matched_tags
            FROM node_tags nt
            JOIN tags t ON t.id = nt.tag_id
            WHERE t.name IN (#{tag_placeholders})
            GROUP BY nt.node_id
          ),
          scored AS (
            SELECT
              ac.id, ac.content, ac.access_count, ac.created_at, ac.token_count,
              CASE
                WHEN ac.embedding IS NOT NULL THEN 1 - (ac.embedding <=> ?::vector)
                ELSE 0.5
              END as similarity,
              COALESCE(tc.matched_tags / ?, 0) as tag_boost
            FROM all_candidates ac
            LEFT JOIN tag_counts tc ON tc.node_id = ac.id
          )
          SELECT id, content, access_count, created_at, token_count,
                 similarity, tag_boost,
                 (similarity * 0.7 + tag_boost * 0.3) as combined_score
          FROM scored
          ORDER BY combined_score DESC
          LIMIT ?
        SQL

        # Build parameter array: query, prefilter, tags (first IN), prefilter, tags (second IN), embedding, tag_count, limit
        params = [
          query,
          prefilter_limit,
          *matching_tags,
          prefilter_limit,
          *matching_tags,
          embedding_str,
          tag_count,
          limit
        ]

        ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([sql, *params])
        )
      end

      # Hybrid search without tag matching (fallback)
      #
      # @param query [String] Search query
      # @param embedding_str [String] Sanitized embedding string
      # @param additional_sql_bare [String] Additional SQL conditions (no alias)
      # @param prefilter_limit [Integer] Candidates to consider
      # @param limit [Integer] Maximum results
      # @return [ActiveRecord::Result] Query results
      #
      def search_hybrid_without_tags(query:, embedding_str:, additional_sql_bare:, prefilter_limit:, limit:)
        # No matching tags, fall back to standard hybrid (fulltext + vector)
        # Include nodes without embeddings with a default similarity score
        # Optimized: compute similarity once in CTE, reuse for combined_score
        sql = <<~SQL
          WITH candidates AS (
            SELECT id, content, access_count, created_at, token_count, embedding
            FROM nodes
            WHERE deleted_at IS NULL
            AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
            #{additional_sql_bare}
            LIMIT ?
          ),
          scored AS (
            SELECT id, content, access_count, created_at, token_count,
                   CASE
                     WHEN embedding IS NOT NULL THEN 1 - (embedding <=> ?::vector)
                     ELSE 0.5
                   END as similarity
            FROM candidates
          )
          SELECT id, content, access_count, created_at, token_count,
                 similarity,
                 0.0 as tag_boost,
                 similarity as combined_score
          FROM scored
          ORDER BY combined_score DESC
          LIMIT ?
        SQL

        ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([
            sql,
            query,
            prefilter_limit,
            embedding_str,
            limit
          ])
        )
      end
    end
  end
end
