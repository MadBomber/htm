# Exception: HTM::TagError
**Inherits:** HTM::Error
    

Raised when tag extraction fails

Common causes:
*   LLM provider API errors
*   Invalid tag response format
*   Network connectivity issues
*   Model not available

Note: This error is distinct from CircuitBreakerOpenError. TagError indicates
a single failure, while CircuitBreakerOpenError indicates repeated failures
have triggered protective circuit breaking.



