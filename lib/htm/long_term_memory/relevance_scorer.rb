# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Relevance scoring for search results
    #
    # Combines multiple signals to calculate dynamic relevance:
    # - Vector similarity (semantic match) - config.relevance_semantic_weight (default: 0.5)
    # - Tag overlap (categorical match) - config.relevance_tag_weight (default: 0.3)
    # - Recency (freshness) - config.relevance_recency_weight (default: 0.1)
    # - Access frequency (popularity/utility) - config.relevance_access_weight (default: 0.1)
    #
    # Recency decay uses configurable half-life: config.relevance_recency_half_life_hours (default: 168 = 1 week)
    #
    # Also provides tag similarity calculations using hierarchical Jaccard.
    #
    module RelevanceScorer
      # Default score when signal is unavailable
      DEFAULT_NEUTRAL_SCORE = 0.5

      # Access frequency normalization
      ACCESS_SCORE_NORMALIZER = 10.0

      # Final score scaling
      RELEVANCE_SCALE = 10.0
      RELEVANCE_MIN = 0.0
      RELEVANCE_MAX = 10.0

      # Configurable scoring weights (via HTM.configuration)
      def weight_semantic
        HTM.configuration.relevance_semantic_weight
      end

      def weight_tag
        HTM.configuration.relevance_tag_weight
      end

      def weight_recency
        HTM.configuration.relevance_recency_weight
      end

      def weight_access
        HTM.configuration.relevance_access_weight
      end

      def recency_half_life_hours
        HTM.configuration.relevance_recency_half_life_hours
      end

      # Calculate dynamic relevance score for a node given query context
      #
      # @param node [Hash] Node data with similarity, tags, created_at, access_count
      # @param query_tags [Array<String>] Tags associated with the query
      # @param vector_similarity [Float, nil] Pre-computed vector similarity (0-1)
      # @param node_tags [Array<String>, nil] Pre-loaded tags for this node (avoids N+1 query)
      # @return [Float] Composite relevance score (RELEVANCE_MIN to RELEVANCE_MAX)
      #
      def calculate_relevance(node:, query_tags: [], vector_similarity: nil, node_tags: nil)
        # 1. Vector similarity (semantic match)
        semantic_score = if vector_similarity
          vector_similarity
        elsif node['similarity']
          node['similarity'].to_f
        else
          DEFAULT_NEUTRAL_SCORE  # Neutral if no embedding
        end

        # 2. Tag overlap (categorical relevance)
        # Use pre-loaded tags if provided, otherwise fetch (for backward compatibility)
        node_tags ||= get_node_tags(node['id'])
        tag_score = if query_tags.any? && node_tags.any?
          weighted_hierarchical_jaccard(query_tags, node_tags)
        else
          DEFAULT_NEUTRAL_SCORE  # Neutral if no tags
        end

        # 3. Recency (temporal relevance) - exponential decay with half-life
        age_hours = (Time.now - Time.parse(node['created_at'].to_s)) / 3600.0
        recency_score = Math.exp(-age_hours / recency_half_life_hours)

        # 4. Access frequency (behavioral signal) - log-normalized
        access_count = node['access_count'] || 0
        access_score = Math.log(1 + access_count) / ACCESS_SCORE_NORMALIZER

        # Weighted composite with final scaling
        relevance = (
          (semantic_score * weight_semantic) +
          (tag_score * weight_tag) +
          (recency_score * weight_recency) +
          (access_score * weight_access)
        ) * RELEVANCE_SCALE

        relevance.clamp(RELEVANCE_MIN, RELEVANCE_MAX)
      end

      # Search with dynamic relevance scoring
      #
      # Returns nodes with calculated relevance scores based on query context
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
      # @param query [String, nil] Search query
      # @param query_tags [Array<String>] Tags to match
      # @param limit [Integer] Maximum results
      # @param embedding_service [Object, nil] Service to generate embeddings
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Nodes with relevance scores
      #
      def search_with_relevance(timeframe:, query: nil, query_tags: [], limit: 20, embedding_service: nil, metadata: {})
        # Get candidates from appropriate search method
        candidates = if query && embedding_service
          # Vector search (returns hashes directly)
          search_uncached(timeframe: timeframe, query: query, limit: limit * 2, embedding_service: embedding_service, metadata: metadata)
        elsif query
          # Full-text search (returns hashes directly)
          search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit * 2, metadata: metadata)
        else
          # Time-range only - use raw SQL to avoid ORM object instantiation
          # This is more efficient than .map(&:attributes) which creates intermediate objects
          fetch_candidates_by_timeframe(timeframe: timeframe, metadata: metadata, limit: limit * 2)
        end

        # Batch load all tags for candidates (fixes N+1 query)
        node_ids = candidates.map { |n| n['id'] }
        tags_by_node = batch_load_node_tags(node_ids)

        # Calculate relevance for each candidate, building final hash in-place
        scored_nodes = candidates.map do |node|
          node_tags = tags_by_node[node['id']] || []

          relevance = calculate_relevance(
            node: node,
            query_tags: query_tags,
            vector_similarity: node['similarity']&.to_f,
            node_tags: node_tags
          )

          # Modify in-place to avoid creating new Hash
          node['relevance'] = relevance
          node['tags'] = node_tags
          node
        end

        # Sort by relevance and return top K
        scored_nodes
          .sort_by { |n| -n['relevance'] }
          .take(limit)
      end

      # Fetch candidates by timeframe using raw SQL (avoids ORM overhead)
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search
      # @param metadata [Hash] Filter by metadata fields
      # @param limit [Integer] Maximum results
      # @return [Array<Hash>] Candidate nodes as hashes
      #
      def fetch_candidates_by_timeframe(timeframe:, metadata:, limit:)
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata)

        conditions = ['deleted_at IS NULL']
        conditions << timeframe_condition if timeframe_condition
        conditions << metadata_condition if metadata_condition

        sql = <<~SQL
          SELECT id, content, access_count, created_at, token_count
          FROM nodes
          WHERE #{conditions.join(' AND ')}
          ORDER BY created_at DESC
          LIMIT $1
        SQL

        HTM.db.fetch(sql, limit).all.map { |r| r.transform_keys(&:to_s) }
      end

      # Search nodes by tags
      #
      # @param tags [Array<String>] Tags to search for
      # @param match_all [Boolean] If true, match ALL tags; if false, match ANY tag
      # @param timeframe [Range, nil] Optional time range filter
      # @param limit [Integer] Maximum results
      # @return [Array<Hash>] Matching nodes with relevance scores
      #
      def search_by_tags(tags:, match_all: false, timeframe: nil, limit: 20)
        return [] if tags.empty?

        # Build base query with specific columns to avoid loading unnecessary data
        query = HTM::Models::Node
          .select(
            Sequel[:nodes][:id],
            Sequel[:nodes][:content],
            Sequel[:nodes][:access_count],
            Sequel[:nodes][:created_at],
            Sequel[:nodes][:token_count]
          )
          .join(:node_tags, node_id: :id)
          .join(:tags, id: Sequel[:node_tags][:tag_id])
          .where(Sequel[:tags][:name] => tags)
          .distinct

        # Apply timeframe filter if provided
        query = query.where(Sequel[:nodes][:created_at] => timeframe) if timeframe

        if match_all
          # Match ALL tags (intersection)
          query = query
            .group(Sequel[:nodes][:id])
            .having { Sequel.function(:count, Sequel[:tags][:name].distinct) =~ tags.size }
        end

        # Fetch and convert to hashes with string keys
        nodes = query.limit(limit).all.map do |row|
          {
            'id' => row[:id],
            'content' => row[:content],
            'access_count' => row[:access_count],
            'created_at' => row[:created_at],
            'token_count' => row[:token_count]
          }
        end

        # Batch load all tags for nodes (fixes N+1 query)
        node_ids = nodes.map { |n| n['id'] }
        tags_by_node = batch_load_node_tags(node_ids)

        # Calculate relevance and enrich with tags (modify in-place)
        nodes.map do |node|
          node_tags = tags_by_node[node['id']] || []
          relevance = calculate_relevance(
            node: node,
            query_tags: tags,
            node_tags: node_tags
          )

          node['relevance'] = relevance
          node['tags'] = node_tags
          node
        end.sort_by { |n| -n['relevance'] }
      end

      private

      # Calculate Jaccard similarity between two sets
      #
      # @param set_a [Array] First set
      # @param set_b [Array] Second set
      # @return [Float] Jaccard similarity (0.0-1.0)
      #
      def jaccard_similarity(set_a, set_b)
        return 0.0 if set_a.empty? && set_b.empty?
        return 0.0 if set_a.empty? || set_b.empty?

        intersection = (set_a & set_b).size
        union = (set_a | set_b).size

        intersection.to_f / union
      end

      # Calculate weighted hierarchical Jaccard similarity
      #
      # Compares hierarchical tags accounting for partial matches at different levels.
      # Optimized to pre-compute tag hierarchies and use early termination.
      #
      # Performance: O(n*m) where n,m are tag counts, but with:
      # - Pre-computed splits to avoid repeated String#split
      # - Early termination when root categories don't match
      # - Set-based exact match fast path
      #
      # @param set_a [Array<String>] First set of hierarchical tags
      # @param set_b [Array<String>] Second set of hierarchical tags
      # @return [Float] Weighted similarity (0.0-1.0)
      #
      def weighted_hierarchical_jaccard(set_a, set_b)
        return 0.0 if set_a.empty? || set_b.empty?

        # Fast path: check for exact matches first
        exact_matches = (set_a & set_b).size
        return 1.0 if exact_matches == set_a.size && exact_matches == set_b.size

        # Pre-compute tag hierarchies to avoid repeated String#split
        hierarchies_a = set_a.map { |tag| tag.split(':') }
        hierarchies_b = set_b.map { |tag| tag.split(':') }

        # Build root category index for early termination optimization
        # Group tags by their root category for faster matching
        roots_b = hierarchies_b.group_by(&:first)

        total_weighted_similarity = 0.0
        total_weights = 0.0

        hierarchies_a.each do |parts_a|
          root_a = parts_a.first

          # Only compare with tags that share the same root category
          matching_hierarchies = roots_b[root_a] || []

          # Also include all hierarchies if no root match (for cross-category comparison)
          candidates = matching_hierarchies.empty? ? hierarchies_b : matching_hierarchies

          candidates.each do |parts_b|
            similarity, weight = calculate_hierarchical_similarity_cached(parts_a, parts_b)
            total_weighted_similarity += similarity * weight
            total_weights += weight
          end

          # Add zero-similarity weight for non-matching root categories
          (hierarchies_b.size - candidates.size).times do
            # Non-matching roots contribute weight but zero similarity
            total_weights += 0.5  # Average weight for non-matches
          end
        end

        total_weights > 0 ? total_weighted_similarity / total_weights : 0.0
      end

      # Calculate similarity between two pre-split hierarchical tags
      #
      # Optimized version that takes pre-split arrays to avoid redundant splits.
      #
      # @param parts_a [Array<String>] First tag hierarchy (pre-split)
      # @param parts_b [Array<String>] Second tag hierarchy (pre-split)
      # @return [Array<Float, Float>] [similarity, weight] both in range 0.0-1.0
      #
      def calculate_hierarchical_similarity_cached(parts_a, parts_b)
        # Calculate overlap at each level using zip for efficiency
        max_depth = [parts_a.length, parts_b.length].max
        min_depth = [parts_a.length, parts_b.length].min

        # Count common levels from root
        common_levels = 0
        min_depth.times do |i|
          break unless parts_a[i] == parts_b[i]
          common_levels += 1
        end

        # Weight based on hierarchy depth (deeper = less weight)
        depth_weight = 1.0 / max_depth

        # Normalized similarity
        similarity = common_levels.to_f / max_depth

        [similarity, depth_weight]
      end

      # Calculate similarity between two hierarchical tags (string version)
      #
      # Compares tags level by level, returning both similarity and a weight
      # based on hierarchy depth (higher levels = more weight).
      #
      # @param tag_a [String] First tag (e.g., "database:postgresql:extensions")
      # @param tag_b [String] Second tag (e.g., "database:postgresql:queries")
      # @return [Array<Float, Float>] [similarity, weight] both in range 0.0-1.0
      #
      def calculate_hierarchical_similarity(tag_a, tag_b)
        calculate_hierarchical_similarity_cached(tag_a.split(':'), tag_b.split(':'))
      end
    end
  end
end
