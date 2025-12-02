# Class: HTM::CircuitBreaker
**Inherits:** Object
    

Circuit Breaker - Prevents cascading failures from external LLM services

Implements the circuit breaker pattern to protect against repeated failures
when calling external LLM APIs for embeddings or tag extraction.

States:
*   :closed - Normal operation, requests flow through
*   :open - Circuit tripped, requests fail fast with CircuitBreakerOpenError
*   :half_open - Testing if service recovered, allows limited requests


**`@example`**
```ruby
breaker = HTM::CircuitBreaker.new(name: 'embedding')
result = breaker.call { external_api_call }
```
**`@example`**
```ruby
breaker = HTM::CircuitBreaker.new(
  name: 'tag_extraction',
  failure_threshold: 3,
  reset_timeout: 30
)
```
# Attributes
## failure_count[RW] {: #attribute-i-failure_count }
Returns the value of attribute failure_count.

## last_failure_time[RW] {: #attribute-i-last_failure_time }
Returns the value of attribute last_failure_time.

## name[RW] {: #attribute-i-name }
Returns the value of attribute name.

## state[RW] {: #attribute-i-state }
Returns the value of attribute state.


# Instance Methods
## call() {: #method-i-call }
Execute a block with circuit breaker protection

**`@raise`** [CircuitBreakerOpenError] If circuit is open

**`@raise`** [StandardError] If the block raises an error (after recording failure)

**`@return`** [Object] Result of the block if successful

**`@yield`** [] Block containing the protected operation

## closed?() {: #method-i-closed? }
Check if circuit is currently closed (normal operation)

**`@return`** [Boolean] true if circuit is closed

## half_open?() {: #method-i-half_open? }
Check if circuit is in half-open state (testing recovery)

**`@return`** [Boolean] true if circuit is half-open

## initialize(name:, failure_threshold:DEFAULT_FAILURE_THRESHOLD, reset_timeout:DEFAULT_RESET_TIMEOUT, half_open_max_calls:DEFAULT_HALF_OPEN_MAX_CALLS) {: #method-i-initialize }
Initialize a new circuit breaker

**`@param`** [String] Identifier for this circuit breaker (for logging)

**`@param`** [Integer] Number of failures before opening circuit

**`@param`** [Integer] Seconds to wait before attempting recovery

**`@param`** [Integer] Successful calls needed to close circuit

**`@return`** [CircuitBreaker] a new instance of CircuitBreaker

## open?() {: #method-i-open? }
Check if circuit is currently open

**`@return`** [Boolean] true if circuit is open

## reset!() {: #method-i-reset! }
Manually reset the circuit breaker to closed state

**`@return`** [void] 

## stats() {: #method-i-stats }
Get current circuit breaker statistics

**`@return`** [Hash] Statistics including state, failure count, etc.

