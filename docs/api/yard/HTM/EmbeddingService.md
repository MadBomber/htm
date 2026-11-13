# Class HTM::EmbeddingService <a id="class-HTM-EmbeddingService"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/embedding_service.rb |

Embedding Service - Processes and validates vector embeddings

This service wraps the configured embedding generator and provides:
*   Response validation
*   Dimension handling (padding/truncation)
*   Error handling and logging
*   Storage formatting
*   Circuit breaker protection for external LLM failures

The actual LLM call is delegated to HTM.configuration.embedding_generator

## Public Class Methods
### `circuit_breaker()` <a id="method-c-circuit_breaker"></a> <a id="circuit_breaker-class_method"></a>
Get or create the circuit breaker for embedding service
- **`@return`** [HTM::CircuitBreaker] The circuit breaker instance

### `format_for_storage(embedding)` <a id="method-c-format_for_storage"></a> <a id="format_for_storage-class_method"></a>
Format embedding for database storage
- **`@param`** `embedding` [Array<Float>] Padded embedding
- **`@return`** [String] PostgreSQL array format

### `generate(text)` <a id="method-c-generate"></a> <a id="generate-class_method"></a>
Generate embedding with validation and processing
- **`@param`** `text` [String] Text to embed
- **`@raise`** [CircuitBreakerOpenError] If circuit breaker is open
- **`@return`** [Hash] Processed embedding with metadata
{
  embedding: Array<Float>,           # Original embedding
  dimension: Integer,                # Original dimension
  storage_embedding: String,         # Formatted for database storage
  storage_dimension: Integer         # Padded dimension (2000)
}

### `max_dimension()` <a id="method-c-max_dimension"></a> <a id="max_dimension-class_method"></a>
Maximum embedding dimension (configurable, default 2000)
- **`@return`** [Integer] Max dimensions for pgvector HNSW index

### `pad_embedding(embedding)` <a id="method-c-pad_embedding"></a> <a id="pad_embedding-class_method"></a>
Pad embedding to max_dimension with zeros
- **`@param`** `embedding` [Array<Float>] Original embedding
- **`@return`** [Array<Float>] Padded embedding

### `reset_circuit_breaker!()` <a id="method-c-reset_circuit_breaker-21"></a> <a id="reset_circuit_breaker!-class_method"></a>
Reset the circuit breaker (useful for testing)
- **`@return`** [void]

### `validate_embedding!(embedding)` <a id="method-c-validate_embedding-21"></a> <a id="validate_embedding!-class_method"></a>
Validate embedding response format
- **`@param`** `embedding` [Object] Raw embedding from generator
- **`@raise`** [HTM::EmbeddingError] if invalid
