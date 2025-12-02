# Module: HTM::Observability
    

Observability module for monitoring and metrics collection

Provides comprehensive monitoring of HTM components including:
*   Connection pool health monitoring with alerts
*   Query timing and performance metrics
*   Cache efficiency tracking
*   Service health checks
*   Memory usage statistics


**@example**
```ruby
stats = HTM::Observability.collect_all
puts stats[:connection_pool][:status]  # => :healthy
```
**@example**
```ruby
pool_stats = HTM::Observability.connection_pool_stats
if pool_stats[:status] == :exhausted
  logger.error "Connection pool exhausted!"
end
```
**@example**
```ruby
if HTM::Observability.healthy?
  puts "All systems operational"
else
  puts "Health check failed: #{HTM::Observability.health_check[:issues]}"
end
```
# Class Methods
## cache_stats() [](#method-c-cache_stats)
Get query cache statistics
**@return** [Hash, nil] Cache stats or nil if unavailable

## circuit_breaker_stats() [](#method-c-circuit_breaker_stats)
Get circuit breaker states for all services
**@return** [Hash] Circuit breaker states:
- :embedding_service - State and failure count
- :tag_service - State and failure count

## collect_all() [](#method-c-collect_all)
Collect all observability metrics
**@return** [Hash] Comprehensive metrics including:
- :connection_pool - Pool stats with health status
- :cache - Query cache hit rates and size
- :circuit_breakers - Service circuit breaker states
- :query_timings - Recent query performance
- :service_timings - Embedding/tag generation times
- :memory_usage - System memory stats

## connection_pool_stats() [](#method-c-connection_pool_stats)
Get connection pool statistics with health status
**@return** [Hash] Pool statistics including:
- :size - Maximum pool size
- :connections - Current total connections
- :in_use - Connections currently checked out
- :available - Connections available for checkout
- :utilization - Usage percentage (0.0-1.0)
- :status - Health status (:healthy, :warning, :critical, :exhausted)
- :wait_timeout - Connection wait timeout (ms)

## health_check() [](#method-c-health_check)
Perform comprehensive health check
**@return** [Hash] Health check results:
- :healthy - Boolean overall health status
- :checks - Individual check results
- :issues - Array of identified issues

## healthy?() [](#method-c-healthy?)
Quick health check - returns boolean
**@return** [Boolean] true if system is healthy

## memory_stats() [](#method-c-memory_stats)
Get memory usage statistics
**@return** [Hash] Memory stats

## query_timing_stats() [](#method-c-query_timing_stats)
Get query timing statistics
**@return** [Hash] Timing statistics including avg, min, max, p95

## record_embedding_timing(duration_ms ) [](#method-c-record_embedding_timing)
Record embedding generation timing
**@param** [Float] Generation duration in milliseconds

## record_query_timing(duration_ms , query_type: :unknown) [](#method-c-record_query_timing)
Record query timing for metrics
**@param** [Float] Query duration in milliseconds

**@param** [Symbol] Type of query (:vector, :fulltext, :hybrid)

## record_tag_timing(duration_ms ) [](#method-c-record_tag_timing)
Record tag extraction timing
**@param** [Float] Extraction duration in milliseconds

## reset_metrics!() [](#method-c-reset_metrics!)
Clear all collected timing metrics
**@return** [void] 

## service_timing_stats() [](#method-c-service_timing_stats)
Get service timing statistics (embedding and tag extraction)
**@return** [Hash] Timing stats for embedding and tag services


