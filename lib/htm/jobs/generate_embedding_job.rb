# frozen_string_literal: true

require_relative '../errors'
require_relative '../models/node'
require_relative '../embedding_service'

class HTM
  module Jobs
    # Background job to generate and store vector embeddings for nodes
    #
    # This job is enqueued after a node is saved to avoid blocking the
    # main request path. It generates embeddings asynchronously and updates
    # the node record with the embedding vector.
    #
    # @see ADR-016: Async Embedding and Tag Generation
    #
    class GenerateEmbeddingJob
      # Generate embedding for a node
      #
      # Uses the configured embedding generator (HTM.embed) which delegates
      # to the application-provided or default RubyLLM implementation.
      #
      # @param node_id [Integer] ID of the node to process
      #
      def self.perform(node_id:)
        node = HTM::Models::Node.find_by(id: node_id)

        unless node
          HTM.logger.warn "GenerateEmbeddingJob: Node #{node_id} not found"
          return
        end

        # Skip if already has embedding
        if node.embedding.present?
          HTM.logger.debug "GenerateEmbeddingJob: Node #{node_id} already has embedding, skipping"
          return
        end

        provider = HTM.configuration.embedding_provider.to_s
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          HTM.logger.debug "GenerateEmbeddingJob: Generating embedding for node #{node_id}"

          # Generate and process embedding using EmbeddingService
          result = HTM::EmbeddingService.generate(node.content)

          # Update node with processed embedding
          node.update!(embedding: result[:storage_embedding])

          # Record success metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.embedding_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'success' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'success' })

          HTM.logger.info "GenerateEmbeddingJob: Successfully generated embedding for node #{node_id} (#{result[:dimension]} dimensions)"

        rescue HTM::CircuitBreakerOpenError => e
          # Circuit breaker is open - service is unavailable, will retry later
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'circuit_open' })
          HTM.logger.warn "GenerateEmbeddingJob: Circuit breaker open for node #{node_id}, will retry when service recovers"

        rescue HTM::EmbeddingError => e
          # Record failure metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.embedding_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'error' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'error' })

          # Log embedding-specific errors
          HTM.logger.error "GenerateEmbeddingJob: Embedding generation failed for node #{node_id}: #{e.message}"

        rescue StandardError => e
          # Record failure metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.embedding_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'error' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'error' })

          # Log unexpected errors
          HTM.logger.error "GenerateEmbeddingJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
          HTM.logger.debug e.backtrace.first(5).join("\n")
        end
      end
    end
  end
end
