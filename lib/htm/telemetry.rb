# frozen_string_literal: true

require 'singleton'

class HTM
  # OpenTelemetry-based observability for HTM
  #
  # Provides opt-in metrics collection with zero overhead when disabled.
  # Uses the null object pattern - when telemetry is disabled or the SDK
  # is not available, all metric operations are no-ops.
  #
  # @example Enable telemetry
  #   HTM.configure do |config|
  #     config.telemetry_enabled = true
  #   end
  #
  # @example Set destination via environment
  #   # Export to OTLP endpoint
  #   ENV['OTEL_METRICS_EXPORTER'] = 'otlp'
  #   ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4318'
  #
  # @see notes/ot.md for full implementation details
  #
  module Telemetry
    # Null meter that creates null instruments
    # Used when telemetry is disabled or SDK unavailable
    class NullMeter
      include Singleton

      def create_counter(*)
        NullInstrument.instance
      end

      def create_histogram(*)
        NullInstrument.instance
      end

      def create_up_down_counter(*)
        NullInstrument.instance
      end
    end

    # Null instrument that accepts but ignores all metric operations
    class NullInstrument
      include Singleton

      def add(*) = nil
      def record(*) = nil
    end

    class << self
      # Check if telemetry is enabled and SDK is available
      #
      # @return [Boolean] true if telemetry should be active
      #
      def enabled?
        HTM.configuration.telemetry_enabled && sdk_available?
      end

      # Check if OpenTelemetry SDK is installed
      #
      # @return [Boolean] true if SDK can be loaded
      #
      def sdk_available?
        return @sdk_available if defined?(@sdk_available)

        @sdk_available = begin
          require 'opentelemetry-metrics-sdk'
          true
        rescue LoadError
          false
        end
      end

      # Initialize OpenTelemetry SDK
      #
      # Called automatically when telemetry is enabled.
      # Safe to call multiple times.
      #
      # @return [void]
      #
      def setup
        return unless enabled?
        return if @setup_complete

        OpenTelemetry::SDK.configure do |c|
          c.service_name = 'htm'
        end

        @setup_complete = true
        HTM.logger.info "Telemetry: OpenTelemetry SDK initialized"
      end

      # Get the meter for creating instruments
      #
      # @return [OpenTelemetry::Metrics::Meter, NullMeter] Real or null meter
      #
      def meter
        return NullMeter.instance unless enabled?

        setup
        @meter ||= OpenTelemetry.meter_provider.meter('htm')
      end

      # Reset telemetry state (for testing)
      #
      # @return [void]
      #
      def reset!
        @meter = nil
        @job_counter = nil
        @embedding_latency = nil
        @tag_latency = nil
        @search_latency = nil
        @cache_operations = nil
        @setup_complete = false
        # Don't reset @sdk_available - that's a system property
      end

      # =========================================
      # Instrument Accessors
      # =========================================

      # Counter for job execution (enqueued, completed, failed)
      #
      # @return [OpenTelemetry::Metrics::Counter, NullInstrument]
      #
      # @example Record a completed job
      #   Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'success' })
      #
      def job_counter
        @job_counter ||= meter.create_counter(
          'htm.jobs',
          unit: 'count',
          description: 'Job execution counts by type and status'
        )
      end

      # Histogram for embedding generation latency
      #
      # @return [OpenTelemetry::Metrics::Histogram, NullInstrument]
      #
      # @example Record latency
      #   Telemetry.embedding_latency.record(145, attributes: { 'provider' => 'ollama', 'status' => 'success' })
      #
      def embedding_latency
        @embedding_latency ||= meter.create_histogram(
          'htm.embedding.latency',
          unit: 'ms',
          description: 'Embedding generation latency in milliseconds'
        )
      end

      # Histogram for tag extraction latency
      #
      # @return [OpenTelemetry::Metrics::Histogram, NullInstrument]
      #
      # @example Record latency
      #   Telemetry.tag_latency.record(250, attributes: { 'provider' => 'ollama', 'status' => 'success' })
      #
      def tag_latency
        @tag_latency ||= meter.create_histogram(
          'htm.tag.latency',
          unit: 'ms',
          description: 'Tag extraction latency in milliseconds'
        )
      end

      # Histogram for search operation latency
      #
      # @return [OpenTelemetry::Metrics::Histogram, NullInstrument]
      #
      # @example Record latency
      #   Telemetry.search_latency.record(50, attributes: { 'strategy' => 'vector' })
      #
      def search_latency
        @search_latency ||= meter.create_histogram(
          'htm.search.latency',
          unit: 'ms',
          description: 'Search operation latency in milliseconds'
        )
      end

      # Counter for cache operations (hits, misses)
      #
      # @return [OpenTelemetry::Metrics::Counter, NullInstrument]
      #
      # @example Record a cache hit
      #   Telemetry.cache_operations.add(1, attributes: { 'operation' => 'hit' })
      #
      def cache_operations
        @cache_operations ||= meter.create_counter(
          'htm.cache.operations',
          unit: 'count',
          description: 'Cache hit/miss counts'
        )
      end

      # =========================================
      # Convenience Methods for Timing
      # =========================================

      # Measure execution time of a block and record to a histogram
      #
      # @param histogram [OpenTelemetry::Metrics::Histogram, NullInstrument] The histogram to record to
      # @param attributes [Hash] Attributes to attach to the measurement
      # @yield The block to measure
      # @return [Object] The result of the block
      #
      # @example Measure embedding generation
      #   result = Telemetry.measure(Telemetry.embedding_latency, 'provider' => 'ollama') do
      #     generate_embedding(text)
      #   end
      #
      def measure(histogram, attributes = {})
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        histogram.record(elapsed_ms, attributes: attributes)
        result
      end
    end
  end
end
