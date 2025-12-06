# Module: HTM::Telemetry
    

OpenTelemetry-based observability for HTM

Provides opt-in metrics collection with zero overhead when disabled. Uses the
null object pattern - when telemetry is disabled or the SDK is not available,
all metric operations are no-ops.

**`@see`** [] for full implementation details


**`@example`**
```ruby
HTM.configure do |config|
  config.telemetry_enabled = true
end
```
**`@example`**
```ruby
# Export to OTLP endpoint
ENV['OTEL_METRICS_EXPORTER'] = 'otlp'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4318'
```
# Class Methods
## cache_operations() {: #method-c-cache_operations }
Counter for cache operations (hits, misses)
**`@return`** [OpenTelemetry::Metrics::Counter, NullInstrument] 


**`@example`**
```ruby
Telemetry.cache_operations.add(1, attributes: { 'operation' => 'hit' })
```
## embedding_latency() {: #method-c-embedding_latency }
Histogram for embedding generation latency
**`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument] 


**`@example`**
```ruby
Telemetry.embedding_latency.record(145, attributes: { 'provider' => 'ollama', 'status' => 'success' })
```
## enabled?() {: #method-c-enabled? }
Check if telemetry is enabled and SDK is available
**`@return`** [Boolean] true if telemetry should be active

## job_counter() {: #method-c-job_counter }
Counter for job execution (enqueued, completed, failed)
**`@return`** [OpenTelemetry::Metrics::Counter, NullInstrument] 


**`@example`**
```ruby
Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'success' })
```
## measure(histogram , attributes {}) {: #method-c-measure }
Measure execution time of a block and record to a histogram
**`@param`** [OpenTelemetry::Metrics::Histogram, NullInstrument] The histogram to record to

**`@param`** [Hash] Attributes to attach to the measurement

**`@return`** [Object] The result of the block

**`@yield`** [] The block to measure


**`@example`**
```ruby
result = Telemetry.measure(Telemetry.embedding_latency, 'provider' => 'ollama') do
  generate_embedding(text)
end
```
## meter() {: #method-c-meter }
Get the meter for creating instruments
**`@return`** [OpenTelemetry::Metrics::Meter, NullMeter] Real or null meter

## reset!() {: #method-c-reset! }
Reset telemetry state (for testing)
**`@return`** [void] 

## sdk_available?() {: #method-c-sdk_available? }
Check if OpenTelemetry SDK is installed
**`@return`** [Boolean] true if SDK can be loaded

## search_latency() {: #method-c-search_latency }
Histogram for search operation latency
**`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument] 


**`@example`**
```ruby
Telemetry.search_latency.record(50, attributes: { 'strategy' => 'vector' })
```
## setup() {: #method-c-setup }
Initialize OpenTelemetry SDK

Called automatically when telemetry is enabled. Safe to call multiple times.
**`@return`** [void] 

## tag_latency() {: #method-c-tag_latency }
Histogram for tag extraction latency
**`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument] 


**`@example`**
```ruby
Telemetry.tag_latency.record(250, attributes: { 'provider' => 'ollama', 'status' => 'success' })
```
