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
          warn "GenerateEmbeddingJob: Node #{node_id} not found"
          return
        end

        # Skip if already has embedding
        if node.embedding.present?
          debug_me "GenerateEmbeddingJob: Node #{node_id} already has embedding, skipping"
          return
        end

        begin
          # Generate embedding using configured generator
          embedding = HTM.embed(node.content)

          # Prepare embedding for storage (pad to 2000 dimensions)
          actual_dimension = embedding.length
          if actual_dimension < 2000
            padded_embedding = embedding + Array.new(2000 - actual_dimension, 0.0)
          else
            padded_embedding = embedding
          end
          embedding_str = "[#{padded_embedding.join(',')}]"

          # Update node with embedding
          node.update!(
            embedding: embedding_str,
            embedding_dimension: actual_dimension
          )

          debug_me "GenerateEmbeddingJob: Successfully generated embedding for node #{node_id} (#{actual_dimension} dimensions)"

        rescue HTM::EmbeddingError => e
          # Log embedding-specific errors
          warn "GenerateEmbeddingJob: Embedding generation failed for node #{node_id}: #{e.message}"

        rescue StandardError => e
          # Log unexpected errors
          warn "GenerateEmbeddingJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
          warn e.backtrace.first(5).join("\n")
        end
      end
    end
  end
end
