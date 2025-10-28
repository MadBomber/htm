# frozen_string_literal: true

require 'active_record'
require 'pg'
require 'pgvector'

class HTM
  # ActiveRecord database configuration and model loading
  class ActiveRecordConfig
    class << self
      # Establish database connection from HTM_DBURL environment variable
      def establish_connection!
        db_url = ENV['HTM_DBURL']
        raise "HTM_DBURL environment variable not set" unless db_url

        # Parse connection URL
        uri = URI.parse(db_url)

        config = {
          adapter: 'postgresql',
          host: uri.host,
          port: uri.port || 5432,
          database: uri.path[1..-1], # Remove leading slash
          username: uri.user,
          password: uri.password,
          pool: 10,
          timeout: 5000,
          encoding: 'unicode',
          # PostgreSQL-specific settings
          prepared_statements: false,
          advisory_locks: false
        }

        # Add SSL settings if present in query string
        if uri.query
          params = URI.decode_www_form(uri.query).to_h
          config[:sslmode] = params['sslmode'] if params['sslmode']
        end

        ActiveRecord::Base.establish_connection(config)

        # Register pgvector type
        ActiveRecord::Base.connection.execute("SET search_path TO public")

        # Load models after connection is established
        require_models

        true
      end

      # Check if connection is established and active
      def connected?
        ActiveRecord::Base.connected? &&
          ActiveRecord::Base.connection.active?
      rescue StandardError
        false
      end

      # Close all database connections
      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      end

      # Verify required extensions are available
      def verify_extensions!
        conn = ActiveRecord::Base.connection

        required_extensions = {
          'timescaledb' => 'TimescaleDB extension',
          'vector' => 'pgvector extension',
          'pg_trgm' => 'PostgreSQL trigram extension'
        }

        missing = []
        required_extensions.each do |ext, name|
          result = conn.select_value(
            "SELECT COUNT(*) FROM pg_extension WHERE extname = '#{ext}'"
          )
          missing << name if result.to_i.zero?
        end

        if missing.any?
          raise "Missing required PostgreSQL extensions: #{missing.join(', ')}"
        end

        true
      end

      # Get connection pool statistics
      def connection_stats
        pool = ActiveRecord::Base.connection_pool
        {
          size: pool.size,
          connections: pool.connections.size,
          in_use: pool.connections.count(&:in_use?),
          available: pool.connections.count { |c| !c.in_use? }
        }
      end

      private

      # Require all model files
      def require_models
        require_relative 'models/robot'
        require_relative 'models/node'
        require_relative 'models/tag'
        require_relative 'models/relationship'
        require_relative 'models/operation_log'
      end
    end
  end
end
