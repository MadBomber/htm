# Class HTM::CircuitBreaker <a id="class-HTM-CircuitBreaker"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/circuit_breaker.rb |

Circuit Breaker - Prevents cascading failures from external LLM services

Implements the circuit breaker pattern to protect against repeated failures
when calling external LLM APIs for embeddings or tag extraction.

States:
*   :closed - Normal operation, requests flow through
*   :open - Circuit tripped, requests fail fast with CircuitBreakerOpenError
*   :half_open - Testing if service recovered, allows limited requests

**@example Basic usage**
```ruby
breaker = HTM::CircuitBreaker.new(name: 'embedding')
result = breaker.call { external_api_call }
```

**@example With custom thresholds**
```ruby
breaker = HTM::CircuitBreaker.new(
  name: 'tag_extraction',
  failure_threshold: 3,
  reset_timeout: 30
)
```

## Constants
### `DEFAULT_FAILURE_THRESHOLD` <a id="constant-DEFAULT_FAILURE_THRESHOLD"></a> <a id="DEFAULT_FAILURE_THRESHOLD-constant"></a>
Default configuration

### `DEFAULT_HALF_OPEN_MAX_CALLS` <a id="constant-DEFAULT_HALF_OPEN_MAX_CALLS"></a> <a id="DEFAULT_HALF_OPEN_MAX_CALLS-constant"></a>
Seconds before trying half-open

### `DEFAULT_RESET_TIMEOUT` <a id="constant-DEFAULT_RESET_TIMEOUT"></a> <a id="DEFAULT_RESET_TIMEOUT-constant"></a>
Failures before opening circuit

## Attributes
### `failure_count` [R] <a id="attribute-i-failure_count"></a> <a id="failure_count-instance_method"></a>
Returns the value of attribute failure_count.

### `last_failure_time` [R] <a id="attribute-i-last_failure_time"></a> <a id="last_failure_time-instance_method"></a>
Returns the value of attribute last_failure_time.

### `name` [R] <a id="attribute-i-name"></a> <a id="name-instance_method"></a>
Returns the value of attribute name.

### `state` [R] <a id="attribute-i-state"></a> <a id="state-instance_method"></a>
Returns the value of attribute state.

## Public Instance Methods
### `call()` <a id="method-i-call"></a> <a id="call-instance_method"></a>
Execute a block with circuit breaker protection
- **`@raise`** [CircuitBreakerOpenError] If circuit is open
- **`@raise`** [StandardError] If the block raises an error (after recording failure)
- **`@return`** [Object] Result of the block if successful
- **`@yield`** Block containing the protected operation

### `closed?()` <a id="method-i-closed-3F"></a> <a id="closed?-instance_method"></a>
Check if circuit is currently closed (normal operation)
- **`@return`** [Boolean] true if circuit is closed

### `half_open?()` <a id="method-i-half_open-3F"></a> <a id="half_open?-instance_method"></a>
Check if circuit is in half-open state (testing recovery)
- **`@return`** [Boolean] true if circuit is half-open

### `initialize(name:, failure_threshold: DEFAULT_FAILURE_THRESHOLD, reset_timeout: DEFAULT_RESET_TIMEOUT, half_open_max_calls: DEFAULT_HALF_OPEN_MAX_CALLS)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize a new circuit breaker
- **`@param`** `name` [String] Identifier for this circuit breaker (for logging)
- **`@param`** `failure_threshold` [Integer] Number of failures before opening circuit
- **`@param`** `reset_timeout` [Integer] Seconds to wait before attempting recovery
- **`@param`** `half_open_max_calls` [Integer] Successful calls needed to close circuit
- **`@return`** [CircuitBreaker] a new instance of CircuitBreaker

### `open?()` <a id="method-i-open-3F"></a> <a id="open?-instance_method"></a>
Check if circuit is currently open
- **`@return`** [Boolean] true if circuit is open

### `reset!()` <a id="method-i-reset-21"></a> <a id="reset!-instance_method"></a>
Manually reset the circuit breaker to closed state
- **`@return`** [void]

### `stats()` <a id="method-i-stats"></a> <a id="stats-instance_method"></a>
Get current circuit breaker statistics
- **`@return`** [Hash] Statistics including state, failure count, etc.
