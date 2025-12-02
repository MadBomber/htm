# Exception: HTM::EmbeddingError
**Inherits:** HTM::Error
    

Raised when embedding generation fails

Common causes:
*   LLM provider API errors
*   Invalid embedding response format
*   Network connectivity issues
*   Model not available

Note: This error is distinct from CircuitBreakerOpenError. EmbeddingError
indicates a single failure, while CircuitBreakerOpenError indicates repeated
failures have triggered protective circuit breaking.



