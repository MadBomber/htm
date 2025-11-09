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

    def initialize(config, pool_size: nil, query_timeout: DEFAULT_QUERY_TIMEOUT, cache_size: DEFAULT_CACHE_SIZE, cache_ttl: DEFAULT_CACHE_TTL)
      @config = config
      @query_timeout = query_timeout  # in milliseconds

      # Set statement timeout for ActiveRecord queries
      ActiveRecord::Base.connection.execute("SET statement_timeout = #{@query_timeout}")

      # Initialize query result cache (disable with cache_size: 0)
      if cache_size > 0
        @query_cache = LruRedux::TTL::ThreadSafeCache.new(cache_size, cache_ttl)
        @cache_stats = { hits: 0, misses: 0 }
      end
    end

    # Add a node to long-term memory
    #
    # Embeddings should be generated client-side and provided via the embedding parameter.
    #
    # @param content [String] Conversation message/utterance
    # @param speaker [String] Who said it: 'user' or robot name
    # @param token_count [Integer] Token count
    # @param robot_id [String] Robot identifier
    # @param embedding [Array<Float>, nil] Pre-generated embedding vector
    # @return [Integer] Node database ID
    #
    def add(content:, source:, token_count: 0, robot_id:, embedding: nil)
      # Prepare embedding if provided
      if embedding
        # Pad embedding to 2000 dimensions if needed
        actual_dimension = embedding.length
        if actual_dimension < 2000
          padded_embedding = embedding + Array.new(2000 - actual_dimension, 0.0)
        else
          padded_embedding = embedding
        end
        embedding_str = "[#{padded_embedding.join(',')}]"
      end

      # Create node using ActiveRecord
      node = HTM::Models::Node.create!(
        content: content,
        source: source,
        token_count: token_count,
        robot_id: robot_id,
        embedding: embedding ? embedding_str : nil,
        embedding_dimension: embedding ? embedding.length : nil
      )

      # Invalidate cache since database content changed
      invalidate_cache!

      node.id
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
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate embeddings
    # @return [Array<Hash>] Matching nodes
    #
    def search(timeframe:, query:, limit:, embedding_service:)
      # Return uncached if cache disabled
      return search_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service) unless @query_cache

      # Generate cache key
      cache_key = cache_key_for(:search, timeframe, query, limit)

      # Try to get from cache
      cached = @query_cache[cache_key]
      if cached
        @cache_stats[:hits] += 1
        return cached
      end

      # Cache miss - execute query
      @cache_stats[:misses] += 1
      result = search_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service)

      # Store in cache
      @query_cache[cache_key] = result
      result
    end

    # Full-text search
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @return [Array<Hash>] Matching nodes
    #
    def search_fulltext(timeframe:, query:, limit:)
      # Return uncached if cache disabled
      return search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit) unless @query_cache

      # Generate cache key
      cache_key = cache_key_for(:fulltext, timeframe, query, limit)

      # Try to get from cache
      cached = @query_cache[cache_key]
      if cached
        @cache_stats[:hits] += 1
        return cached
      end

      # Cache miss - execute query
      @cache_stats[:misses] += 1
      result = search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit)

      # Store in cache
      @query_cache[cache_key] = result
      result
    end

    # Hybrid search (full-text + vector)
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate embeddings
    # @param prefilter_limit [Integer] Candidates to consider (default: 100)
    # @return [Array<Hash>] Matching nodes
    #
    def search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100)
      # Return uncached if cache disabled
      return search_hybrid_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service, prefilter_limit: prefilter_limit) unless @query_cache

      # Generate cache key
      cache_key = cache_key_for(:hybrid, timeframe, query, limit, prefilter_limit)

      # Try to get from cache
      cached = @query_cache[cache_key]
      if cached
        @cache_stats[:hits] += 1
        return cached
      end

      # Cache miss - execute query
      @cache_stats[:misses] += 1
      result = search_hybrid_uncached(timeframe: timeframe, query: query, limit: limit, embedding_service: embedding_service, prefilter_limit: prefilter_limit)

      # Store in cache
      @query_cache[cache_key] = result
      result
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
    # @param node_ids [Array<Integer>] Node IDs
    # @return [void]
    #
    def mark_evicted(node_ids)
      return if node_ids.empty?

      HTM::Models::Node.where(id: node_ids).update_all(in_working_memory: false)
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
        nodes_by_robot: HTM::Models::Node.group(:robot_id).count,
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
      result = ActiveRecord::Base.connection.select_all(
        <<~SQL,
          SELECT t1.name AS topic1, t2.name AS topic2, COUNT(DISTINCT nt1.node_id) AS shared_nodes
          FROM tags t1
          JOIN node_tags nt1 ON t1.id = nt1.tag_id
          JOIN node_tags nt2 ON nt1.node_id = nt2.node_id
          JOIN tags t2 ON nt2.tag_id = t2.id
          WHERE t1.name < t2.name
          GROUP BY t1.name, t2.name
          HAVING COUNT(DISTINCT nt1.node_id) >= #{min_shared_nodes.to_i}
          ORDER BY shared_nodes DESC
          LIMIT #{limit.to_i}
        SQL
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
    # @return [Float] Composite relevance score (0-10)
    #
    def calculate_relevance(node:, query_tags: [], vector_similarity: nil)
      # 1. Vector similarity (semantic match) - weight: 0.5
      semantic_score = if vector_similarity
        vector_similarity
      elsif node['similarity']
        node['similarity'].to_f
      else
        0.5  # Neutral if no embedding
      end

      # 2. Tag overlap (categorical relevance) - weight: 0.3
      node_tags = get_node_tags(node['id'])
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
    # @param timeframe [Range] Time range to search
    # @param query [String, nil] Search query
    # @param query_tags [Array<String>] Tags to match
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object, nil] Service to generate embeddings
    # @return [Array<Hash>] Nodes with relevance scores
    #
    def search_with_relevance(timeframe:, query: nil, query_tags: [], limit: 20, embedding_service: nil)
      # Get candidates from appropriate search method
      candidates = if query && embedding_service
        # Vector search
        search_uncached(timeframe: timeframe, query: query, limit: limit * 2, embedding_service: embedding_service)
      elsif query
        # Full-text search
        search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit * 2)
      else
        # Time-range only
        HTM::Models::Node
          .where(created_at: timeframe)
          .order(created_at: :desc)
          .limit(limit * 2)
          .map(&:attributes)
      end

      # Calculate relevance for each candidate
      scored_nodes = candidates.map do |node|
        relevance = calculate_relevance(
          node: node,
          query_tags: query_tags,
          vector_similarity: node['similarity']&.to_f
        )

        node.merge({
          'relevance' => relevance,
          'tags' => get_node_tags(node['id'])
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
    rescue
      []
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

      # Calculate relevance and enrich with tags
      nodes.map do |node|
        relevance = calculate_relevance(
          node: node,
          query_tags: tags
        )

        node.merge({
          'relevance' => relevance,
          'tags' => get_node_tags(node['id'])
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

    private

    # Generate cache key for query
    #
    # @param method [Symbol] Search method name
    # @param timeframe [Range] Time range
    # @param query [String] Search query
    # @param limit [Integer] Result limit
    # @param args [Array] Additional arguments
    # @return [String] Cache key
    #
    def cache_key_for(method, timeframe, query, limit, *args)
      key_parts = [
        method,
        timeframe.begin.to_i,
        timeframe.end.to_i,
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

    # Uncached vector similarity search
    #
    # Generates query embedding client-side and performs vector search in database.
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate query embedding
    # @return [Array<Hash>] Matching nodes
    #
    def search_uncached(timeframe:, query:, limit:, embedding_service:)
      # Generate query embedding client-side
      query_embedding = embedding_service.embed(query)

      # Pad embedding to 2000 dimensions if needed (to match nodes.embedding vector(2000))
      if query_embedding.length < 2000
        query_embedding = query_embedding + Array.new(2000 - query_embedding.length, 0.0)
      end

      # Convert to PostgreSQL vector format
      embedding_str = "[#{query_embedding.join(',')}]"

      result = ActiveRecord::Base.connection.select_all(
        <<~SQL,
          SELECT id, content, source, access_count, created_at, robot_id, token_count,
                 1 - (embedding <=> '#{embedding_str}'::vector) as similarity
          FROM nodes
          WHERE created_at BETWEEN '#{timeframe.begin.iso8601}' AND '#{timeframe.end.iso8601}'
          AND embedding IS NOT NULL
          ORDER BY embedding <=> '#{embedding_str}'::vector
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
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @return [Array<Hash>] Matching nodes
    #
    def search_fulltext_uncached(timeframe:, query:, limit:)
      result = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([
          <<~SQL,
            SELECT id, content, source, access_count, created_at, robot_id, token_count,
                   ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?)) as rank
            FROM nodes
            WHERE created_at BETWEEN ? AND ?
            AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
            ORDER BY rank DESC
            LIMIT ?
          SQL
          query, timeframe.begin, timeframe.end, query, limit
        ])
      )

      # Track access for retrieved nodes
      node_ids = result.map { |r| r['id'] }
      track_access(node_ids)

      result.to_a
    end

    # Uncached hybrid search
    #
    # Generates query embedding client-side, then combines full-text search for
    # candidate selection with vector similarity for ranking.
    #
    # @param timeframe [Range] Time range to search
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param embedding_service [Object] Service to generate query embedding
    # @param prefilter_limit [Integer] Candidates to consider
    # @return [Array<Hash>] Matching nodes
    #
    def search_hybrid_uncached(timeframe:, query:, limit:, embedding_service:, prefilter_limit:)
      # Generate query embedding client-side
      query_embedding = embedding_service.embed(query)

      # Pad embedding to 2000 dimensions if needed
      if query_embedding.length < 2000
        query_embedding = query_embedding + Array.new(2000 - query_embedding.length, 0.0)
      end

      # Convert to PostgreSQL vector format
      embedding_str = "[#{query_embedding.join(',')}]"

      result = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([
          <<~SQL,
            WITH candidates AS (
              SELECT id, content, source, access_count, created_at, robot_id, token_count, embedding
              FROM nodes
              WHERE created_at BETWEEN ? AND ?
              AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
              AND embedding IS NOT NULL
              LIMIT ?
            )
            SELECT id, content, source, access_count, created_at, robot_id, token_count,
                   1 - (embedding <=> '#{embedding_str}'::vector) as similarity
            FROM candidates
            ORDER BY embedding <=> '#{embedding_str}'::vector
            LIMIT ?
          SQL
          timeframe.begin, timeframe.end, query, prefilter_limit, limit
        ])
      )

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

#######################################
=begin

# Enhanced hierarchical similarity (with term_bonus for deep term matches like "country-music")
# Replaces your private calculate_hierarchical_similarity
def calculate_hierarchical_similarity(tag_a, tag_b, max_depth: 5)
  return [0.0, 1.0] if tag_a.empty? || tag_b.empty?  # [similarity, weight]

  parts_a = tag_a.split(':').reject(&:empty?)
  parts_b = tag_b.split(':').reject(&:empty?)
  return [0.0, 1.0] if parts_a.empty? || parts_b.empty?

  # Prefix similarity
  local_max = [parts_a.length, parts_b.length].max
  common_levels = 0
  (0...local_max).each do |i|
    if i < parts_a.length && i < parts_b.length && parts_a[i] == parts_b[i]
      common_levels += 1
    else
      break
    end
  end
  prefix_sim = local_max > 0 ? common_levels.to_f / local_max : 0.0

  # Term bonus: Shared terms weighted by avg depth
  common_terms = parts_a.to_set & parts_b.to_set
  term_bonus = 0.0
  common_terms.each do |term|
    depth_a = parts_a.index(term) + 1
    depth_b = parts_b.index(term) + 1
    avg_depth = (depth_a + depth_b) / 2.0
    depth_weight = avg_depth / max_depth.to_f
    term_bonus += depth_weight * 0.8  # Increased from 0.5 for more aggression
  end
  term_bonus = [1.0, term_bonus].min

  # Combined similarity (your weight now favors deeper via local_max)
  sim = (prefix_sim + term_bonus) / 2.0
  weight = local_max.to_f / max_depth  # Deeper = higher weight (flipped from your 1/max)

  [sim, weight]
end

# Enhanced weighted_hierarchical_jaccard (uses new similarity; adds max_pairs fallback)
# Replaces your private weighted_hierarchical_jaccard
def weighted_hierarchical_jaccard(set_a, set_b, max_depth: 5, max_pairs: 1000)
  return 0.0 if set_a.empty? || set_b.empty?

  # Fallback to flat Jaccard for large sets (your jaccard_similarity)
  if set_a.size * set_b.size > max_pairs
    terms_a = set_a.flat_map { |tag| tag.split(':').reject(&:empty?) }.to_set
    terms_b = set_b.flat_map { |tag| tag.split(':').reject(&:empty?) }.to_set
    return jaccard_similarity(terms_a.to_a, terms_b.to_a)
  end

  total_weighted_similarity = 0.0
  total_weights = 0.0
  set_a.each do |tag_a|
    set_b.each do |tag_b|
      similarity, weight = calculate_hierarchical_similarity(tag_a, tag_b, max_depth: max_depth)
      total_weighted_similarity += similarity * weight
      total_weights += weight
    end
  end
  total_weights > 0 ? total_weighted_similarity / total_weights : 0.0
end

# Updated calculate_relevance (adds ont_weight param; scales to 0-100 option)
# Enhances your existing method
def calculate_relevance(node:, query_tags: [], vector_similarity: nil, ont_weight: 1.0, scale_to_100: false)
  # 1. Vector similarity (semantic) - weight: 0.5
  semantic_score = if vector_similarity
    vector_similarity
  elsif node['similarity']
    node['similarity'].to_f
  else
    0.5
  end

  # 2. Tag overlap (ontology) - weight: 0.3, boosted by ont_weight
  node_tags = get_node_tags(node['id'])
  tag_score = if query_tags.any? && node_tags.any?
    weighted_hierarchical_jaccard(query_tags, node_tags) * ont_weight
  else
    0.5
  end
  tag_score = [tag_score, 1.0].min  # Cap boosted score

  # 3. Recency - weight: 0.1
  age_hours = (Time.current - Time.parse(node['created_at'].to_s)) / 3600.0
  recency_score = Math.exp(-age_hours / 168.0)

  # 4. Access frequency - weight: 0.1
  access_count = node['access_count'] || 0
  access_score = Math.log(1 + access_count) / 10.0

  # Weighted composite (0-10 base)
  relevance_0_10 = (
    (semantic_score * 0.5) +
    (tag_score * 0.3) +
    (recency_score * 0.1) +
    (access_score * 0.1)
  ).clamp(0.0, 10.0)

  # Scale to 0-100 if requested
  final_relevance = scale_to_100 ? (relevance_0_10 * 10.0).round(2) : relevance_0_10

  final_relevance
end

# Updated search_with_relevance (adds threshold: for 0-100 filtering; ont_weight)
# Enhances your existing method
def search_with_relevance(timeframe:, query: nil, query_tags: [], limit: 20, embedding_service: nil, threshold: nil, ont_weight: 1.0, scale_to_100: true)
  # Get candidates (your logic)
  candidates = if query && embedding_service
    search_uncached(timeframe: timeframe, query: query, limit: limit * 3, embedding_service: embedding_service)  # Oversample more for thresholds
  elsif query
    search_fulltext_uncached(timeframe: timeframe, query: query, limit: limit * 3)
  else
    HTM::Models::Node
      .where(created_at: timeframe)
      .order(created_at: :desc)
      .limit(limit * 3)
      .map(&:attributes)
  end

  # Score and enrich
  scored_nodes = candidates.map do |node|
    relevance = calculate_relevance(
      node: node,
      query_tags: query_tags,
      vector_similarity: node['similarity']&.to_f,
      ont_weight: ont_weight,
      scale_to_100: scale_to_100
    )
    node.merge({
      'relevance' => relevance,
      'tags' => get_node_tags(node['id'])
    })
  end

  # Filter by threshold if provided (e.g., >=80 for 0-100 scale)
  scored_nodes = scored_nodes.select { |n| threshold.nil? || n['relevance'] >= threshold }

  # Sort by relevance DESC, take limit (or all if threshold used)
  scored_nodes
    .sort_by { |n| -n['relevance'] }
    .take(limit)
end

=end



  end
end
