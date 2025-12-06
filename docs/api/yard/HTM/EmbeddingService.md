# Class: HTM::EmbeddingService
**Inherits:** Object
    

Embedding Service - Processes and validates vector embeddings

This service wraps the configured embedding generator and provides:
*   Response validation
*   Dimension handling (padding/truncation)
*   Error handling and logging
*   Storage formatting
*   Circuit breaker protection for external LLM failures

The actual LLM call is delegated to HTM.configuration.embedding_generator


# Class Methods
## circuit_breaker() {: #method-c-circuit_breaker }
Get or create the circuit breaker for embedding service
**`@return`** [HTM::CircuitBreaker] The circuit breaker instance

## format_for_storage(embedding ) {: #method-c-format_for_storage }
Format embedding for database storage
**`@param`** [Array<Float>] Padded embedding

**`@return`** [String] PostgreSQL array format

## generate(text ) {: #method-c-generate }
Generate embedding with validation and processing
**`@param`** [String] Text to embed

**`@raise`** [CircuitBreakerOpenError] If circuit breaker is open

**`@return`** [Hash] Processed embedding with metadata
{
  embedding: Array<Float>,           # Original embedding
  dimension: Integer,                # Original dimension
  storage_embedding: String,         # Formatted for database storage
  storage_dimension: Integer         # Padded dimension (2000)
}

## max_dimension() {: #method-c-max_dimension }
Maximum embedding dimension (configurable, default 2000)
**`@return`** [Integer] Max dimensions for pgvector HNSW index

## pad_embedding(embedding ) {: #method-c-pad_embedding }
Pad embedding to max_dimension with zeros
**`@param`** [Array<Float>] Original embedding

**`@return`** [Array<Float>] Padded embedding

## reset_circuit_breaker!() {: #method-c-reset_circuit_breaker! }
Reset the circuit breaker (useful for testing)
**`@return`** [void] 

## validate_embedding!(embedding ) {: #method-c-validate_embedding! }
Validate embedding response format
**`@param`** [Object] Raw embedding from generator

**`@raise`** [HTM::EmbeddingError] if invalid


