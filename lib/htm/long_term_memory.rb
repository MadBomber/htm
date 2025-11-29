# frozen_string_literal: true

require 'pg'
require 'json'
require 'lru_redux'
require 'digest'

class HTM
  # Long-term Memory - PostgreSQL/TimescaleDB-backed permanent storage
  #
  # LongTermMemory provides durable storage for all memory nodes with:
  # - Vector similarity search (RAG)
  # - Full-text search
  # - Time-range queries
  # - Relationship graphs
  # - Tag system
  # - ActiveRecord ORM for data access
  # - Query result caching for efficiency
  #
  class LongTermMemory
    DEFAULT_QUERY_TIMEOUT = 30_000  # milliseconds (30 seconds)
    MAX_VECTOR_DIMENSION = 2000  # Maximum supported dimension with HNSW index (pgvector limitation)
    DEFAULT_CACHE_SIZE = 1000  # Number of queries to cache
    DEFAULT_CACHE_TTL = 300    # Cache lifetime in seconds (5 minutes)

    attr_reader :query_timeout

    # Initialize long-term memory storage
    #
    # @param config [Hash] Database configuration (host, port, dbname, user, password)
    # @param pool_size [Integer, nil] Connection pool size (uses ActiveRecord default if nil)
    # @param query_timeout [Integer] Query timeout in milliseconds (default: 30000)
    # @param cache_size [Integer] Number of query results to cache (default: 1000, use 0 to disable)
    # @param cache_ttl [Integer] Cache time-to-live in seconds (default: 300)
    #
    # @example Initialize with defaults
    #   ltm = LongTermMemory.new(HTM::Database.default_config)
    #
    # @example Initialize with custom cache settings
    #   ltm = LongTermMemory.new(config, cache_size: 500, cache_ttl: 600)
    #
    # @example Disable caching
    #   ltm = LongTermMemory.new(config, cache_size: 0)
    #
    def initialize(config, pool_size: nil, query_timeout: DEFAULT_QUERY_TIMEOUT, cache_size: DEFAULT_CACHE_SIZE, cache_ttl: DEFAULT_CACHE_TTL)
      @config = config
      @query_timeout = query_timeout  # in milliseconds

      # Set statement timeout for ActiveRecord queries
      ActiveRecord::Base.connection.execute("SET statement_timeout = #{@query_timeout}")

      # Initialize query result cache (disable with cache_size: 0)
      if cache_size > 0
        @query_cache = LruRedux::TTL::ThreadSafeCache.new(cache_size, cache_ttl)
        @cache_stats = { hits: 0, misses: 0 }
        @cache_stats_mutex = Mutex.new  # Thread-safety for cache statistics
      end
    end

    # Add a node to long-term memory (with deduplication)
    #
    # If content already exists (by content_hash), links the robot to the existing
    # node and updates timestamps. Otherwise creates a new node.
    #
    # @param content [String] Conversation message/utterance
    # @param token_count [Integer] Token count
    # @param robot_id [Integer] Robot identifier
    # @param embedding [Array<Float>, nil] Pre-generated embedding vector
    # @param metadata [Hash] Flexible metadata for the node (default: {})
    # @return [Hash] { node_id:, is_new:, robot_node: }
    #
    def add(content:, token_count: 0, robot_id:, embedding: nil, metadata: {})
      content_hash = HTM::Models::Node.generate_content_hash(content)

      # Wrap in transaction to ensure data consistency
      ActiveRecord::Base.transaction do
        # Check for existing node with same content (including soft-deleted)
        # This avoids unique constraint violations on content_hash
        existing_node = HTM::Models::Node.with_deleted.find_by(content_hash: content_hash)

        # If found but soft-deleted, restore it
        if existing_node&.deleted?
          existing_node.restore!
          HTM.logger.info "Restored soft-deleted node #{existing_node.id} for content match"
        end

        if existing_node
          # Link robot to existing node (or update if already linked)
          robot_node = link_robot_to_node(robot_id: robot_id, node: existing_node)

          # Update the node's updated_at timestamp
          existing_node.touch

          {
            node_id: existing_node.id,
            is_new: false,
            robot_node: robot_node
          }
        else
          # Prepare embedding if provided
          embedding_str = nil
          if embedding
            # Pad embedding to 2000 dimensions if needed
            actual_dimension = embedding.length
            padded_embedding = if actual_dimension < 2000
              embedding + Array.new(2000 - actual_dimension, 0.0)
            else
              embedding
            end
            embedding_str = "[#{padded_embedding.join(',')}]"
          end

          # Create new node
          node = HTM::Models::Node.create!(
            content: content,
            content_hash: content_hash,
            token_count: token_count,
            embedding: embedding_str,
            metadata: metadata
          )

          # Link robot to new node
          robot_node = link_robot_to_node(robot_id: robot_id, node: node)

          # Invalidate cache since database content changed
          invalidate_cache!

          {
            node_id: node.id,
            is_new: true,
            robot_node: robot_node
          }
        end
      end
    end

    # Link a robot to a node (create or update robot_node record)
    #
    # @param robot_id [Integer] Robot ID
    # @param node [HTM::Models::Node] Node to link
    # @return [HTM::Models::RobotNode] The robot_node link record
    #
    def link_robot_to_node(robot_id:, node:)
      robot_node = HTM::Models::RobotNode.find_by(robot_id: robot_id, node_id: node.id)

      if robot_node
        # Existing link - record that robot remembered this again
        robot_node.record_remember!
      else
        # New link
        robot_node = HTM::Models::RobotNode.create!(
          robot_id: robot_id,
          node_id: node.id,
          first_remembered_at: Time.current,
          last_remembered_at: Time.current,
          remember_count: 1
        )
      end

      robot_node
    end

    # Retrieve a node by ID
    #
    # Automatically tracks access by incrementing access_count and updating last_accessed
    #
    # @param node_id [Integer] Node database ID
    # @return [Hash, nil] Node data or nil
    #
    def retrieve(node_id)
      node = HTM::Models::Node.find_by(id: node_id)
      return nil unless node

      # Track access (atomic increment)
      node.increment!(:access_count)
      node.touch(:last_accessed)

      node.attributes
    end

    # Update last_accessed timestamp
    #
    # @param node_id [Integer] Node database ID
    # @return [void]
    #
    def update_last_accessed(node_id)
      node = HTM::Models::Node.find_by(id: node_id)
      node&.update(last_accessed: Time.current)
    end

    # Delete a node
    #
    # @param node_id [Integer] Node database ID
    # @return [void]
    #
    def delete(node_id)
      node = HTM::Models::Node.find_by(id: node_id)
      node&.destroy

      # Invalidate cache since database content changed
      invalidate_cache!
    end

    # Check if a node exists
    #
    # @param node_id [Integer] Node database ID
    # @return [Boolean] True if node exists
    #
    def exists?(node_id)
      HTM::Models::Node.exists?(node_id)
    end

    # Vector similarity search
    #
    # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate embeddings
    # @param metadata [Hash] Filter by metadata fields (default: {})
    # @return [Array<Hash>] Matching nodes
    #
    def search(timeframe:, query:, limit:, embedding_service:, metadata: {})
      cached_query(:search, timeframe, query, limit, metadata) do
        search_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service, metadata: metadata)
      end
    end

    # Full-text search
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param metadata [Hash] Filter by metadata fields (default: {})
    # @return [Array<Hash>] Matching nodes
    #
    def search_fulltext(timeframe:, query:, limit:, metadata: {})
      cached_query(:fulltext, timeframe, query, limit, metadata) do
        search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit, metadata: metadata)
      end
    end

    # Hybrid search (full-text + vector)
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate embeddings
    # @param prefilter_limit [Integer] Candidates to consider (default: 100)
    # @param metadata [Hash] Filter by metadata fields (default: {})
    # @return [Array<Hash>] Matching nodes
    #
    def search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100, metadata: {})
      cached_query(:hybrid, timeframe, query, limit, prefilter_limit, metadata) do
        search_hybrid_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service, prefilter_limit: prefilter_limit, metadata: metadata)
      end
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

    # Mark nodes as evicted from working memory
    #
    # Working memory state is now tracked per-robot in the working_memories table
    # (optional persistence). The in-memory WorkingMemory class handles eviction
    # tracking. This method is retained for API compatibility but is a no-op.
    #
    # @param node_ids [Array<Integer>] Node IDs (ignored)
    # @return [void]
    #
    def mark_evicted(node_ids)
      # No-op: working memory is tracked in-memory or via WorkingMemoryEntry model
    end

    # Track access for multiple nodes (bulk operation)
    #
    # Updates access_count and last_accessed for all nodes in the array
    #
    # @param node_ids [Array<Integer>] Node IDs that were accessed
    # @return [void]
    #
    def track_access(node_ids)
      return if node_ids.empty?

      # Atomic batch update
      HTM::Models::Node.where(id: node_ids).update_all(
        "access_count = access_count + 1, last_accessed = NOW()"
      )
    end

    # Register a robot
    #
    # @param robot_id [String] Robot identifier
    # @param robot_name [String] Robot name
    # @return [void]
    #
    def register_robot(robot_name)
      robot = HTM::Models::Robot.find_or_create_by(name: robot_name)
      robot.update(last_active: Time.current)
      robot.id
    end

    # Update robot activity timestamp
    #
    # @param robot_id [String] Robot identifier
    # @return [void]
    #
    def update_robot_activity(robot_id)
      robot = HTM::Models::Robot.find_by(id: robot_id)
      robot&.update(last_active: Time.current)
    end

    # Get memory statistics
    #
    # @return [Hash] Statistics
    #
    def stats
      base_stats = {
        total_nodes: HTM::Models::Node.count,
        nodes_by_robot: HTM::Models::RobotNode.group(:robot_id).count,
        total_tags: HTM::Models::Tag.count,
        oldest_memory: HTM::Models::Node.minimum(:created_at),
        newest_memory: HTM::Models::Node.maximum(:created_at),
        active_robots: HTM::Models::Robot.count,
        robot_activity: HTM::Models::Robot.select(:id, :name, :last_active).map(&:attributes),
        database_size: ActiveRecord::Base.connection.select_value("SELECT pg_database_size(current_database())").to_i
      }

      # Include cache statistics if cache is enabled
      if @query_cache
        base_stats[:cache] = cache_stats
      end

      base_stats
    end

    # Shutdown - no-op with ActiveRecord (connection pool managed by ActiveRecord)
    def shutdown
      # ActiveRecord handles connection pool shutdown
      # This method kept for API compatibility
    end

    # Clear the query cache
    #
    # Call this after any operation that modifies data (soft delete, restore, etc.)
    # to ensure subsequent queries see fresh results.
    #
    # @return [void]
    #
    def clear_cache!
      invalidate_cache!
    end

    # For backwards compatibility with tests/code that expect pool_size
    def pool_size
      ActiveRecord::Base.connection_pool.size
    end

    # Retrieve nodes by ontological topic
    #
    # @param topic_path [String] Topic hierarchy path
    # @param exact [Boolean] Exact match or prefix match
    # @param limit [Integer] Maximum results
    # @return [Array<Hash>] Matching nodes
    #
    def nodes_by_topic(topic_path, exact: false, limit: 50)
      if exact
        nodes = HTM::Models::Node
          .joins(:tags)
          .where(tags: { name: topic_path })
          .distinct
          .order(created_at: :desc)
          .limit(limit)
      else
        nodes = HTM::Models::Node
          .joins(:tags)
          .where("tags.name LIKE ?", "#{topic_path}%")
          .distinct
          .order(created_at: :desc)
          .limit(limit)
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
    # @param limit [Integer] Maximum relationships
    # @return [Array<Hash>] Topic relationships
    #
    def topic_relationships(min_shared_nodes: 2, limit: 50)
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
        [[nil, min_shared_nodes.to_i], [nil, limit.to_i]]
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

    # Calculate dynamic relevance score for a node given query context
    #
    # Combines multiple signals:
    # - Vector similarity (semantic match)
    # - Tag overlap (categorical match)
    # - Recency (freshness)
    # - Access frequency (popularity/utility)
    #
    # @param node [Hash] Node data with similarity, tags, created_at, access_count
    # @param query_tags [Array<String>] Tags associated with the query
    # @param vector_similarity [Float, nil] Pre-computed vector similarity (0-1)
    # @param node_tags [Array<String>, nil] Pre-loaded tags for this node (avoids N+1 query)
    # @return [Float] Composite relevance score (0-10)
    #
    def calculate_relevance(node:, query_tags: [], vector_similarity: nil, node_tags: nil)
      # 1. Vector similarity (semantic match) - weight: 0.5
      semantic_score = if vector_similarity
        vector_similarity
      elsif node['similarity']
        node['similarity'].to_f
      else
        0.5  # Neutral if no embedding
      end

      # 2. Tag overlap (categorical relevance) - weight: 0.3
      # Use pre-loaded tags if provided, otherwise fetch (for backward compatibility)
      node_tags ||= get_node_tags(node['id'])
      tag_score = if query_tags.any? && node_tags.any?
        weighted_hierarchical_jaccard(query_tags, node_tags)
      else
        0.5  # Neutral if no tags
      end

      # 3. Recency (temporal relevance) - weight: 0.1
      age_hours = (Time.now - Time.parse(node['created_at'].to_s)) / 3600.0
      recency_score = Math.exp(-age_hours / 168.0)  # 1-week half-life

      # 4. Access frequency (behavioral signal) - weight: 0.1
      access_count = node['access_count'] || 0
      access_score = Math.log(1 + access_count) / 10.0  # Normalize to 0-1

      # Weighted composite (scale to 0-10)
      relevance = (
        (semantic_score * 0.5) +
        (tag_score * 0.3) +
        (recency_score * 0.1) +
        (access_score * 0.1)
      ) * 10.0

      relevance.clamp(0.0, 10.0)
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
        # Vector search
        search_uncached(timeframe: timeframe, query: query, limit: limit * 2, embedding_service: embedding_service, metadata: metadata)
      elsif query
        # Full-text search
        search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit * 2, metadata: metadata)
      else
        # Time-range only (or no filter if timeframe is nil)
        scope = HTM::Models::Node.where(deleted_at: nil)
        scope = apply_timeframe_scope(scope, timeframe)
        scope = apply_metadata_scope(scope, metadata)
        scope.order(created_at: :desc).limit(limit * 2).map(&:attributes)
      end

      # Batch load all tags for candidates (fixes N+1 query)
      node_ids = candidates.map { |n| n['id'] }
      tags_by_node = batch_load_node_tags(node_ids)

      # Calculate relevance for each candidate
      scored_nodes = candidates.map do |node|
        node_tags = tags_by_node[node['id']] || []

        relevance = calculate_relevance(
          node: node,
          query_tags: query_tags,
          vector_similarity: node['similarity']&.to_f,
          node_tags: node_tags
        )

        node.merge({
          'relevance' => relevance,
          'tags' => node_tags
        })
      end

      # Sort by relevance and return top K
      scored_nodes
        .sort_by { |n| -n['relevance'] }
        .take(limit)
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

      # Build base query
      query = HTM::Models::Node
        .joins(:tags)
        .where(tags: { name: tags })
        .distinct

      # Apply timeframe filter if provided
      query = query.where(created_at: timeframe) if timeframe

      if match_all
        # Match ALL tags (intersection)
        query = query
          .group('nodes.id')
          .having('COUNT(DISTINCT tags.name) = ?', tags.size)
      end

      # Get results
      nodes = query.limit(limit).map(&:attributes)

      # Batch load all tags for nodes (fixes N+1 query)
      node_ids = nodes.map { |n| n['id'] }
      tags_by_node = batch_load_node_tags(node_ids)

      # Calculate relevance and enrich with tags
      nodes.map do |node|
        node_tags = tags_by_node[node['id']] || []
        relevance = calculate_relevance(
          node: node,
          query_tags: tags,
          node_tags: node_tags
        )

        node.merge({
          'relevance' => relevance,
          'tags' => node_tags
        })
      end.sort_by { |n| -n['relevance'] }
    end

    # Get most popular tags
    #
    # @param limit [Integer] Number of tags to return
    # @param timeframe [Range, nil] Optional time range filter
    # @return [Array<Hash>] Tags with usage counts
    #
    def popular_tags(limit: 20, timeframe: nil)
      query = HTM::Models::Tag
        .joins(:node_tags)
        .joins('INNER JOIN nodes ON nodes.id = node_tags.node_id')
        .group('tags.id', 'tags.name')
        .select('tags.name, COUNT(node_tags.id) as usage_count')

      query = query.where('nodes.created_at >= ? AND nodes.created_at <= ?', timeframe.begin, timeframe.end) if timeframe

      query
        .order('usage_count DESC')
        .limit(limit)
        .map { |tag| { name: tag.name, usage_count: tag.usage_count } }
    end

    # Find tags that match terms in the query
    #
    # Searches the tags table for tags where any hierarchy level matches
    # query words. For example, query "PostgreSQL database" would match
    # tags like "database:postgresql", "database:sql", etc.
    # Find tags matching a query using semantic extraction
    #
    # @param query [String] Search query
    # @param include_extracted [Boolean] If true, returns hash with :extracted and :matched keys
    # @return [Array<String>] Matching tag names (default)
    # @return [Hash] If include_extracted: { extracted: [...], matched: [...] }
    #
    def find_query_matching_tags(query, include_extracted: false)
      empty_result = include_extracted ? { extracted: [], matched: [] } : []
      return empty_result if query.nil? || query.strip.empty?

      # Use the tag extractor to generate semantic tags from the query
      # This uses the same LLM process as when storing nodes
      existing_tags = HTM::Models::Tag.pluck(:name).sample(50)
      extracted_tags = HTM::TagService.extract(query, existing_ontology: existing_tags)

      if extracted_tags.empty?
        return include_extracted ? { extracted: [], matched: [] } : []
      end

      # Step 1: Try exact matches
      exact_matches = HTM::Models::Tag.where(name: extracted_tags).pluck(:name)

      if exact_matches.any?
        return include_extracted ? { extracted: extracted_tags, matched: exact_matches } : exact_matches
      end

      # Step 2: Try matching on parent/prefix levels
      # For "person:human:character:popeye", try "person:human:character", "person:human", "person"
      prefix_candidates = extracted_tags.flat_map do |tag|
        levels = tag.split(':')
        (1...levels.size).map { |i| levels[0, i].join(':') }
      end.uniq

      if prefix_candidates.any?
        prefix_matches = HTM::Models::Tag.where(name: prefix_candidates).pluck(:name)
        if prefix_matches.any?
          return include_extracted ? { extracted: extracted_tags, matched: prefix_matches } : prefix_matches
        end
      end

      # Step 3: Try matching individual components, starting from rightmost (most specific)
      # For "person:human:character:popeye", try "popeye", then "character", then "human", then "person"
      # Search for tags that contain this component at any level
      all_components = extracted_tags.flat_map { |tag| tag.split(':') }.uniq

      # Order by specificity: components that appear at deeper levels first
      component_depths = Hash.new(0)
      extracted_tags.each do |tag|
        levels = tag.split(':')
        levels.each_with_index { |comp, idx| component_depths[comp] = [component_depths[comp], idx].max }
      end
      ordered_components = all_components.sort_by { |c| -component_depths[c] }

      # Try each component, starting with most specific (rightmost)
      ordered_components.each do |component|
        # Find tags where this component appears at any level
        component_matches = HTM::Models::Tag
          .where("name = ? OR name LIKE ? OR name LIKE ? OR name LIKE ?",
                 component,           # exact match (single-level tag)
                 "#{component}:%",    # starts with component
                 "%:#{component}",    # ends with component
                 "%:#{component}:%")  # component in middle
          .pluck(:name)

        if component_matches.any?
          return include_extracted ? { extracted: extracted_tags, matched: component_matches } : component_matches
        end
      end

      # No matches found at any level
      include_extracted ? { extracted: extracted_tags, matched: [] } : []
    end

    private

    # Sanitize embedding for SQL use
    #
    # Validates that all values are numeric and converts to safe PostgreSQL vector format.
    # This prevents SQL injection by ensuring only valid numeric values are included.
    #
    # @param embedding [Array<Numeric>] Embedding vector
    # @return [String] Sanitized vector string for PostgreSQL (e.g., "[0.1,0.2,0.3]")
    # @raise [ArgumentError] If embedding contains non-numeric values
    #
    def sanitize_embedding_for_sql(embedding)
      unless embedding.is_a?(Array) && embedding.all? { |v| v.is_a?(Numeric) && v.finite? }
        raise ArgumentError, "Embedding must be an array of finite numeric values"
      end

      "[#{embedding.map { |v| v.to_f }.join(',')}]"
    end

    # Build SQL condition for timeframe filtering
    #
    # @param timeframe [nil, Range, Array<Range>] Time range(s)
    # @param table_alias [String] Table alias (default: none)
    # @return [String, nil] SQL condition or nil for no filter
    #
    def build_timeframe_condition(timeframe, table_alias: nil)
      return nil if timeframe.nil?

      prefix = table_alias ? "#{table_alias}." : ""
      column = "#{prefix}created_at"
      conn = ActiveRecord::Base.connection

      case timeframe
      when Range
        # Use quote to safely escape timestamp values
        begin_quoted = conn.quote(timeframe.begin.iso8601)
        end_quoted = conn.quote(timeframe.end.iso8601)
        "(#{column} BETWEEN #{begin_quoted} AND #{end_quoted})"
      when Array
        conditions = timeframe.map do |range|
          begin_quoted = conn.quote(range.begin.iso8601)
          end_quoted = conn.quote(range.end.iso8601)
          "(#{column} BETWEEN #{begin_quoted} AND #{end_quoted})"
        end
        "(#{conditions.join(' OR ')})"
      else
        nil
      end
    end

    # Build ActiveRecord where clause for timeframe
    #
    # @param scope [ActiveRecord::Relation] Base scope
    # @param timeframe [nil, Range, Array<Range>] Time range(s)
    # @return [ActiveRecord::Relation] Scoped query
    #
    def apply_timeframe_scope(scope, timeframe)
      return scope if timeframe.nil?

      case timeframe
      when Range
        scope.where(created_at: timeframe)
      when Array
        # Build OR conditions for multiple ranges
        conditions = timeframe.map { |range| scope.where(created_at: range) }
        conditions.reduce { |result, condition| result.or(condition) }
      else
        scope
      end
    end

    # Build SQL condition for metadata filtering (JSONB containment)
    #
    # @param metadata [Hash] Metadata to filter by
    # @param table_alias [String] Table alias (default: none)
    # @return [String, nil] SQL condition or nil for no filter
    #
    def build_metadata_condition(metadata, table_alias: nil)
      return nil if metadata.nil? || metadata.empty?

      prefix = table_alias ? "#{table_alias}." : ""
      column = "#{prefix}metadata"
      conn = ActiveRecord::Base.connection

      # Use JSONB containment operator @>
      # This matches if the metadata column contains all key-value pairs in the filter
      quoted_metadata = conn.quote(metadata.to_json)
      "(#{column} @> #{quoted_metadata}::jsonb)"
    end

    # Build ActiveRecord where clause for metadata
    #
    # @param scope [ActiveRecord::Relation] Base scope
    # @param metadata [Hash] Metadata to filter by
    # @return [ActiveRecord::Relation] Scoped query
    #
    def apply_metadata_scope(scope, metadata)
      return scope if metadata.nil? || metadata.empty?

      # Use JSONB containment operator
      scope.where("metadata @> ?::jsonb", metadata.to_json)
    end

    # Generate cache key for query
    #
    # @param method [Symbol] Search method name
    # @param timeframe [nil, Range, Array<Range>] Time range(s)
    # @param query [String] Search query
    # @param limit [Integer] Result limit
    # @param args [Array] Additional arguments
    # @return [String] Cache key
    #
    def cache_key_for(method, timeframe, query, limit, *args)
      timeframe_key = case timeframe
      when nil
        "nil"
      when Range
        "#{timeframe.begin.to_i}-#{timeframe.end.to_i}"
      when Array
        timeframe.map { |r| "#{r.begin.to_i}-#{r.end.to_i}" }.join(',')
      else
        timeframe.to_s
      end

      key_parts = [
        method,
        timeframe_key,
        query,
        limit,
        *args
      ]
      Digest::SHA256.hexdigest(key_parts.join('|'))
    end

    # Get cache statistics
    #
    # @return [Hash, nil] Cache stats or nil if cache disabled
    #
    def cache_stats
      return nil unless @query_cache

      total = @cache_stats[:hits] + @cache_stats[:misses]
      hit_rate = total > 0 ? (@cache_stats[:hits].to_f / total * 100).round(2) : 0.0

      {
        hits: @cache_stats[:hits],
        misses: @cache_stats[:misses],
        hit_rate: hit_rate,
        size: @query_cache.count
      }
    end

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

    def weighted_hierarchical_jaccard(set_a, set_b)
      return 0.0 if set_a.empty? || set_b.empty?

      total_weighted_similarity = 0.0
      total_weights = 0.0

      set_a.each do |tag_a|
        set_b.each do |tag_b|
          similarity, weight = calculate_hierarchical_similarity(tag_a, tag_b)
          total_weighted_similarity += similarity * weight
          total_weights += weight
        end
      end

      total_weights > 0 ? total_weighted_similarity / total_weights : 0.0
    end



    # Invalidate (clear) the query cache
    #
    # @return [void]
    #
    def invalidate_cache!
      @query_cache.clear if @query_cache
    end

    # Execute a query with caching
    #
    # @param method [Symbol] Search method name for cache key
    # @param args [Array] Arguments for cache key (timeframe, query, limit, etc.)
    # @yield Block that executes the actual query
    # @return [Array<Hash>] Query results (from cache or freshly executed)
    #
    def cached_query(method, *args, &block)
      return yield unless @query_cache

      cache_key = cache_key_for(method, *args)

      if (cached = @query_cache[cache_key])
        @cache_stats_mutex.synchronize { @cache_stats[:hits] += 1 }
        return cached
      end

      @cache_stats_mutex.synchronize { @cache_stats[:misses] += 1 }
      result = yield
      @query_cache[cache_key] = result
      result
    end

    # Uncached vector similarity search
    #
    # Generates query embedding client-side and performs vector search in database.
    #
    # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate query embedding
    # @param metadata [Hash] Filter by metadata fields (default: {})
    # @return [Array<Hash>] Matching nodes
    #
    def search_uncached(timeframe:, query:, limit:, embedding_service:, metadata: {})
      # Generate query embedding client-side
      query_embedding = embedding_service.embed(query)

      # Pad embedding to 2000 dimensions if needed (to match nodes.embedding vector(2000))
      if query_embedding.length < 2000
        query_embedding = query_embedding + Array.new(2000 - query_embedding.length, 0.0)
      end

      # Sanitize embedding for safe SQL use (validates all values are numeric)
      embedding_str = sanitize_embedding_for_sql(query_embedding)

      # Build filter conditions
      timeframe_condition = build_timeframe_condition(timeframe)
      metadata_condition = build_metadata_condition(metadata)

      conditions = ["embedding IS NOT NULL", "deleted_at IS NULL"]
      conditions << timeframe_condition if timeframe_condition
      conditions << metadata_condition if metadata_condition

      where_clause = "WHERE #{conditions.join(' AND ')}"

      # Use quote to safely escape the embedding string in the query
      quoted_embedding = ActiveRecord::Base.connection.quote(embedding_str)

      result = ActiveRecord::Base.connection.select_all(
        <<~SQL,
          SELECT id, content, access_count, created_at, token_count,
                 1 - (embedding <=> #{quoted_embedding}::vector) as similarity
          FROM nodes
          #{where_clause}
          ORDER BY embedding <=> #{quoted_embedding}::vector
          LIMIT #{limit.to_i}
        SQL
      )

      # Track access for retrieved nodes
      node_ids = result.map { |r| r['id'] }
      track_access(node_ids)

      result.to_a
    end

    # Uncached full-text search
    #
    # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param metadata [Hash] Filter by metadata fields (default: {})
    # @return [Array<Hash>] Matching nodes
    #
    def search_fulltext_uncached(timeframe:, query:, limit:, metadata: {})
      # Build filter conditions
      timeframe_condition = build_timeframe_condition(timeframe)
      metadata_condition = build_metadata_condition(metadata)

      additional_conditions = []
      additional_conditions << timeframe_condition if timeframe_condition
      additional_conditions << metadata_condition if metadata_condition
      additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

      result = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([
          <<~SQL,
            SELECT id, content, access_count, created_at, token_count,
                   ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?)) as rank
            FROM nodes
            WHERE deleted_at IS NULL
            AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
            #{additional_sql}
            ORDER BY rank DESC
            LIMIT ?
          SQL
          query, query, limit
        ])
      )

      # Track access for retrieved nodes
      node_ids = result.map { |r| r['id'] }
      track_access(node_ids)

      result.to_a
    end

    # Uncached hybrid search
    #
    # Generates query embedding client-side, then combines:
    # 1. Full-text search for content matching
    # 2. Tag matching for categorical relevance
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

      # Pad embedding to 2000 dimensions if needed
      if query_embedding.length < 2000
        query_embedding = query_embedding + Array.new(2000 - query_embedding.length, 0.0)
      end

      # Sanitize embedding for safe SQL use (validates all values are numeric)
      embedding_str = sanitize_embedding_for_sql(query_embedding)
      quoted_embedding = ActiveRecord::Base.connection.quote(embedding_str)

      # Build filter conditions (with table alias for CTEs)
      timeframe_condition = build_timeframe_condition(timeframe, table_alias: 'n')
      metadata_condition = build_metadata_condition(metadata, table_alias: 'n')

      additional_conditions = []
      additional_conditions << timeframe_condition if timeframe_condition
      additional_conditions << metadata_condition if metadata_condition
      additional_sql = additional_conditions.any? ? "AND #{additional_conditions.join(' AND ')}" : ""

      # Same for non-aliased queries
      timeframe_condition_bare = build_timeframe_condition(timeframe)
      metadata_condition_bare = build_metadata_condition(metadata)

      additional_conditions_bare = []
      additional_conditions_bare << timeframe_condition_bare if timeframe_condition_bare
      additional_conditions_bare << metadata_condition_bare if metadata_condition_bare
      additional_sql_bare = additional_conditions_bare.any? ? "AND #{additional_conditions_bare.join(' AND ')}" : ""

      # Find tags that match query terms
      matching_tags = find_query_matching_tags(query)

      # Build the hybrid query
      # If we have matching tags, include nodes with those tags in the candidate pool
      # NOTE: Hybrid search includes nodes without embeddings using a default
      # similarity score of 0.5. This allows newly created nodes to appear in
      # search results immediately (via fulltext matching) before their embeddings
      # are generated by background jobs.

      if matching_tags.any?
        # Escape tag names for SQL
        tag_list = matching_tags.map { |t| ActiveRecord::Base.connection.quote(t) }.join(', ')
        result = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([
            <<~SQL,
              WITH fulltext_candidates AS (
                -- Nodes matching full-text search (with or without embeddings)
                SELECT DISTINCT n.id, n.content, n.access_count, n.created_at, n.token_count, n.embedding
                FROM nodes n
                WHERE n.deleted_at IS NULL
                AND to_tsvector('english', n.content) @@ plainto_tsquery('english', ?)
                #{additional_sql}
                LIMIT ?
              ),
              tag_candidates AS (
                -- Nodes matching relevant tags (with or without embeddings)
                SELECT DISTINCT n.id, n.content, n.access_count, n.created_at, n.token_count, n.embedding
                FROM nodes n
                JOIN node_tags nt ON nt.node_id = n.id
                JOIN tags t ON t.id = nt.tag_id
                WHERE n.deleted_at IS NULL
                AND t.name IN (#{tag_list})
                #{additional_sql}
                LIMIT ?
              ),
              all_candidates AS (
                SELECT * FROM fulltext_candidates
                UNION
                SELECT * FROM tag_candidates
              ),
              scored AS (
                SELECT
                  ac.id, ac.content, ac.access_count, ac.created_at, ac.token_count,
                  CASE
                    WHEN ac.embedding IS NOT NULL THEN 1 - (ac.embedding <=> #{quoted_embedding}::vector)
                    ELSE 0.5  -- Default similarity for nodes without embeddings
                  END as similarity,
                  COALESCE((
                    SELECT COUNT(DISTINCT t.name)::float / ?
                    FROM node_tags nt
                    JOIN tags t ON t.id = nt.tag_id
                    WHERE nt.node_id = ac.id AND t.name IN (#{tag_list})
                  ), 0) as tag_boost
                FROM all_candidates ac
              )
              SELECT id, content, access_count, created_at, token_count,
                     similarity, tag_boost,
                     (similarity * 0.7 + tag_boost * 0.3) as combined_score
              FROM scored
              ORDER BY combined_score DESC
              LIMIT ?
            SQL
            query, prefilter_limit,
            prefilter_limit,
            matching_tags.length.to_f,
            limit
          ])
        )
      else
        # No matching tags, fall back to standard hybrid (fulltext + vector)
        # Include nodes without embeddings with a default similarity score
        result = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array([
            <<~SQL,
              WITH candidates AS (
                SELECT id, content, access_count, created_at, token_count, embedding
                FROM nodes
                WHERE deleted_at IS NULL
                AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
                #{additional_sql_bare}
                LIMIT ?
              )
              SELECT id, content, access_count, created_at, token_count,
                     CASE
                       WHEN embedding IS NOT NULL THEN 1 - (embedding <=> #{quoted_embedding}::vector)
                       ELSE 0.5  -- Default similarity for nodes without embeddings
                     END as similarity,
                     0.0 as tag_boost,
                     CASE
                       WHEN embedding IS NOT NULL THEN 1 - (embedding <=> #{quoted_embedding}::vector)
                       ELSE 0.5  -- Default score for nodes without embeddings (fulltext matched)
                     END as combined_score
              FROM candidates
              ORDER BY combined_score DESC
              LIMIT ?
            SQL
            query, prefilter_limit, limit
          ])
        )
      end

      # Track access for retrieved nodes
      node_ids = result.map { |r| r['id'] }
      track_access(node_ids)

      result.to_a
    end


    def calculate_hierarchical_similarity(tag_a, tag_b)
      parts_a = tag_a.split(':')
      parts_b = tag_b.split(':')

      # Calculate overlap at each level
      common_levels = 0
      max_depth = [parts_a.length, parts_b.length].max

      (0...max_depth).each do |i|
        if i < parts_a.length && i < parts_b.length && parts_a[i] == parts_b[i]
          common_levels += 1
        else
          break
        end
      end

      # Calculate weight based on hierarchy depth (higher levels = more weight)
      depth_weight = 1.0 / max_depth

      # Calculate normalized similarity (0-1)
      similarity = max_depth > 0 ? (common_levels.to_f / max_depth) : 0.0

      [similarity, depth_weight]
    end
  end
end
