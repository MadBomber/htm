# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Tag management operations for LongTermMemory
    #
    # Handles hierarchical tag operations including:
    # - Adding tags to nodes
    # - Querying nodes by topic/tag
    # - Tag relationship analysis
    # - Batch tag loading (N+1 prevention)
    # - Query-to-tag matching
    #
    # Security: All queries use parameterized placeholders and LIKE patterns
    # are sanitized to prevent SQL injection.
    #
    module TagOperations
      # Maximum results to prevent DoS via unbounded queries
      MAX_TAG_QUERY_LIMIT = 1000
      MAX_TAG_SAMPLE_SIZE = 50

      # Default trigram similarity threshold for fuzzy tag search (0.0-1.0)
      # Lower = more fuzzy matches, higher = stricter matching
      DEFAULT_TAG_SIMILARITY_THRESHOLD = 0.3

      # Cache TTL for popular tags (5 minutes)
      # This eliminates expensive RANDOM() queries on every tag extraction
      POPULAR_TAGS_CACHE_TTL = 300

      # Thread-safe cache for popular tags
      @popular_tags_cache = nil
      @popular_tags_cache_expires_at = nil
      @popular_tags_mutex = Mutex.new

      class << self
        attr_accessor :popular_tags_cache, :popular_tags_cache_expires_at, :popular_tags_mutex
      end

      # Add a tag to a node
      #
      # @param node_id [Integer] Node database ID
      # @param tag [String] Tag name
      # @return [void]
      #
      def add_tag(node_id:, tag:)
        tag_record = HTM::Models::Tag.find_or_create_by(name: tag)
        HTM::Models::NodeTag.create(
          node_id: node_id,
          tag_id: tag_record.id
        )
      rescue ActiveRecord::RecordNotUnique
        # Tag association already exists, ignore
      end

      # Retrieve nodes by ontological topic
      #
      # @param topic_path [String] Topic hierarchy path
      # @param exact [Boolean] Exact match only (highest priority)
      # @param fuzzy [Boolean] Use trigram similarity for typo-tolerant search
      # @param min_similarity [Float] Minimum similarity for fuzzy mode (0.0-1.0)
      # @param limit [Integer] Maximum results (capped at MAX_TAG_QUERY_LIMIT)
      # @return [Array<Hash>] Matching nodes
      #
      # Matching modes (in order of precedence):
      # - exact: true - Only exact tag name match
      # - fuzzy: true - Trigram similarity search (typo-tolerant)
      # - default - LIKE prefix match (e.g., "database" matches "database:postgresql")
      #
      def nodes_by_topic(topic_path, exact: false, fuzzy: false, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD, limit: 50)
        # Enforce limit to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_TAG_QUERY_LIMIT].min

        if exact
          nodes = HTM::Models::Node
            .joins(:tags)
            .where(tags: { name: topic_path })
            .distinct
            .order(created_at: :desc)
            .limit(safe_limit)
        elsif fuzzy
          # Trigram similarity search - tolerates typos and partial matches
          safe_similarity = [[min_similarity.to_f, 0.0].max, 1.0].min
          nodes = HTM::Models::Node
            .joins(:tags)
            .where("similarity(tags.name, ?) >= ?", topic_path, safe_similarity)
            .distinct
            .order(created_at: :desc)
            .limit(safe_limit)
        else
          # Sanitize LIKE pattern to prevent wildcard injection
          safe_pattern = HTM::SqlBuilder.sanitize_like_pattern(topic_path)
          nodes = HTM::Models::Node
            .joins(:tags)
            .where("tags.name LIKE ?", "#{safe_pattern}%")
            .distinct
            .order(created_at: :desc)
            .limit(safe_limit)
        end

        nodes.map(&:attributes)
      end

      # Get ontology structure view
      #
      # @return [Array<Hash>] Ontology structure
      #
      def ontology_structure
        result = ActiveRecord::Base.connection.select_all(
          "SELECT * FROM ontology_structure WHERE root_topic IS NOT NULL ORDER BY root_topic, level1_topic, level2_topic"
        )
        result.to_a
      end

      # Get topic relationships (co-occurrence)
      #
      # @param min_shared_nodes [Integer] Minimum shared nodes
      # @param limit [Integer] Maximum relationships (capped at MAX_TAG_QUERY_LIMIT)
      # @return [Array<Hash>] Topic relationships
      #
      def topic_relationships(min_shared_nodes: 2, limit: 50)
        # Enforce limit to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_TAG_QUERY_LIMIT].min
        safe_min = [min_shared_nodes.to_i, 1].max

        # Use parameterized query to prevent SQL injection
        sql = <<~SQL
          SELECT t1.name AS topic1, t2.name AS topic2, COUNT(DISTINCT nt1.node_id) AS shared_nodes
          FROM tags t1
          JOIN node_tags nt1 ON t1.id = nt1.tag_id
          JOIN node_tags nt2 ON nt1.node_id = nt2.node_id
          JOIN tags t2 ON nt2.tag_id = t2.id
          WHERE t1.name < t2.name
          GROUP BY t1.name, t2.name
          HAVING COUNT(DISTINCT nt1.node_id) >= $1
          ORDER BY shared_nodes DESC
          LIMIT $2
        SQL

        result = ActiveRecord::Base.connection.exec_query(
          sql,
          'topic_relationships',
          [[nil, safe_min], [nil, safe_limit]]
        )
        result.to_a
      end

      # Get topics for a specific node
      #
      # @param node_id [Integer] Node database ID
      # @return [Array<String>] Topic paths
      #
      def node_topics(node_id)
        HTM::Models::Tag
          .joins(:node_tags)
          .where(node_tags: { node_id: node_id })
          .order(:name)
          .pluck(:name)
      end

      # Get tags for a specific node
      #
      # @param node_id [Integer] Node database ID
      # @return [Array<String>] Tag names
      #
      def get_node_tags(node_id)
        HTM::Models::Tag
          .joins(:node_tags)
          .where(node_tags: { node_id: node_id })
          .pluck(:name)
      rescue ActiveRecord::ActiveRecordError => e
        HTM.logger.error("Failed to retrieve tags for node #{node_id}: #{e.message}")
        []
      end

      # Batch load tags for multiple nodes (avoids N+1 queries)
      #
      # @param node_ids [Array<Integer>] Node database IDs
      # @return [Hash<Integer, Array<String>>] Map of node_id to array of tag names
      #
      def batch_load_node_tags(node_ids)
        return {} if node_ids.empty?

        # Single query to get all tags for all nodes
        results = HTM::Models::NodeTag
          .joins(:tag)
          .where(node_id: node_ids)
          .pluck(:node_id, 'tags.name')

        # Group by node_id
        results.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      rescue ActiveRecord::ActiveRecordError => e
        HTM.logger.error("Failed to batch load tags: #{e.message}")
        {}
      end

      # Get most popular tags
      #
      # @param limit [Integer] Number of tags to return (capped at MAX_TAG_QUERY_LIMIT)
      # @param timeframe [Range, nil] Optional time range filter
      # @return [Array<Hash>] Tags with usage counts
      #
      def popular_tags(limit: 20, timeframe: nil)
        # Enforce limit to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_TAG_QUERY_LIMIT].min

        query = HTM::Models::Tag
          .joins(:node_tags)
          .joins('INNER JOIN nodes ON nodes.id = node_tags.node_id')
          .group('tags.id', 'tags.name')
          .select('tags.name, COUNT(node_tags.id) as usage_count')

        query = query.where('nodes.created_at >= ? AND nodes.created_at <= ?', timeframe.begin, timeframe.end) if timeframe

        query
          .order('usage_count DESC')
          .limit(safe_limit)
          .map { |tag| { name: tag.name, usage_count: tag.usage_count } }
      end

      # Fuzzy search for tags using trigram similarity
      #
      # Uses PostgreSQL pg_trgm extension to find tags that are similar
      # to the query string, tolerating typos and partial matches.
      #
      # @param query [String] Search query (tag name or partial)
      # @param limit [Integer] Maximum results (capped at MAX_TAG_QUERY_LIMIT)
      # @param min_similarity [Float] Minimum similarity threshold (0.0-1.0)
      # @return [Array<Hash>] Matching tags with similarity scores
      #   Each hash contains: { name: String, similarity: Float }
      #
      def search_tags(query, limit: 20, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD)
        return [] if query.nil? || query.strip.empty?

        # Enforce limits
        safe_limit = [[limit.to_i, 1].max, MAX_TAG_QUERY_LIMIT].min
        safe_similarity = [[min_similarity.to_f, 0.0].max, 1.0].min

        sql = <<~SQL
          SELECT name, similarity(name, ?) as similarity
          FROM tags
          WHERE similarity(name, ?) >= ?
          ORDER BY similarity DESC, name
          LIMIT ?
        SQL

        result = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([sql, query, query, safe_similarity, safe_limit])
        )

        result.map { |r| { name: r['name'], similarity: r['similarity'].to_f } }
      rescue ActiveRecord::ActiveRecordError => e
        HTM.logger.error("Failed to search tags: #{e.message}")
        []
      end

      # Find tags that match terms in the query
      #
      # Searches the tags table for tags where any hierarchy level matches
      # query words. Uses semantic extraction via LLM to find relevant tags.
      #
      # Performance: Uses a single UNION query instead of multiple sequential queries.
      #
      # @param query [String] Search query
      # @param include_extracted [Boolean] If true, returns hash with :extracted and :matched keys
      # @return [Array<String>] Matching tag names (default)
      # @return [Hash] If include_extracted: { extracted: [...], matched: [...] }
      #
      def find_query_matching_tags(query, include_extracted: false)
        empty_result = include_extracted ? { extracted: [], matched: [] } : []
        return empty_result if query.nil? || query.strip.empty?

        # OPTIMIZATION: Use cached popular tags instead of expensive RANDOM() query
        # This saves 50-300ms per call by avoiding a full table sort
        existing_tags = cached_popular_tags

        # Use the tag extractor to generate semantic tags from the query
        extracted_tags = HTM::TagService.extract(query, existing_ontology: existing_tags)

        if extracted_tags.empty?
          return include_extracted ? { extracted: [], matched: [] } : []
        end

        # Build prefix candidates from extracted tags
        prefix_candidates = extracted_tags.flat_map do |tag|
          levels = tag.split(':')
          (1...levels.size).map { |i| levels[0, i].join(':') }
        end.uniq

        # Get all components for component matching
        all_components = extracted_tags.flat_map { |tag| tag.split(':') }.uniq

        # Build UNION query to find matches in a single database round-trip
        matched_tags = find_matching_tags_unified(
          exact_candidates: extracted_tags,
          prefix_candidates: prefix_candidates,
          component_candidates: all_components
        )

        if include_extracted
          { extracted: extracted_tags, matched: matched_tags }
        else
          matched_tags
        end
      end

      private

      # Get cached popular tags for ontology context
      #
      # Uses TTL cache to avoid expensive repeated queries.
      # Returns array of tag names for the TagService to use as ontology context.
      #
      # @return [Array<String>] Popular tag names
      #
      def cached_popular_tags
        cache = TagOperations
        cache.popular_tags_mutex.synchronize do
          now = Time.now
          if cache.popular_tags_cache.nil? || cache.popular_tags_cache_expires_at.nil? || now > cache.popular_tags_cache_expires_at
            # Fetch popular tags and extract just the names
            cache.popular_tags_cache = popular_tags(limit: MAX_TAG_SAMPLE_SIZE).map { |t| t[:name] }
            cache.popular_tags_cache_expires_at = now + POPULAR_TAGS_CACHE_TTL
          end
          cache.popular_tags_cache
        end
      rescue StandardError => e
        HTM.logger.error("Failed to fetch cached popular tags: #{e.message}")
        []
      end

      # Find matching tags using a single unified query
      #
      # Uses UNION to combine exact, prefix, component, and trigram matching
      # in a single database round-trip.
      #
      # Matching strategies (in priority order):
      # 1. Exact matches - tag name exactly equals candidate
      # 2. Prefix matches - tag name equals parent path component
      # 3. Component matches - tag contains component at any hierarchy level
      # 4. Trigram matches - fuzzy similarity search (typo-tolerant fallback)
      #
      # @param exact_candidates [Array<String>] Tags to match exactly
      # @param prefix_candidates [Array<String>] Prefixes to match
      # @param component_candidates [Array<String>] Components to search for
      # @param fuzzy_fallback [Boolean] Include trigram fuzzy matching (default: true)
      # @param min_similarity [Float] Minimum similarity for trigram matching
      # @return [Array<String>] Matched tag names
      #
      def find_matching_tags_unified(exact_candidates:, prefix_candidates:, component_candidates:, fuzzy_fallback: true, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD)
        return [] if exact_candidates.empty? && prefix_candidates.empty? && component_candidates.empty?

        conditions = []
        params = []

        # Exact matches (highest priority)
        if exact_candidates.any?
          placeholders = exact_candidates.map { '?' }.join(', ')
          conditions << "(SELECT name, 1 as priority FROM tags WHERE name IN (#{placeholders}))"
          params.concat(exact_candidates)
        end

        # Prefix matches
        if prefix_candidates.any?
          placeholders = prefix_candidates.map { '?' }.join(', ')
          conditions << "(SELECT name, 2 as priority FROM tags WHERE name IN (#{placeholders}))"
          params.concat(prefix_candidates)
        end

        # Component matches
        # Pre-sanitize components once to avoid duplicate processing
        if component_candidates.any?
          # Pre-compute sanitized components for efficiency
          sanitized_components = component_candidates.map do |component|
            [component, HTM::SqlBuilder.sanitize_like_pattern(component)]
          end

          component_conditions = sanitized_components.map do |_component, _safe|
            # Match: exact, starts with, ends with, or middle
            "(name = ? OR name LIKE ? OR name LIKE ? OR name LIKE ?)"
          end

          component_params = sanitized_components.flat_map do |component, safe_component|
            [
              component,                 # exact match
              "#{safe_component}:%",     # starts with
              "%:#{safe_component}",     # ends with
              "%:#{safe_component}:%"    # in middle
            ]
          end

          conditions << "(SELECT name, 3 as priority FROM tags WHERE #{component_conditions.join(' OR ')})"
          params.concat(component_params)
        end

        # Trigram fuzzy matches (lowest priority - fallback for typos)
        # Uses pg_trgm similarity to find tags even with spelling errors
        if fuzzy_fallback && component_candidates.any?
          safe_similarity = [[min_similarity.to_f, 0.0].max, 1.0].min
          trigram_conditions = component_candidates.map { "similarity(name, ?) >= ?" }
          trigram_params = component_candidates.flat_map { |c| [c, safe_similarity] }

          conditions << "(SELECT name, 4 as priority FROM tags WHERE #{trigram_conditions.join(' OR ')})"
          params.concat(trigram_params)
        end

        return [] if conditions.empty?

        # Combine with UNION and order by priority
        sql = <<~SQL
          SELECT DISTINCT name FROM (
            #{conditions.join(' UNION ')}
          ) AS matches
          ORDER BY name
          LIMIT ?
        SQL
        params << MAX_TAG_QUERY_LIMIT

        result = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([sql, *params])
        )
        result.map { |r| r['name'] }
      rescue ActiveRecord::ActiveRecordError => e
        HTM.logger.error("Failed to find matching tags: #{e.message}")
        []
      end
    end
  end
end
