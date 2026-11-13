# Module HTM::Telemetry <a id="module-HTM-Telemetry"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/telemetry.rb |

OpenTelemetry-based observability for HTM

Provides opt-in metrics collection with zero overhead when disabled. Uses the
null object pattern - when telemetry is disabled or the SDK is not available,
all metric operations are no-ops.

- **`@see`** `notes/ot.md` for full implementation details

**@example Enable telemetry**
```ruby
HTM.configure do |config|
  config.telemetry_enabled = true
end
```

**@example Set destination via environment**
```ruby
# Export to OTLP endpoint
ENV['OTEL_METRICS_EXPORTER'] = 'otlp'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4318'
```

## Public Class Methods
### `cache_operations()` <a id="method-c-cache_operations"></a> <a id="cache_operations-class_method"></a>
Counter for cache operations (hits, misses)
- **`@return`** [OpenTelemetry::Metrics::Counter, NullInstrument]

**@example Record a cache hit**
```ruby
Telemetry.cache_operations.add(1, attributes: { 'operation' => 'hit' })
```

### `embedding_latency()` <a id="method-c-embedding_latency"></a> <a id="embedding_latency-class_method"></a>
Histogram for embedding generation latency
- **`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument]

**@example Record latency**
```ruby
Telemetry.embedding_latency.record(145, attributes: { 'provider' => 'ollama', 'status' => 'success' })
```

### `enabled?()` <a id="method-c-enabled-3F"></a> <a id="enabled?-class_method"></a>
Check if telemetry is enabled and SDK is available
- **`@return`** [Boolean] true if telemetry should be active

### `job_counter()` <a id="method-c-job_counter"></a> <a id="job_counter-class_method"></a>
Counter for job execution (enqueued, completed, failed)
- **`@return`** [OpenTelemetry::Metrics::Counter, NullInstrument]

**@example Record a completed job**
```ruby
Telemetry.job_counter.add(1, attributes: { 'job' => 'embedding', 'status' => 'success' })
```

### `measure(histogram, attributes = {})` <a id="method-c-measure"></a> <a id="measure-class_method"></a>
Measure execution time of a block and record to a histogram
- **`@param`** `histogram` [OpenTelemetry::Metrics::Histogram, NullInstrument] The histogram to record to
- **`@param`** `attributes` [Hash] Attributes to attach to the measurement
- **`@return`** [Object] The result of the block
- **`@yield`** The block to measure

**@example Measure embedding generation**
```ruby
result = Telemetry.measure(Telemetry.embedding_latency, 'provider' => 'ollama') do
  generate_embedding(text)
end
```

### `meter()` <a id="method-c-meter"></a> <a id="meter-class_method"></a>
Get the meter for creating instruments
- **`@return`** [OpenTelemetry::Metrics::Meter, NullMeter] Real or null meter

### `reset!()` <a id="method-c-reset-21"></a> <a id="reset!-class_method"></a>
Reset telemetry state (for testing)
- **`@return`** [void]

### `sdk_available?()` <a id="method-c-sdk_available-3F"></a> <a id="sdk_available?-class_method"></a>
Check if OpenTelemetry SDK is installed
- **`@return`** [Boolean] true if SDK can be loaded

### `search_latency()` <a id="method-c-search_latency"></a> <a id="search_latency-class_method"></a>
Histogram for search operation latency
- **`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument]

**@example Record latency**
```ruby
Telemetry.search_latency.record(50, attributes: { 'strategy' => 'vector' })
```

### `setup()` <a id="method-c-setup"></a> <a id="setup-class_method"></a>
Initialize OpenTelemetry SDK

Called automatically when telemetry is enabled. Safe to call multiple times.
- **`@return`** [void]

### `tag_latency()` <a id="method-c-tag_latency"></a> <a id="tag_latency-class_method"></a>
Histogram for tag extraction latency
- **`@return`** [OpenTelemetry::Metrics::Histogram, NullInstrument]

**@example Record latency**
```ruby
Telemetry.tag_latency.record(250, attributes: { 'provider' => 'ollama', 'status' => 'success' })
```
