# frozen_string_literal: true

require 'pg'
require 'pgvector'
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
    # @param type [String, nil] Node type
    # @param category [String, nil] Node category
    # @param importance [Float] Importance score
    # @param token_count [Integer] Token count
    # @param robot_id [String] Robot identifier
    # @param embedding [Array<Float>, nil] Pre-generated embedding vector
    # @return [Integer] Node database ID
    #
    def add(content:, speaker:, type: nil, category: nil, importance: 1.0, token_count: 0, robot_id:, embedding: nil)
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
        speaker: speaker,
        type: type,
        category: category,
        importance: importance,
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
    # @param node_id [Integer] Node database ID
    # @return [Hash, nil] Node data or nil
    #
    def retrieve(node_id)
      node = HTM::Models::Node.find_by(id: node_id)
      return nil unless node

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

    # Register a robot
    #
    # @param robot_id [String] Robot identifier
    # @param robot_name [String] Robot name
    # @return [void]
    #
    def register_robot(robot_id, robot_name)
      robot = HTM::Models::Robot.find_or_initialize_by(id: robot_id)
      robot.name = robot_name
      robot.last_active = Time.current
      robot.save!
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
        nodes_by_type: HTM::Models::Node.group(:type).count,
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
          JOIN nodes_tags nt1 ON t1.id = nt1.tag_id
          JOIN nodes_tags nt2 ON nt1.node_id = nt2.node_id
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
        .where(nodes_tags: { node_id: node_id })
        .order(:name)
        .pluck(:name)
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
          SELECT id, content, speaker, type, category, importance, created_at, robot_id, token_count,
                 1 - (embedding <=> '#{embedding_str}'::vector) as similarity
          FROM nodes
          WHERE created_at BETWEEN '#{timeframe.begin.iso8601}' AND '#{timeframe.end.iso8601}'
          AND embedding IS NOT NULL
          ORDER BY embedding <=> '#{embedding_str}'::vector
          LIMIT #{limit.to_i}
        SQL
      )
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
            SELECT id, content, speaker, type, category, importance, created_at, robot_id, token_count,
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
              SELECT id, content, speaker, type, category, importance, created_at, robot_id, token_count, embedding
              FROM nodes
              WHERE created_at BETWEEN ? AND ?
              AND to_tsvector('english', content) @@ plainto_tsquery('english', ?)
              AND embedding IS NOT NULL
              LIMIT ?
            )
            SELECT id, content, speaker, type, category, importance, created_at, robot_id, token_count,
                   1 - (embedding <=> '#{embedding_str}'::vector) as similarity
            FROM candidates
            ORDER BY embedding <=> '#{embedding_str}'::vector
            LIMIT ?
          SQL
          timeframe.begin, timeframe.end, query, prefilter_limit, limit
        ])
      )
      result.to_a
    end
  end
end
