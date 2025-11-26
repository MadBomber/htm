# frozen_string_literal: true

class HTM
  # Job adapter for pluggable background job backends
  #
  # Supports multiple job backends to work seamlessly across different
  # application types (CLI, Sinatra, Rails).
  #
  # Supported backends:
  # - :active_job - Rails ActiveJob (recommended for Rails apps)
  # - :sidekiq - Direct Sidekiq integration (recommended for Sinatra apps)
  # - :inline - Synchronous execution (recommended for CLI and tests)
  # - :thread - Background thread (legacy, for standalone apps)
  #
  # @example Configure job backend
  #   HTM.configure do |config|
  #     config.job_backend = :active_job
  #   end
  #
  # @example Enqueue a job
  #   HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: 123)
  #
  # @see ADR-016: Async Embedding and Tag Generation
  #
  module JobAdapter
    class << self
      # Enqueue a background job using the configured backend
      #
      # @param job_class [Class] Job class to enqueue (must respond to :perform)
      # @param params [Hash] Parameters to pass to the job
      # @return [void]
      #
      # @raise [HTM::Error] If job backend is unknown
      #
      def enqueue(job_class, **params)
        backend = HTM.configuration.job_backend

        case backend
        when :active_job
          enqueue_active_job(job_class, **params)
        when :sidekiq
          enqueue_sidekiq(job_class, **params)
        when :inline
          enqueue_inline(job_class, **params)
        when :thread
          enqueue_thread(job_class, **params)
        else
          raise HTM::Error, "Unknown job backend: #{backend}. Supported backends: :active_job, :sidekiq, :inline, :thread"
        end
      end

      private

      # Enqueue job using ActiveJob (Rails)
      def enqueue_active_job(job_class, **params)
        unless defined?(ActiveJob)
          raise HTM::Error, "ActiveJob is not available. Add 'activejob' gem or use a different backend."
        end

        # Convert job class to ActiveJob if needed
        active_job_class = to_active_job_class(job_class)
        active_job_class.perform_later(**params)

        HTM.logger.debug "Enqueued #{job_class.name} via ActiveJob with params: #{params.inspect}"
      end

      # Enqueue job using Sidekiq directly
      def enqueue_sidekiq(job_class, **params)
        unless defined?(Sidekiq)
          raise HTM::Error, "Sidekiq is not available. Add 'sidekiq' gem or use a different backend."
        end

        # Convert job class to Sidekiq worker if needed
        sidekiq_class = to_sidekiq_worker(job_class)

        # Sidekiq 7.x requires native JSON types - convert symbol keys to strings
        json_params = params.transform_keys(&:to_s)
        sidekiq_class.perform_async(json_params)

        HTM.logger.debug "Enqueued #{job_class.name} via Sidekiq with params: #{params.inspect}"
      end

      # Execute job inline (synchronously)
      def enqueue_inline(job_class, **params)
        HTM.logger.debug "Executing #{job_class.name} inline with params: #{params.inspect}"

        begin
          job_class.perform(**params)
          HTM.logger.debug "Completed #{job_class.name} inline execution"
        rescue StandardError => e
          HTM.logger.error "Inline job #{job_class.name} failed: #{e.class.name} - #{e.message}"
          HTM.logger.debug e.backtrace.first(5).join("\n")
        end
      end

      # Execute job in background thread (legacy)
      def enqueue_thread(job_class, **params)
        Thread.new do
          HTM.logger.debug "Executing #{job_class.name} in thread with params: #{params.inspect}"

          begin
            job_class.perform(**params)
            HTM.logger.debug "Completed #{job_class.name} thread execution"
          rescue StandardError => e
            HTM.logger.error "Thread job #{job_class.name} failed: #{e.class.name} - #{e.message}"
            HTM.logger.debug e.backtrace.first(5).join("\n")
          end
        end

        HTM.logger.debug "Started thread for #{job_class.name}"
      rescue StandardError => e
        HTM.logger.error "Failed to start thread for #{job_class.name}: #{e.message}"
      end

      # Convert HTM job class to ActiveJob class
      def to_active_job_class(job_class)
        # If it's already an ActiveJob, return it
        return job_class if job_class < ActiveJob::Base

        # Create wrapper ActiveJob class
        Class.new(ActiveJob::Base) do
          queue_as :htm

          define_method(:perform) do |**params|
            job_class.perform(**params)
          end

          # Set descriptive name
          define_singleton_method(:name) do
            "#{job_class.name}ActiveJobWrapper"
          end
        end
      end

      # Convert HTM job class to Sidekiq worker
      def to_sidekiq_worker(job_class)
        # If it's already a Sidekiq worker, return it
        return job_class if job_class.included_modules.include?(Sidekiq::Worker)

        # Create wrapper Sidekiq worker
        # Note: Sidekiq 7.x requires JSON-compatible args, so we accept a hash
        # and convert string keys back to symbols for the underlying job
        Class.new do
          include Sidekiq::Worker
          sidekiq_options queue: :htm, retry: 3

          define_method(:perform) do |params|
            # Convert string keys back to symbols for the job class
            symbolized_params = params.transform_keys(&:to_sym)
            job_class.perform(**symbolized_params)
          end

          # Set descriptive name
          define_singleton_method(:name) do
            "#{job_class.name}SidekiqWrapper"
          end
        end
      end
    end
  end
end
