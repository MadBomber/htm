# frozen_string_literal: true

class HTM
  # Observability module for monitoring and metrics collection
  #
  # Provides comprehensive monitoring of HTM components including:
  # - Connection pool health monitoring with alerts
  # - Query timing and performance metrics
  # - Cache efficiency tracking
  # - Service health checks
  # - Memory usage statistics
  #
  # @example Basic usage
  #   stats = HTM::Observability.collect_all
  #   puts stats[:connection_pool][:status]  # => :healthy
  #
  # @example Connection pool monitoring
  #   pool_stats = HTM::Observability.connection_pool_stats
  #   if pool_stats[:status] == :exhausted
  #     logger.error "Connection pool exhausted!"
  #   end
  #
  # @example Health check
  #   if HTM::Observability.healthy?
  #     puts "All systems operational"
  #   else
  #     puts "Health check failed: #{HTM::Observability.health_check[:issues]}"
  #   end
  #
  module Observability
    # Connection pool utilization thresholds
    POOL_WARNING_THRESHOLD = 0.75  # 75% utilization triggers warning
    POOL_CRITICAL_THRESHOLD = 0.90 # 90% utilization triggers critical

    # Timing metrics storage (thread-safe)
    @metrics_mutex = Mutex.new
    @query_timings = []
    @embedding_timings = []
    @tag_extraction_timings = []
    @max_timing_samples = 1000

    class << self
      # Collect all observability metrics
      #
      # @return [Hash] Comprehensive metrics including:
      #   - :connection_pool - Pool stats with health status
      #   - :cache - Query cache hit rates and size
      #   - :circuit_breakers - Service circuit breaker states
      #   - :query_timings - Recent query performance
      #   - :service_timings - Embedding/tag generation times
      #   - :memory_usage - System memory stats
      #
      def collect_all
        {
          connection_pool: connection_pool_stats,
          cache: cache_stats,
          circuit_breakers: circuit_breaker_stats,
          query_timings: query_timing_stats,
          service_timings: service_timing_stats,
          memory_usage: memory_stats,
          collected_at: Time.current
        }
      end

      # Get connection pool statistics with health status
      #
      # @return [Hash] Pool statistics including:
      #   - :size - Maximum pool size
      #   - :connections - Current total connections
      #   - :in_use - Connections currently checked out
      #   - :available - Connections available for checkout
      #   - :utilization - Usage percentage (0.0-1.0)
      #   - :status - Health status (:healthy, :warning, :critical, :exhausted)
      #   - :wait_timeout - Connection wait timeout (ms)
      #
      def connection_pool_stats
        return { status: :unavailable, message: "ActiveRecord not connected" } unless connected?

        pool = ActiveRecord::Base.connection_pool

        size = pool.size
        connections = pool.connections.size
        in_use = pool.connections.count(&:in_use?)
        available = connections - in_use

        # Calculate utilization based on connections in use vs pool size
        utilization = size > 0 ? in_use.to_f / size : 0.0

        # Determine health status
        status = case
        when available == 0 && in_use >= size
          :exhausted
        when utilization >= POOL_CRITICAL_THRESHOLD
          :critical
        when utilization >= POOL_WARNING_THRESHOLD
          :warning
        else
          :healthy
        end

        stats = {
          size: size,
          connections: connections,
          in_use: in_use,
          available: available,
          utilization: (utilization * 100).round(2),
          status: status,
          wait_timeout: pool.checkout_timeout * 1000 # Convert to ms
        }

        # Log warnings if pool is stressed
        log_pool_status(stats)

        stats
      rescue StandardError => e
        { status: :error, message: e.message }
      end

      # Get query cache statistics
      #
      # @return [Hash, nil] Cache stats or nil if unavailable
      #
      def cache_stats
        # Try to access LongTermMemory cache stats
        # Note: This requires access to an LTM instance
        {
          info: "Cache stats available via LongTermMemory#stats[:cache]"
        }
      end

      # Get circuit breaker states for all services
      #
      # @return [Hash] Circuit breaker states:
      #   - :embedding_service - State and failure count
      #   - :tag_service - State and failure count
      #
      def circuit_breaker_stats
        stats = {}

        if defined?(HTM::EmbeddingService)
          cb = HTM::EmbeddingService.circuit_breaker
          stats[:embedding_service] = {
            state: cb.state,
            failure_count: cb.failure_count,
            last_failure_time: cb.last_failure_time
          }
        end

        if defined?(HTM::TagService)
          cb = HTM::TagService.circuit_breaker
          stats[:tag_service] = {
            state: cb.state,
            failure_count: cb.failure_count,
            last_failure_time: cb.last_failure_time
          }
        end

        stats
      rescue StandardError => e
        { error: e.message }
      end

      # Record query timing for metrics
      #
      # @param duration_ms [Float] Query duration in milliseconds
      # @param query_type [Symbol] Type of query (:vector, :fulltext, :hybrid)
      #
      def record_query_timing(duration_ms, query_type: :unknown)
        @metrics_mutex.synchronize do
          @query_timings << {
            duration_ms: duration_ms,
            query_type: query_type,
            recorded_at: Time.current
          }

          # Keep only recent samples
          @query_timings.shift if @query_timings.size > @max_timing_samples
        end
      end

      # Record embedding generation timing
      #
      # @param duration_ms [Float] Generation duration in milliseconds
      #
      def record_embedding_timing(duration_ms)
        @metrics_mutex.synchronize do
          @embedding_timings << {
            duration_ms: duration_ms,
            recorded_at: Time.current
          }
          @embedding_timings.shift if @embedding_timings.size > @max_timing_samples
        end
      end

      # Record tag extraction timing
      #
      # @param duration_ms [Float] Extraction duration in milliseconds
      #
      def record_tag_timing(duration_ms)
        @metrics_mutex.synchronize do
          @tag_extraction_timings << {
            duration_ms: duration_ms,
            recorded_at: Time.current
          }
          @tag_extraction_timings.shift if @tag_extraction_timings.size > @max_timing_samples
        end
      end

      # Get query timing statistics
      #
      # @return [Hash] Timing statistics including avg, min, max, p95
      #
      def query_timing_stats
        calculate_timing_stats(@query_timings, :query)
      end

      # Get service timing statistics (embedding and tag extraction)
      #
      # @return [Hash] Timing stats for embedding and tag services
      #
      def service_timing_stats
        {
          embedding: calculate_timing_stats(@embedding_timings, :embedding),
          tag_extraction: calculate_timing_stats(@tag_extraction_timings, :tag)
        }
      end

      # Get memory usage statistics
      #
      # @return [Hash] Memory stats
      #
      def memory_stats
        {
          process_rss_mb: process_memory_mb,
          gc_stats: GC.stat.slice(:count, :heap_allocated_pages, :heap_live_slots)
        }
      rescue StandardError
        { available: false }
      end

      # Perform comprehensive health check
      #
      # @return [Hash] Health check results:
      #   - :healthy - Boolean overall health status
      #   - :checks - Individual check results
      #   - :issues - Array of identified issues
      #
      def health_check
        checks = {}
        issues = []

        # Check database connection
        checks[:database] = connected?
        issues << "Database not connected" unless checks[:database]

        # Check connection pool
        pool_stats = connection_pool_stats
        checks[:connection_pool] = pool_stats[:status] == :healthy || pool_stats[:status] == :warning
        issues << "Connection pool #{pool_stats[:status]}" if [:critical, :exhausted].include?(pool_stats[:status])

        # Check circuit breakers
        cb_stats = circuit_breaker_stats
        if cb_stats[:embedding_service]
          checks[:embedding_circuit] = cb_stats[:embedding_service][:state] != :open
          issues << "Embedding service circuit breaker open" unless checks[:embedding_circuit]
        end
        if cb_stats[:tag_service]
          checks[:tag_circuit] = cb_stats[:tag_service][:state] != :open
          issues << "Tag service circuit breaker open" unless checks[:tag_circuit]
        end

        # Check required extensions
        if connected?
          begin
            checks[:pgvector] = extension_installed?('vector')
            issues << "pgvector extension not installed" unless checks[:pgvector]

            checks[:pg_trgm] = extension_installed?('pg_trgm')
            issues << "pg_trgm extension not installed" unless checks[:pg_trgm]
          rescue StandardError => e
            checks[:extensions] = false
            issues << "Failed to check extensions: #{e.message}"
          end
        end

        {
          healthy: issues.empty?,
          checks: checks,
          issues: issues,
          checked_at: Time.current
        }
      end

      # Quick health check - returns boolean
      #
      # @return [Boolean] true if system is healthy
      #
      def healthy?
        health_check[:healthy]
      end

      # Clear all collected timing metrics
      #
      # @return [void]
      #
      def reset_metrics!
        @metrics_mutex.synchronize do
          @query_timings.clear
          @embedding_timings.clear
          @tag_extraction_timings.clear
        end
      end

      private

      # Check if ActiveRecord is connected
      def connected?
        return false unless defined?(ActiveRecord::Base)
        ActiveRecord::Base.connected? && ActiveRecord::Base.connection.active?
      rescue StandardError
        false
      end

      # Check if a PostgreSQL extension is installed
      def extension_installed?(name)
        result = ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM pg_extension WHERE extname = '#{name}'"
        )
        result.to_i > 0
      end

      # Calculate timing statistics from samples
      def calculate_timing_stats(timings, type)
        @metrics_mutex.synchronize do
          return { sample_count: 0 } if timings.empty?

          durations = timings.map { |t| t[:duration_ms] }.sort
          count = durations.size

          {
            sample_count: count,
            avg_ms: (durations.sum / count).round(2),
            min_ms: durations.first.round(2),
            max_ms: durations.last.round(2),
            p50_ms: percentile(durations, 50).round(2),
            p95_ms: percentile(durations, 95).round(2),
            p99_ms: percentile(durations, 99).round(2)
          }
        end
      end

      # Calculate percentile from sorted array
      def percentile(sorted_array, percentile)
        return 0 if sorted_array.empty?

        k = (percentile / 100.0 * (sorted_array.size - 1))
        f = k.floor
        c = k.ceil

        return sorted_array[f] if f == c

        sorted_array[f] * (c - k) + sorted_array[c] * (k - f)
      end

      # Get process memory in MB
      def process_memory_mb
        if RUBY_PLATFORM.include?('darwin')
          # macOS: Use ps command
          `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024.0
        elsif File.exist?('/proc/self/status')
          # Linux: Read from proc
          File.read('/proc/self/status').match(/VmRSS:\s+(\d+)/)[1].to_i / 1024.0
        else
          nil
        end
      rescue StandardError
        nil
      end

      # Log pool status based on health
      def log_pool_status(stats)
        case stats[:status]
        when :exhausted
          HTM.logger.error "Connection pool EXHAUSTED: #{stats[:in_use]}/#{stats[:size]} connections in use (#{stats[:utilization]}%)"
        when :critical
          HTM.logger.warn "Connection pool CRITICAL: #{stats[:in_use]}/#{stats[:size]} connections in use (#{stats[:utilization]}%)"
        when :warning
          HTM.logger.warn "Connection pool WARNING: #{stats[:in_use]}/#{stats[:size]} connections in use (#{stats[:utilization]}%)"
        end
      end
    end
  end
end
