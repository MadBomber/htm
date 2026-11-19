# Class HTM::CircuitBreakerOpenError <a id="class-HTM-CircuitBreakerOpenError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::Error](Error.md) |
| **Defined in** | lib/htm/errors.rb |

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

- **`@see`** `HTM::CircuitBreaker`
- **`@see`** `HTM::Observability.circuit_breaker_stats`

**@example Handling circuit breaker**
```ruby
begin
  htm.remember("new content")
rescue HTM::CircuitBreakerOpenError
  # LLM service unavailable, but node is still saved
  # Embeddings/tags will be generated later when service recovers
end
```
