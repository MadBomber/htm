# frozen_string_literal: true

require 'async'
require 'async/barrier'

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
  # - :fiber - Fiber-based concurrency using async gem (recommended for I/O-bound jobs)
  #
  # @example Configure job backend
  #   HTM.configure do |config|
  #     config.job.backend = :active_job
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
        when :fiber
          enqueue_fiber(job_class, **params)
        else
          raise HTM::Error, "Unknown job backend: #{backend}. Supported backends: :active_job, :sidekiq, :inline, :thread, :fiber"
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
      end

      # Execute job inline (synchronously)
      def enqueue_inline(job_class, **params)
        begin
          job_class.perform(**params)
        rescue StandardError => e
          HTM.logger.error "Inline job #{job_class.name} failed: #{e.class.name} - #{e.message}"
        end
      end

      # Execute job in background thread (legacy)
      def enqueue_thread(job_class, **params)
        Thread.new do
          begin
            job_class.perform(**params)
          rescue StandardError => e
            HTM.logger.error "Thread job #{job_class.name} failed: #{e.class.name} - #{e.message}"
          end
        end
      rescue StandardError => e
        HTM.logger.error "Failed to start thread for #{job_class.name}: #{e.message}"
      end

      # Execute job using async gem (fiber-based concurrency)
      # Non-blocking for I/O-bound operations like LLM API calls
      def enqueue_fiber(job_class, **params)
        Async do
          begin
            job_class.perform(**params)
          rescue StandardError => e
            HTM.logger.error "Fiber job #{job_class.name} failed: #{e.class.name} - #{e.message}"
          end
        end
      rescue StandardError => e
        HTM.logger.error "Failed to start fiber for #{job_class.name}: #{e.message}"
      end

      public

      # Execute multiple jobs in parallel using fibers
      # Best for I/O-bound jobs like LLM API calls
      #
      # @param jobs [Array<Array>] Array of [job_class, params] pairs
      # @return [void]
      #
      # @example Run embedding and tags jobs in parallel
      #   JobAdapter.enqueue_parallel([
      #     [GenerateEmbeddingJob, { node_id: 123 }],
      #     [GenerateTagsJob, { node_id: 123 }]
      #   ])
      #
      def enqueue_parallel(jobs)
        return if jobs.empty?

        backend = HTM.configuration.job_backend

        case backend
        when :fiber
          enqueue_parallel_fiber(jobs)
        when :inline
          # Run sequentially for inline backend
          jobs.each { |job_class, params| enqueue_inline(job_class, **params) }
        else
          # For other backends, enqueue each job separately
          jobs.each { |job_class, params| enqueue(job_class, **params) }
        end
      end

      private

      # Execute multiple jobs in parallel using async fibers
      def enqueue_parallel_fiber(jobs)
        Async do |task|
          barrier = Async::Barrier.new

          jobs.each do |job_class, params|
            barrier.async do
              begin
                job_class.perform(**params)
              rescue StandardError => e
                HTM.logger.error "Parallel fiber job #{job_class.name} failed: #{e.class.name} - #{e.message}"
              end
            end
          end

          barrier.wait
        end
      rescue StandardError => e
        HTM.logger.error "Failed to start parallel fibers: #{e.message}"
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
