# frozen_string_literal: true

require 'sinatra/base'

class HTM
  # Sinatra helpers for HTM integration
  #
  # Provides convenient helper methods for using HTM in Sinatra applications.
  #
  # @example Basic usage
  #   class MyApp < Sinatra::Base
  #     helpers HTM::Sinatra::Helpers
  #
  #     before do
  #       init_htm(robot_name: session[:user_id] || 'guest')
  #     end
  #
  #     post '/remember' do
  #       node_id = htm.remember(params[:content], source: 'user')
  #       json status: 'ok', node_id: node_id
  #     end
  #
  #     get '/recall' do
  #       memories = htm.recall(params[:topic], limit: 10)
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
      # @param source [String] Source identifier (default: 'user')
      # @return [Integer] Node ID
      #
      def remember(content, source: 'user')
        htm.remember(content, source: source)
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
        # Establish connection if needed
        unless HTM::ActiveRecordConfig.connected?
          HTM::ActiveRecordConfig.establish_connection!
        end

        # Process request
        status, headers, body = @app.call(env)

        # Return response
        [status, headers, body]
      ensure
        # Return connections to pool
        ActiveRecord::Base.clear_active_connections! if defined?(ActiveRecord)
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
          config.job_backend = :sidekiq
        else
          config.job_backend = :thread
        end
      end

      HTM.logger.info "HTM registered with Sinatra application"
      HTM.logger.debug "HTM job backend: #{HTM.configuration.job_backend}"
    end
  end
end
