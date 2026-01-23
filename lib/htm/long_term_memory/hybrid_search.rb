# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Hybrid search using Reciprocal Rank Fusion (RRF)
    #
    # Performs three independent searches and merges results:
    # 1. Vector similarity search for semantic matching
    # 2. Full-text search for keyword matching
    # 3. Tag-based search for hierarchical category matching
    #
    # Results are merged using RRF scoring. Nodes appearing in multiple
    # searches receive boosted scores, making them rank higher.
    #
    # Tag scoring uses hierarchical depth matching - the more levels of a
    # tag hierarchy that match, the higher the score contribution.
    #
    # RRF Formula: score = Σ 1/(k + rank) for each search where node appears
    #
    # Results are cached for performance.
    #
    # Security: All queries use parameterized placeholders to prevent SQL injection.
    #
    module HybridSearch
      # Maximum results to prevent DoS via unbounded queries
      MAX_HYBRID_LIMIT = 1000

      # RRF constant - higher values reduce the impact of rank differences
      # 60 is the standard value from the original RRF paper
      RRF_K = 60

      # Multiplier for candidates from each search
      # We fetch more candidates than requested to ensure good fusion
      CANDIDATE_MULTIPLIER = 3

      # Hybrid search using Reciprocal Rank Fusion
      #
      # @param timeframe [Range] Time range to search
      # @param query [String] Search query
      # @param limit [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
      # @param embedding_service [Object] Service to generate embeddings
      # @param prefilter_limit [Integer] Candidates per search (default: 100)
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100, metadata: {})
        # Enforce limits to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_HYBRID_LIMIT].min
        safe_prefilter = [prefilter_limit.to_i, 1].max

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = @cache.fetch(:hybrid, timeframe, query, safe_limit, safe_prefilter, metadata) do
          search_hybrid_rrf(
            timeframe: timeframe,
            query: query,
            limit: safe_limit,
            embedding_service: embedding_service,
            candidate_limit: safe_prefilter * CANDIDATE_MULTIPLIER,
            metadata: metadata
          )
        end
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        HTM::Telemetry.search_latency.record(elapsed_ms, attributes: { 'strategy' => 'hybrid' })
        result
      end

      private

      # Hybrid search using Reciprocal Rank Fusion
      #
      # Runs vector, fulltext, and tag searches independently, then merges
      # results using RRF scoring. Nodes appearing in multiple searches
      # get contributions from each, naturally boosting them.
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search
      # @param query [String] Search query
      # @param limit [Integer] Maximum results
      # @param embedding_service [Object] Service to generate query embedding
      # @param candidate_limit [Integer] Candidates to fetch from each search
      # @param metadata [Hash] Filter by metadata fields
      # @return [Array<Hash>] Merged results with RRF scores
      #
      def search_hybrid_rrf(timeframe:, query:, limit:, embedding_service:, candidate_limit:, metadata: {})
        # Run all three searches independently
        vector_results = fetch_vector_candidates(
          query: query,
          embedding_service: embedding_service,
          timeframe: timeframe,
          metadata: metadata,
          limit: candidate_limit
        )

        fulltext_results = fetch_fulltext_candidates(
          query: query,
          timeframe: timeframe,
          metadata: metadata,
          limit: candidate_limit
        )

        # Extract tags from query and find matching nodes
        tag_results = fetch_tag_candidates(
          query: query,
          timeframe: timeframe,
          metadata: metadata,
          limit: candidate_limit
        )

        # Merge using RRF
        merged = merge_with_rrf(vector_results, fulltext_results, tag_results)

        # Take top results
        top_results = merged.first(limit)

        # Track access for retrieved nodes
        node_ids = top_results.map { |r| r['id'] }
        track_access(node_ids)

        top_results
      end

      # Fetch candidates using vector similarity search
      #
      # @param query [String] Search query
      # @param embedding_service [Object] Service to generate embeddings
      # @param timeframe [nil, Range, Array<Range>] Time filter
      # @param metadata [Hash] Metadata filter
      # @param limit [Integer] Maximum candidates
      # @return [Array<Hash>] Results with similarity scores
      #
      def fetch_vector_candidates(query:, embedding_service:, timeframe:, metadata:, limit:)
        # Generate query embedding
        query_embedding = embedding_service.embed(query)

        unless query_embedding.is_a?(Array) && query_embedding.any?
          HTM.logger.error("Invalid embedding returned from embedding service")
          return []
        end

        padded_embedding = HTM::SqlBuilder.pad_embedding(query_embedding)
        embedding_str = HTM::SqlBuilder.sanitize_embedding(padded_embedding)

        # Build filter conditions
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata)

        conditions = ["embedding IS NOT NULL", "deleted_at IS NULL"]
        conditions << timeframe_condition if timeframe_condition
        conditions << metadata_condition if metadata_condition

        where_clause = "WHERE #{conditions.join(' AND ')}"

        # Note: Using Sequel.lit for the vector comparison since it needs special handling
        embedding_literal = HTM.db.literal(embedding_str)
        sql = <<~SQL
          SELECT id, content, access_count, created_at, token_count,
                 1 - (embedding <=> #{embedding_literal}::vector) as similarity
          FROM nodes
          #{where_clause}
          ORDER BY embedding <=> #{embedding_literal}::vector
          LIMIT ?
        SQL

        HTM.db.fetch(sql, limit).all.map { |r| r.transform_keys(&:to_s) }
      end

      # Fetch candidates using full-text search
      #
      # @param query [String] Search query
      # @param timeframe [nil, Range, Array<Range>] Time filter
      # @param metadata [Hash] Metadata filter
      # @param limit [Integer] Maximum candidates
      # @return [Array<Hash>] Results with text rank scores
      #
      def fetch_fulltext_candidates(query:, timeframe:, metadata:, limit:)
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata)

        additional_conditions = []
        additional_conditions << timeframe_condition if timeframe_condition
        additional_conditions << metadata_condition if metadata_condition
        additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

        # Combined tsvector + trigram search (same as fulltext_search.rb)
        # Escape the query for safe interpolation in trigram comparisons
        query_literal = HTM.db.literal(query)
        sql = <<~SQL
          WITH tsvector_matches AS (
            SELECT id, content, access_count, created_at, token_count,
                   (1.0 + ts_rank(to_tsvector('english', content), plainto_tsquery('english', #{query_literal}))) as text_rank
            FROM nodes
            WHERE deleted_at IS NULL
            AND to_tsvector('english', content) @@ plainto_tsquery('english', #{query_literal})
            #{additional_sql}
          ),
          trigram_matches AS (
            SELECT id, content, access_count, created_at, token_count,
                   similarity(content, #{query_literal}) as text_rank
            FROM nodes
            WHERE deleted_at IS NULL
            AND similarity(content, #{query_literal}) >= 0.1
            AND id NOT IN (SELECT id FROM tsvector_matches)
            #{additional_sql}
          ),
          combined AS (
            SELECT * FROM tsvector_matches
            UNION ALL
            SELECT * FROM trigram_matches
          )
          SELECT id, content, access_count, created_at, token_count, text_rank
          FROM combined
          ORDER BY text_rank DESC
          LIMIT ?
        SQL

        HTM.db.fetch(sql, limit).all.map { |r| r.transform_keys(&:to_s) }
      end

      # Fetch candidates using tag-based search with hierarchical scoring
      #
      # Extracts tags from the query, finds nodes with matching tags,
      # and scores based on hierarchical depth match.
      #
      # Scoring: For a query tag "database:postgresql:extensions" (3 levels):
      # - Node with "database:postgresql:extensions" = 3/3 = 1.0
      # - Node with "database:postgresql" = 2/3 = 0.67
      # - Node with "database" = 1/3 = 0.33
      #
      # @param query [String] Search query
      # @param timeframe [nil, Range, Array<Range>] Time filter
      # @param metadata [Hash] Metadata filter
      # @param limit [Integer] Maximum candidates
      # @return [Array<Hash>] Results with tag_depth_score
      #
      def fetch_tag_candidates(query:, timeframe:, metadata:, limit:)
        # Extract tags from query using the existing tag extraction infrastructure
        tag_extraction = find_query_matching_tags(query, include_extracted: true)
        extracted_tags = tag_extraction[:extracted] || []
        matched_db_tags = tag_extraction[:matched] || []

        return [] if extracted_tags.empty? && matched_db_tags.empty?

        # Build a map of tag prefixes to their max depth
        # This allows us to score partial matches
        tag_depth_map = build_tag_depth_map(extracted_tags)

        # Use matched_db_tags if available, otherwise use extracted_tags
        search_tags = matched_db_tags.any? ? matched_db_tags : extracted_tags

        return [] if search_tags.empty?

        # Build filter conditions
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe, table_alias: 'n')
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata, table_alias: 'n')

        additional_conditions = []
        additional_conditions << timeframe_condition if timeframe_condition
        additional_conditions << metadata_condition if metadata_condition
        additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

        # Find nodes with matching tags
        # Use Sequel's literal to safely quote tag names
        tag_literals = search_tags.map { |tag| HTM.db.literal(tag) }.join(', ')

        sql = <<~SQL
          SELECT DISTINCT n.id, n.content, n.access_count, n.created_at, n.token_count,
                 array_agg(t.name) as matched_tags
          FROM nodes n
          JOIN node_tags nt ON nt.node_id = n.id
          JOIN tags t ON t.id = nt.tag_id
          WHERE n.deleted_at IS NULL
          AND t.name IN (#{tag_literals})
          #{additional_sql}
          GROUP BY n.id, n.content, n.access_count, n.created_at, n.token_count
          LIMIT ?
        SQL

        results = HTM.db.fetch(sql, limit).all

        # Calculate depth scores for each result
        results.map do |result|
          matched_tags = parse_pg_array(result[:matched_tags])
          depth_score = calculate_tag_depth_score(matched_tags, tag_depth_map)

          result.transform_keys(&:to_s).merge('tag_depth_score' => depth_score, 'matched_tags' => matched_tags)
        end.sort_by { |r| -r['tag_depth_score'] }
      end

      # Build a map of tag prefixes to their depth information
      #
      # For tag "database:postgresql:extensions":
      # - "database" => { depth: 1, max_depth: 3 }
      # - "database:postgresql" => { depth: 2, max_depth: 3 }
      # - "database:postgresql:extensions" => { depth: 3, max_depth: 3 }
      #
      # @param extracted_tags [Array<String>] Tags extracted from query
      # @return [Hash] Map of tag/prefix to depth info
      #
      def build_tag_depth_map(extracted_tags)
        depth_map = {}

        extracted_tags.each do |tag|
          levels = tag.split(':')
          max_depth = levels.size

          # Add entry for each prefix level
          (1..max_depth).each do |depth|
            prefix = levels[0, depth].join(':')
            # Keep the highest max_depth if prefix appears in multiple tags
            if !depth_map.key?(prefix) || depth_map[prefix][:max_depth] < max_depth
              depth_map[prefix] = { depth: depth, max_depth: max_depth }
            end
          end
        end

        depth_map
      end

      # Calculate depth score for a node's matched tags
      #
      # The score is based on how deeply the matched tags align with
      # the extracted query tags. More levels matched = higher score.
      #
      # @param matched_tags [Array<String>] Tags the node has that matched
      # @param tag_depth_map [Hash] Map of tag/prefix to depth info
      # @return [Float] Normalized score (0.0 to 1.0)
      #
      def calculate_tag_depth_score(matched_tags, tag_depth_map)
        return 0.0 if matched_tags.empty? || tag_depth_map.empty?

        # Find the best depth match for each matched tag
        best_score = 0.0

        matched_tags.each do |tag|
          if tag_depth_map.key?(tag)
            info = tag_depth_map[tag]
            # Score is depth / max_depth
            # e.g., "database:postgresql" matching query "database:postgresql:extensions"
            # gives 2/3 = 0.67
            score = info[:depth].to_f / info[:max_depth].to_f
            best_score = [best_score, score].max
          else
            # Check if this tag is a parent of any extracted tag
            tag_depth_map.each do |prefix, info|
              if prefix.start_with?(tag + ':') || prefix == tag
                score = tag.split(':').size.to_f / info[:max_depth].to_f
                best_score = [best_score, score].max
              end
            end
          end
        end

        # Bonus for multiple tag matches (capped at 0.2 extra)
        multi_match_bonus = [(matched_tags.size - 1) * 0.05, 0.2].min

        [best_score + multi_match_bonus, 1.0].min
      end

      # Parse PostgreSQL array string to Ruby array
      #
      # @param pg_array [String, Array, Sequel::Postgres::PGArray] PostgreSQL array or Ruby array
      # @return [Array<String>] Parsed array
      #
      def parse_pg_array(pg_array)
        # Handle Sequel::Postgres::PGArray (wraps Ruby Array)
        return pg_array.to_a if pg_array.respond_to?(:to_a) && !pg_array.is_a?(String)
        return pg_array if pg_array.is_a?(Array)
        return [] if pg_array.nil? || (pg_array.respond_to?(:empty?) && pg_array.empty?)

        # Handle raw PostgreSQL array format: {val1,val2,val3}
        pg_str = pg_array.to_s
        if pg_str.start_with?('{') && pg_str.end_with?('}')
          pg_str[1..-2].split(',').map { |s| s.gsub(/^"|"$/, '') }
        else
          [pg_str]
        end
      end

      # Merge three result sets using Reciprocal Rank Fusion
      #
      # RRF score = Σ 1/(k + rank) for each list where the item appears
      #
      # Items appearing in multiple lists naturally get higher scores
      # because they receive contributions from multiple ranks.
      #
      # @param vector_results [Array<Hash>] Vector search results (ordered by similarity)
      # @param fulltext_results [Array<Hash>] Fulltext search results (ordered by text_rank)
      # @param tag_results [Array<Hash>] Tag search results (ordered by tag_depth_score)
      # @return [Array<Hash>] Merged results sorted by RRF score
      #
      def merge_with_rrf(vector_results, fulltext_results, tag_results = [])
        # Build RRF scores
        # Key: node_id, Value: { node_data:, rrf_score:, sources: }
        merged = {}

        # Process vector results
        vector_results.each_with_index do |result, index|
          id = result['id']
          rank = index + 1  # 1-based rank
          rrf_contribution = 1.0 / (RRF_K + rank)

          merged[id] = {
            'id' => result['id'],
            'content' => result['content'],
            'access_count' => result['access_count'],
            'created_at' => result['created_at'],
            'token_count' => result['token_count'],
            'similarity' => result['similarity'],
            'text_rank' => 0.0,
            'tag_depth_score' => 0.0,
            'matched_tags' => [],
            'rrf_score' => rrf_contribution,
            'vector_rank' => rank,
            'fulltext_rank' => nil,
            'tag_rank' => nil,
            'sources' => ['vector']
          }
        end

        # Process fulltext results
        fulltext_results.each_with_index do |result, index|
          id = result['id']
          rank = index + 1  # 1-based rank
          rrf_contribution = 1.0 / (RRF_K + rank)

          if merged.key?(id)
            # Node appears in both - add RRF contribution (this is the boost!)
            merged[id]['rrf_score'] += rrf_contribution
            merged[id]['text_rank'] = result['text_rank']
            merged[id]['fulltext_rank'] = rank
            merged[id]['sources'] << 'fulltext'
          else
            # Node only in fulltext
            merged[id] = {
              'id' => result['id'],
              'content' => result['content'],
              'access_count' => result['access_count'],
              'created_at' => result['created_at'],
              'token_count' => result['token_count'],
              'similarity' => 0.0,
              'text_rank' => result['text_rank'],
              'tag_depth_score' => 0.0,
              'matched_tags' => [],
              'rrf_score' => rrf_contribution,
              'vector_rank' => nil,
              'fulltext_rank' => rank,
              'tag_rank' => nil,
              'sources' => ['fulltext']
            }
          end
        end

        # Process tag results
        tag_results.each_with_index do |result, index|
          id = result['id']
          rank = index + 1  # 1-based rank
          rrf_contribution = 1.0 / (RRF_K + rank)

          if merged.key?(id)
            # Node already found - add RRF contribution (boost!)
            merged[id]['rrf_score'] += rrf_contribution
            merged[id]['tag_depth_score'] = result['tag_depth_score']
            merged[id]['matched_tags'] = result['matched_tags']
            merged[id]['tag_rank'] = rank
            merged[id]['sources'] << 'tags'
          else
            # Node only found via tags
            merged[id] = {
              'id' => result['id'],
              'content' => result['content'],
              'access_count' => result['access_count'],
              'created_at' => result['created_at'],
              'token_count' => result['token_count'],
              'similarity' => 0.0,
              'text_rank' => 0.0,
              'tag_depth_score' => result['tag_depth_score'],
              'matched_tags' => result['matched_tags'],
              'rrf_score' => rrf_contribution,
              'vector_rank' => nil,
              'fulltext_rank' => nil,
              'tag_rank' => rank,
              'sources' => ['tags']
            }
          end
        end

        # Sort by RRF score descending
        merged.values.sort_by { |r| -r['rrf_score'] }
      end
    end
  end
end
