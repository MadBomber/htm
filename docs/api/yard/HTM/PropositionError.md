# Exception: HTM::PropositionError
**Inherits:** HTM::Error
    

Raised when proposition extraction fails

Common causes:
*   LLM provider API errors
*   Invalid proposition response format
*   Network connectivity issues
*   Model not available

Note: This error is distinct from CircuitBreakerOpenError. PropositionError
indicates a single failure, while CircuitBreakerOpenError indicates repeated
failures have triggered protective circuit breaking.



