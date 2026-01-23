# frozen_string_literal: true

# HTM Sinatra Integration
#
# Optional integration for using HTM with Sinatra web applications.
# This file is NOT loaded automatically - require it explicitly:
#
#   require 'htm'
#   require 'htm/integrations/sinatra'
#
# Provides:
# - HTM::Sinatra::Helpers - Request helpers (init_htm, htm, remember, recall)
# - HTM::Sinatra::Middleware - Connection pool management
# - Sinatra::Base.register_htm - One-line setup
#

require 'sinatra/base'

class HTM
  # Sinatra helpers for HTM integration
  #
  # Provides convenient helper methods for using HTM in Sinatra applications.
  #
  # @example Basic usage
  #   require 'htm/integrations/sinatra'
  #
  #   class MyApp < Sinatra::Base
  #     register_htm
  #
  #     before do
  #       init_htm(robot_name: session[:user_id] || 'guest')
  #     end
  #
  #     post '/remember' do
  #       node_id = remember(params[:content])
  #       json status: 'ok', node_id: node_id
  #     end
  #
  #     get '/recall' do
  #       memories = recall(params[:topic], limit: 10)
  #       json memories: memories
  #     end
  #   end
  #
  module Sinatra
    module Helpers
      # Initialize HTM instance for current request
      #
      # @param robot_name [String] Robot identifier (typically user/session ID)
      # @param working_memory_size [Integer] Token limit for working memory
      # @return [HTM] HTM instance for this request
      #
      def init_htm(robot_name: 'guest', working_memory_size: 128_000)
        @htm = HTM.new(
          robot_name: robot_name,
          working_memory_size: working_memory_size
        )
      end

      # Get current HTM instance
      #
      # @return [HTM] HTM instance for this request
      # @raise [RuntimeError] If HTM not initialized (call init_htm first)
      #
      def htm
        @htm || raise("HTM not initialized. Call init_htm in a before filter.")
      end

      # Remember information (convenience method)
      #
      # @param content [String] Content to remember
      # @param tags [Array<String>] Optional tags to assign
      # @return [Integer] Node ID
      #
      def remember(content, tags: [])
        htm.remember(content, tags: tags)
      end

      # Recall memories (convenience method)
      #
      # @param topic [String] Topic to search for
      # @param options [Hash] Recall options (timeframe, limit, strategy, etc.)
      # @return [Array<Hash>] Matching memories
      #
      def recall(topic, **options)
        htm.recall(topic, **options)
      end

      # JSON response helper
      #
      # @param data [Hash] Data to convert to JSON
      # @return [String] JSON response
      #
      def json(data)
        content_type :json
        data.to_json
      end
    end

    # Rack middleware for HTM connection management
    #
    # Ensures database connections are properly managed across requests.
    # With Sequel's fiber-safe connection pooling, this is largely automatic.
    #
    # @example Use in Sinatra app
    #   class MyApp < Sinatra::Base
    #     use HTM::Sinatra::Middleware
    #   end
    #
    class Middleware
      def initialize(app, options = {})
        @app = app
        @options = options
      end

      def call(env)
        # Ensure connection is available
        ensure_connection!

        # Process request
        status, headers, body = @app.call(env)

        # Return response
        [status, headers, body]
      end

      # Store the connection config at startup (called from register_htm)
      def self.store_config!
        # With Sequel, connection is established globally via HTM::SequelConfig
        # No additional per-request config storage needed
      end

      private

      def ensure_connection!
        # Sequel handles connection pooling automatically
        # Just verify the connection is available
        unless HTM.db
          HTM::SequelConfig.establish_connection!
        end
      rescue StandardError => e
        HTM.logger.error "Failed to ensure connection: #{e.class} - #{e.message}"
        raise
      end
    end
  end
end

# Extend Sinatra::Base with HTM registration helper
module ::Sinatra
  class Base
    # Register HTM with Sinatra application
    #
    # Automatically configures HTM for Sinatra apps:
    # - Adds helpers
    # - Adds middleware
    # - Configures logger
    #
    # @example
    #   class MyApp < Sinatra::Base
    #     register_htm
    #
    #     post '/remember' do
    #       remember(params[:content])
    #     end
    #   end
    #
    def self.register_htm
      helpers HTM::Sinatra::Helpers
      use HTM::Sinatra::Middleware

      # Configure HTM with Sinatra logger
      HTM.configure do |config|
        config.logger = logger if respond_to?(:logger)

        # Use Sidekiq if available, otherwise thread-based
        if defined?(::Sidekiq)
          config.job.backend = :sidekiq
        else
          config.job.backend = :thread
        end
      end

      # Establish initial connection (Sequel handles pooling automatically)
      begin
        HTM::Sinatra::Middleware.store_config!
        HTM::SequelConfig.establish_connection!
        HTM.logger.info "HTM database connection established"
      rescue StandardError => e
        HTM.logger.error "Failed to establish HTM database connection: #{e.message}"
        raise
      end

      HTM.logger.info "HTM registered with Sinatra application"
    end
  end
end
