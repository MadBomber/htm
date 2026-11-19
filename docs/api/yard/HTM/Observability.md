# Module HTM::Observability <a id="module-HTM-Observability"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/observability.rb |

Observability module for monitoring and metrics collection

Provides comprehensive monitoring of HTM components including:
*   Connection pool health monitoring with alerts
*   Query timing and performance metrics
*   Cache efficiency tracking
*   Service health checks
*   Memory usage statistics

**@example Basic usage**
```ruby
stats = HTM::Observability.collect_all
puts stats[:connection_pool][:status]  # => :healthy
```

**@example Connection pool monitoring**
```ruby
pool_stats = HTM::Observability.connection_pool_stats
if pool_stats[:status] == :exhausted
  logger.error "Connection pool exhausted!"
end
```

**@example Health check**
```ruby
if HTM::Observability.healthy?
  puts "All systems operational"
else
  puts "Health check failed: #{HTM::Observability.health_check[:issues]}"
end
```

## Constants
### `POOL_CRITICAL_THRESHOLD` <a id="constant-POOL_CRITICAL_THRESHOLD"></a> <a id="POOL_CRITICAL_THRESHOLD-constant"></a>
75% utilization triggers warning

### `POOL_WARNING_THRESHOLD` <a id="constant-POOL_WARNING_THRESHOLD"></a> <a id="POOL_WARNING_THRESHOLD-constant"></a>
Connection pool utilization thresholds

## Public Class Methods
### `cache_stats()` <a id="method-c-cache_stats"></a> <a id="cache_stats-class_method"></a>
Get query cache statistics
- **`@return`** [Hash, nil] Cache stats or nil if unavailable

### `circuit_breaker_stats()` <a id="method-c-circuit_breaker_stats"></a> <a id="circuit_breaker_stats-class_method"></a>
Get circuit breaker states for all services
- **`@return`** [Hash] Circuit breaker states:
- :embedding_service - State and failure count
- :tag_service - State and failure count

### `collect_all()` <a id="method-c-collect_all"></a> <a id="collect_all-class_method"></a>
Collect all observability metrics
- **`@return`** [Hash] Comprehensive metrics including:
- :connection_pool - Pool stats with health status
- :cache - Query cache hit rates and size
- :circuit_breakers - Service circuit breaker states
- :query_timings - Recent query performance
- :service_timings - Embedding/tag generation times
- :memory_usage - System memory stats

### `connection_pool_stats()` <a id="method-c-connection_pool_stats"></a> <a id="connection_pool_stats-class_method"></a>
Get connection pool statistics with health status
- **`@return`** [Hash] Pool statistics including:
- :size - Maximum pool size
- :connections - Current total connections
- :in_use - Connections currently checked out
- :available - Connections available for checkout
- :utilization - Usage percentage (0.0-1.0)
- :status - Health status (:healthy, :warning, :critical, :exhausted)
- :wait_timeout - Connection wait timeout (ms)

### `health_check()` <a id="method-c-health_check"></a> <a id="health_check-class_method"></a>
Perform comprehensive health check
- **`@return`** [Hash] Health check results:
- :healthy - Boolean overall health status
- :checks - Individual check results
- :issues - Array of identified issues

### `healthy?()` <a id="method-c-healthy-3F"></a> <a id="healthy?-class_method"></a>
Quick health check - returns boolean
- **`@return`** [Boolean] true if system is healthy

### `memory_stats()` <a id="method-c-memory_stats"></a> <a id="memory_stats-class_method"></a>
Get memory usage statistics
- **`@return`** [Hash] Memory stats

### `query_timing_stats()` <a id="method-c-query_timing_stats"></a> <a id="query_timing_stats-class_method"></a>
Get query timing statistics
- **`@return`** [Hash] Timing statistics including avg, min, max, p95

### `record_embedding_timing(duration_ms)` <a id="method-c-record_embedding_timing"></a> <a id="record_embedding_timing-class_method"></a>
Record embedding generation timing
- **`@param`** `duration_ms` [Float] Generation duration in milliseconds

### `record_query_timing(duration_ms, query_type: :unknown)` <a id="method-c-record_query_timing"></a> <a id="record_query_timing-class_method"></a>
Record query timing for metrics
- **`@param`** `duration_ms` [Float] Query duration in milliseconds
- **`@param`** `query_type` [Symbol] Type of query (:vector, :fulltext, :hybrid)

### `record_tag_timing(duration_ms)` <a id="method-c-record_tag_timing"></a> <a id="record_tag_timing-class_method"></a>
Record tag extraction timing
- **`@param`** `duration_ms` [Float] Extraction duration in milliseconds

### `reset_metrics!()` <a id="method-c-reset_metrics-21"></a> <a id="reset_metrics!-class_method"></a>
Clear all collected timing metrics
- **`@return`** [void]

### `service_timing_stats()` <a id="method-c-service_timing_stats"></a> <a id="service_timing_stats-class_method"></a>
Get service timing statistics (embedding and tag extraction)
- **`@return`** [Hash] Timing stats for embedding and tag services
