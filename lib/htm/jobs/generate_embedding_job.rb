# frozen_string_literal: true

require_relative '../errors'
require_relative '../embedding_service'

class HTM
  module Jobs
    # Background job to generate and store vector embeddings for nodes
    #
    # @see ADR-016: Async Embedding and Tag Generation
    #
    class GenerateEmbeddingJob
      # Generate embedding for a node
      #
      # @param node_id [Integer] ID of the node to process
      #
      def self.perform(node_id:)
        node = find_node(node_id) or return
        return if node.embedding

        provider   = HTM.configuration.embedding_provider.to_s
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = HTM::EmbeddingService.generate(node.content)
          node.update(embedding: result[:storage_embedding])
          record_telemetry(provider, start_time, 'success', :embedding)
          HTM.logger.info "GenerateEmbeddingJob: Generated embedding for node #{node_id} (#{result[:dimension]} dimensions)"
        rescue HTM::CircuitBreakerOpenError
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'circuit_open' })
          HTM.logger.warn "GenerateEmbeddingJob: Circuit breaker open for node #{node_id}"
        rescue HTM::EmbeddingError => e
          record_telemetry(provider, start_time, 'error', :embedding)
          HTM.logger.error "GenerateEmbeddingJob: Embedding failed for node #{node_id}: #{e.message}"
        rescue StandardError => e
          record_telemetry(provider, start_time, 'error', :embedding)
          HTM.logger.error "GenerateEmbeddingJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
        end
      end

      class << self
        private

        def find_node(node_id)
          node = HTM::Models::Node.first(id: node_id)
          HTM.logger.warn "GenerateEmbeddingJob: Node #{node_id} not found" unless node
          node
        end

        def elapsed_ms(start_time)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        end

        def record_telemetry(provider, start_time, status, metric_type)
          ms = elapsed_ms(start_time)
          HTM::Telemetry.public_send(:"#{metric_type}_latency").record(ms, attributes: { 'provider' => provider, 'status' => status })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => metric_type.to_s, 'status' => status })
        end
      end
    end
  end
end
