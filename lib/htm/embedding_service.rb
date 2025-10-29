# frozen_string_literal: true

require_relative 'errors'

class HTM
  # Embedding Service - Processes and validates vector embeddings
  #
  # This service wraps the configured embedding generator and provides:
  # - Response validation
  # - Dimension handling (padding/truncation)
  # - Error handling and logging
  # - Storage formatting
  #
  # The actual LLM call is delegated to HTM.configuration.embedding_generator
  #
  class EmbeddingService
    MAX_DIMENSION = 2000  # Maximum dimension for pgvector HNSW index

    # Generate embedding with validation and processing
    #
    # @param text [String] Text to embed
    # @return [Hash] Processed embedding with metadata
    #   {
    #     embedding: Array<Float>,           # Original embedding
    #     dimension: Integer,                # Original dimension
    #     storage_embedding: String,         # Formatted for database storage
    #     storage_dimension: Integer         # Padded dimension (2000)
    #   }
    #
    def self.generate(text)
      HTM.logger.debug "EmbeddingService: Generating embedding for #{text.length} chars"

      # Call configured embedding generator
      raw_embedding = HTM.configuration.embedding_generator.call(text)

      # Validate response
      validate_embedding!(raw_embedding)

      # Get actual dimension
      actual_dimension = raw_embedding.length

      # Check dimension limit
      if actual_dimension > MAX_DIMENSION
        HTM.logger.warn "EmbeddingService: Embedding dimension #{actual_dimension} exceeds max #{MAX_DIMENSION}, truncating"
        raw_embedding = raw_embedding[0...MAX_DIMENSION]
        actual_dimension = MAX_DIMENSION
      end

      # Pad to 2000 dimensions for consistent storage
      storage_embedding = pad_embedding(raw_embedding)

      # Format for database storage
      storage_string = format_for_storage(storage_embedding)

      HTM.logger.debug "EmbeddingService: Generated #{actual_dimension}D embedding (padded to #{MAX_DIMENSION})"

      {
        embedding: raw_embedding,
        dimension: actual_dimension,
        storage_embedding: storage_string,
        storage_dimension: MAX_DIMENSION
      }

    rescue HTM::EmbeddingError
      raise
    rescue StandardError => e
      HTM.logger.error "EmbeddingService: Failed to generate embedding: #{e.message}"
      raise HTM::EmbeddingError, "Embedding generation failed: #{e.message}"
    end

    # Validate embedding response format
    #
    # @param embedding [Object] Raw embedding from generator
    # @raise [HTM::EmbeddingError] if invalid
    #
    def self.validate_embedding!(embedding)
      unless embedding.is_a?(Array)
        raise HTM::EmbeddingError, "Embedding must be an Array, got #{embedding.class}"
      end

      if embedding.empty?
        raise HTM::EmbeddingError, "Embedding array is empty"
      end

      unless embedding.all? { |v| v.is_a?(Numeric) }
        raise HTM::EmbeddingError, "Embedding must contain only numeric values"
      end

      # Check for NaN or Infinity
      if embedding.any? { |v| v.respond_to?(:nan?) && v.nan? || v.respond_to?(:infinite?) && v.infinite? }
        raise HTM::EmbeddingError, "Embedding contains NaN or Infinity values"
      end
    end

    # Pad embedding to MAX_DIMENSION with zeros
    #
    # @param embedding [Array<Float>] Original embedding
    # @return [Array<Float>] Padded embedding
    #
    def self.pad_embedding(embedding)
      return embedding if embedding.length >= MAX_DIMENSION

      embedding + Array.new(MAX_DIMENSION - embedding.length, 0.0)
    end

    # Format embedding for database storage
    #
    # @param embedding [Array<Float>] Padded embedding
    # @return [String] PostgreSQL array format
    #
    def self.format_for_storage(embedding)
      "[#{embedding.join(',')}]"
    end
  end
end
