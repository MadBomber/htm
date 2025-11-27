# frozen_string_literal: true

require 'active_record'
require 'pg'
require 'neighbor'
require 'erb'
require 'yaml'

class HTM
  # ActiveRecord database configuration and model loading
  class ActiveRecordConfig
    class << self
      # Establish database connection from config/database.yml
      def establish_connection!
        config = load_database_config

        ActiveRecord::Base.establish_connection(config)

        # Set search path
        ActiveRecord::Base.connection.execute("SET search_path TO public")

        # Load models after connection is established
        require_models

        true
      end

      # Load and parse database configuration from YAML with ERB
      def load_database_config
        config_path = File.expand_path('../../config/database.yml', __dir__)

        unless File.exist?(config_path)
          raise "Database configuration file not found at #{config_path}"
        end

        # Read and parse ERB
        erb_content = ERB.new(File.read(config_path)).result
        db_config = YAML.safe_load(erb_content, aliases: true)

        # Determine environment
        env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'

        # Get configuration for current environment
        config = db_config[env]

        unless config
          raise "No database configuration found for environment: #{env}"
        end

        # Convert string keys to symbols for ActiveRecord
        config.transform_keys(&:to_sym)
      end

      # Check if connection is established and active
      def connected?
        return false unless defined?(ActiveRecord::Base)
        return false unless ActiveRecord::Base.connection_handler.connection_pool_list.any?

        ActiveRecord::Base.connected? && ActiveRecord::Base.connection.active?
      rescue ActiveRecord::ConnectionNotDefined, ActiveRecord::ConnectionNotEstablished
        false
      rescue StandardError => e
        HTM.logger.debug "Connection check failed: #{e.class} - #{e.message}"
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
        require_relative 'models/robot_node'
        require_relative 'models/tag'
        require_relative 'models/node_tag'
        require_relative 'models/working_memory_entry'
      end
    end
  end
end
