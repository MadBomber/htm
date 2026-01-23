# frozen_string_literal: true

require 'pg'
require 'json'

# Load standalone utility classes
require_relative 'sql_builder'
require_relative 'query_cache'

# Load modules
require_relative 'long_term_memory/relevance_scorer'
require_relative 'long_term_memory/node_operations'
require_relative 'long_term_memory/robot_operations'
require_relative 'long_term_memory/tag_operations'
require_relative 'long_term_memory/vector_search'
require_relative 'long_term_memory/fulltext_search'
require_relative 'long_term_memory/hybrid_search'

class HTM
  # Long-term Memory - PostgreSQL-backed permanent storage
  #
  # LongTermMemory provides durable storage for all memory nodes with:
  # - Vector similarity search (RAG)
  # - Full-text search
  # - Time-range queries
  # - Relationship graphs
  # - Tag system
  # - Sequel ORM for data access
  # - Query result caching for efficiency
  #
  # This class uses standalone utility classes and modules:
  #
  # Standalone classes (used via class methods or instances):
  # - HTM::SqlBuilder: SQL condition building helpers (class methods)
  # - HTM::QueryCache: Query result caching (instantiated as @cache)
  #
  # Included modules:
  # - RelevanceScorer: Dynamic relevance scoring
  # - NodeOperations: Node CRUD operations
  # - RobotOperations: Robot registration and activity
  # - TagOperations: Tag management
  # - VectorSearch: Vector similarity search
  # - FulltextSearch: Full-text search
  # - HybridSearch: Combined search strategies
  #
  class LongTermMemory
    # Include modules (order matters - dependencies first)
    #
    # Dependency graph:
    #   TagOperations, RobotOperations  (no deps)
    #   NodeOperations      → @cache (QueryCache instance)
    #   VectorSearch        → HTM::SqlBuilder, @cache, NodeOperations
    #   FulltextSearch      → HTM::SqlBuilder, @cache, NodeOperations
    #   HybridSearch        → HTM::SqlBuilder, @cache, TagOperations, NodeOperations
    #   RelevanceScorer     → HTM::SqlBuilder, TagOperations, VectorSearch, FulltextSearch
    #
    include TagOperations
    include RobotOperations
    include NodeOperations
    include VectorSearch
    include FulltextSearch
    include HybridSearch
    include RelevanceScorer

    DEFAULT_QUERY_TIMEOUT = 30_000  # milliseconds (30 seconds)
    MAX_VECTOR_DIMENSION = 2000  # Maximum supported dimension with HNSW index (pgvector limitation)
    DEFAULT_CACHE_SIZE = 1000  # Number of queries to cache
    DEFAULT_CACHE_TTL = 300    # Cache lifetime in seconds (5 minutes)

    attr_reader :query_timeout

    # Initialize long-term memory storage
    #
    # @param config [Hash] Database configuration (host, port, dbname, user, password)
    # @param pool_size [Integer, nil] Connection pool size (uses Sequel default if nil)
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

      # Set statement timeout for Sequel queries
      HTM.db.run("SET statement_timeout = #{@query_timeout}")

      # Initialize query result cache (disable with cache_size: 0)
      @cache = HTM::QueryCache.new(size: cache_size, ttl: cache_ttl)
    end

    # Get memory statistics
    #
    # @return [Hash] Statistics
    #
    def stats
      base_stats = {
        total_nodes: HTM::Models::Node.count,
        nodes_by_robot: HTM::Models::RobotNode.group_and_count(:robot_id).as_hash(:robot_id, :count),
        total_tags: HTM::Models::Tag.count,
        oldest_memory: HTM::Models::Node.min(:created_at),
        newest_memory: HTM::Models::Node.max(:created_at),
        active_robots: HTM::Models::Robot.count,
        robot_activity: HTM::Models::Robot.select(:id, :name, :last_active).all.map(&:values),
        database_size: HTM.db.get(Sequel.function(:pg_database_size, Sequel.function(:current_database))).to_i
      }

      # Include cache statistics if cache is enabled
      if @cache&.enabled?
        base_stats[:cache] = @cache.stats
      end

      base_stats
    end

    # Shutdown - no-op with Sequel (connection pool managed by Sequel)
    def shutdown
      # Sequel handles connection pool shutdown
      # This method kept for API compatibility
    end

    # Clear the query result cache
    #
    # @return [void]
    #
    def clear_cache!
      @cache&.clear!
    end

    # For backwards compatibility with tests/code that expect pool_size
    def pool_size
      HTM.db.pool.size
    end
  end
end
