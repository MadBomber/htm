# frozen_string_literal: true

require 'active_record'
require 'pg'
require 'neighbor'

class HTM
  # ActiveRecord database configuration and model loading
  #
  # Uses HTM::Config for database settings. Configuration can come from:
  # - config/htm.yml (environment-specific)
  # - Environment variables (HTM_DB_URL, HTM_DB_HOST, etc.)
  # - Programmatic configuration via HTM.configure
  #
  class ActiveRecordConfig
    class << self
      # Establish database connection from HTM::Config
      def establish_connection!
        config = load_database_config

        ActiveRecord::Base.establish_connection(config)

        # Set search path
        ActiveRecord::Base.connection.execute("SET search_path TO public")

        # Load models after connection is established
        require_models

        true
      end

      # Load database configuration from HTM::Config
      #
      # @return [Hash] ActiveRecord-compatible configuration hash
      #
      def load_database_config
        htm_config = HTM.config

        # If we have a database URL, parse it
        if htm_config.database_url
          htm_config.database_config
        else
          # Fall back to legacy config/database.yml if it exists and no config in HTM::Config
          legacy_config_path = File.expand_path('../../config/database.yml', __dir__)

          if File.exist?(legacy_config_path) && !htm_config.database_configured?
            load_legacy_database_config(legacy_config_path)
          else
            htm_config.database_config
          end
        end
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

      # Load legacy database.yml configuration (for backward compatibility)
      #
      # @param config_path [String] Path to database.yml
      # @return [Hash] ActiveRecord-compatible configuration hash
      #
      def load_legacy_database_config(config_path)
        require 'erb'
        require 'yaml'

        erb_content = ERB.new(File.read(config_path)).result
        db_config = YAML.safe_load(erb_content, aliases: true)

        config = db_config[HTM.env]

        unless config
          raise "No database configuration found for environment: #{HTM.env}"
        end

        config.transform_keys(&:to_sym)
      end

      # Require all model files
      def require_models
        require_relative 'models/robot'
        require_relative 'models/node'
        require_relative 'models/robot_node'
        require_relative 'models/tag'
        require_relative 'models/node_tag'
        require_relative 'models/file_source'
      end
    end
  end
end
