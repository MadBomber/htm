# frozen_string_literal: true

require 'sequel'

class HTM
  # Sequel database configuration and model loading
  #
  # Uses HTM::Config for database settings. Configuration can come from:
  # - Environment variables (HTM_DATABASE__URL, HTM_DATABASE__HOST, etc.)
  # - Programmatic configuration via HTM.configure
  #
  # Sequel is fiber-safe by design, making it ideal for async/fiber-based
  # concurrency patterns used in HTM's job processing.
  #
  class SequelConfig
    class << self
      # Database connection instance
      # @return [Sequel::Database, nil]
      attr_reader :db

      # Establish database connection from HTM::Config
      #
      # @param load_models [Boolean] Whether to load models after connection (default: true)
      #   Set to false when running migrations on a fresh database
      # @return [Sequel::Database] The database connection
      #
      def establish_connection!(load_models: true)
        return @db if @db

        config = load_database_config
        connection_string = build_connection_string(config)

        # Configure Sequel with fiber-safe settings
        @db = Sequel.connect(connection_string, {
          max_connections: config[:pool] || 5,
          pool_timeout: (config[:checkout_timeout] || 5).to_i,
          # Fiber-safe settings - important for async gem compatibility
          preconnect: :concurrently,
          # Use threaded mode which works well with fibers
          single_threaded: false
        })

        # Load PostgreSQL-specific extensions for JSONB and array handling
        @db.extension :pg_json
        @db.extension :pg_array

        # Set search path and statement timeout
        @db.run("SET search_path TO public")
        @db.run("SET statement_timeout = #{config[:statement_timeout] || 30_000}")

        # Load models after connection is established (unless disabled for migrations)
        require_models if load_models && models_loadable?

        @db
      end

      # Check if models can be loaded (tables exist)
      #
      # @return [Boolean]
      #
      def models_loadable?
        return false unless @db
        @db.table_exists?(:robots)
      rescue Sequel::DatabaseError
        false
      end

      # Ensure models are loaded
      #
      # Call this after migrations to ensure models are available
      # @return [void]
      #
      def ensure_models_loaded!
        require_models unless @models_loaded
      end

      # Load database configuration from HTM::Config
      #
      # @return [Hash] Database configuration hash
      #
      def load_database_config
        HTM.config.database_config
      end

      # Build connection string from config hash
      #
      # @param config [Hash] Database configuration
      # @return [String] PostgreSQL connection string
      #
      def build_connection_string(config)
        # If we have a URL already, use it
        if config[:url]
          return config[:url]
        end

        user = config[:username] || config[:user]
        password = config[:password]
        host = config[:host] || 'localhost'
        port = config[:port] || 5432
        database = config[:database]

        if password && !password.empty?
          "postgres://#{user}:#{password}@#{host}:#{port}/#{database}"
        elsif user
          "postgres://#{user}@#{host}:#{port}/#{database}"
        else
          "postgres://#{host}:#{port}/#{database}"
        end
      end

      # Check if connection is established and active
      #
      # @return [Boolean]
      #
      def connected?
        return false unless @db

        @db.test_connection
      rescue Sequel::DatabaseError
        false
      end

      # Close all database connections
      #
      # @return [void]
      #
      def disconnect!
        @db&.disconnect
        @db = nil
      end

      # Verify required extensions are available
      #
      # @raise [RuntimeError] if required extensions are missing
      # @return [true]
      #
      def verify_extensions!
        required_extensions = {
          'vector' => 'pgvector extension',
          'pg_trgm' => 'PostgreSQL trigram extension'
        }

        missing = []
        required_extensions.each do |ext, name|
          result = @db["SELECT COUNT(*) AS cnt FROM pg_extension WHERE extname = ?", ext].first
          missing << name if result[:cnt].to_i.zero?
        end

        if missing.any?
          raise "Missing required PostgreSQL extensions: #{missing.join(', ')}"
        end

        true
      end

      # Get connection pool statistics
      #
      # @return [Hash] Pool statistics
      #
      def connection_stats
        pool = @db.pool
        {
          size: pool.max_size,
          available: pool.available_connections.size,
          allocated: pool.allocated.size
        }
      rescue NoMethodError
        # Fallback for connection pools that don't support these methods
        { size: @db.pool.max_size }
      end

      # Run raw SQL
      #
      # @param sql [String] SQL to execute
      # @return [void]
      #
      def execute(sql)
        @db.run(sql)
      end

      # Select a single value
      #
      # @param sql [String] SQL query
      # @return [Object] The value
      #
      def select_value(sql)
        @db[sql].first&.values&.first
      end

      private

      # Require all model files
      def require_models
        return if @models_loaded

        require_relative 'models/robot'
        require_relative 'models/node'
        require_relative 'models/robot_node'
        require_relative 'models/tag'
        require_relative 'models/node_tag'
        require_relative 'models/file_source'

        @models_loaded = true
      end
    end
  end

  # Convenience method to access the database connection
  #
  # @return [Sequel::Database]
  #
  def self.db
    SequelConfig.db || SequelConfig.establish_connection!
  end
end
