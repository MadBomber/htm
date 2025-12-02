# Exception: HTM::CircuitBreakerOpenError
**Inherits:** HTM::Error
    

Raised when circuit breaker is open due to repeated failures

The circuit breaker pattern protects against cascading failures when external
LLM services are unavailable. When too many consecutive failures occur, the
circuit "opens" and subsequent calls fail fast without attempting the
operation.

Circuit states:
*   :closed - Normal operation, requests flow through
*   :open - Too many failures, requests fail immediately
*   :half_open - Testing if service recovered

After a reset timeout (default: 60 seconds), the circuit transitions to
half-open and tests if the service has recovered.

**`@see`** [] 

**`@see`** [] 


**`@example`**
```ruby
begin
  htm.remember("new content")
rescue HTM::CircuitBreakerOpenError
  # LLM service unavailable, but node is still saved
  # Embeddings/tags will be generated later when service recovers
end
```

