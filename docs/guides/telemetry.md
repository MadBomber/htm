# Telemetry

HTM includes optional OpenTelemetry-based metrics for observability. Telemetry is disabled by default with zero overhead when off.

## Overview

When enabled, HTM emits metrics for:

- **Job execution** - Embedding generation and tag extraction jobs
- **Latency tracking** - Operation timing for embeddings, tags, and search
- **Cache effectiveness** - Hit/miss rates for query caching
- **Search performance** - Query latency by strategy

## Quick Start

### Enable Telemetry

```ruby
HTM.configure do |config|
  config.telemetry_enabled = true
end
```

Or via environment variable:

```bash
export HTM_TELEMETRY_ENABLED=true
```

### Install Dependencies

Telemetry uses optional OpenTelemetry gems (user installs if needed):

```ruby
# Add to Gemfile
gem 'opentelemetry-sdk'
gem 'opentelemetry-metrics-sdk'
gem 'opentelemetry-exporter-otlp'  # For OTLP export
```

### Configure Export Destination

```bash
# Export to OTLP-compatible backend
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
```

## Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `htm.jobs` | Counter | job, status | Job execution counts (embedding, tags) |
| `htm.embedding.latency` | Histogram | provider, status | Embedding generation time (ms) |
| `htm.tag.latency` | Histogram | provider, status | Tag extraction time (ms) |
| `htm.search.latency` | Histogram | strategy | Search operation time (ms) |
| `htm.cache.operations` | Counter | operation (hit/miss) | Query cache effectiveness |

## Compatible Backends

HTM telemetry is OTLP-compatible and works with:

### Open Source

- **Jaeger** - Distributed tracing
- **Prometheus + Grafana** - Metrics and visualization
- **Grafana Tempo/Mimir** - Metrics and traces
- **SigNoz** - Full-stack observability
- **Uptrace** - APM with traces and metrics

### Commercial

- **Datadog**
- **New Relic**
- **Honeycomb**
- **Splunk**
- **Dynatrace**
- **AWS X-Ray**
- **Google Cloud Trace**
- **Azure Monitor**

## Prometheus + Grafana Setup

### Install Services (macOS)

```bash
brew install prometheus grafana
brew services start prometheus grafana
```

### Configure Prometheus Scrape

Add to `/opt/homebrew/etc/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'htm'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9394']
```

### Expose Metrics Endpoint

```ruby
require 'prometheus/client'
require 'webrick'

# Create metrics endpoint
server = WEBrick::HTTPServer.new(Port: 9394)
server.mount_proc '/metrics' do |req, res|
  res['Content-Type'] = 'text/plain'
  res.body = Prometheus::Client::Formats::Text.marshal(
    Prometheus::Client.registry
  )
end

Thread.new { server.start }
```

### Grafana Dashboard

A pre-configured dashboard is available at:
`examples/telemetry/grafana/dashboards/htm-metrics.json`

Import via Grafana UI:
1. Go to Dashboards > Import
2. Upload the JSON file
3. Select your Prometheus data source

## Design

HTM uses the null object pattern for telemetry:

- **Disabled**: All metric operations are no-ops with zero overhead
- **SDK not installed**: Gracefully degrades with no errors
- **Enabled**: Full metric collection and export

```ruby
# No-op when disabled
HTM::Telemetry.record_job(:embedding, :success)  # Does nothing

# Active when enabled
HTM.configure { |c| c.telemetry_enabled = true }
HTM::Telemetry.record_job(:embedding, :success)  # Records metric
```

## Observability Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    HTM Application                      │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   remember  │  │    recall   │  │    jobs     │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         └────────────────┼────────────────┘             │
│                          │                              │
│              ┌───────────▼───────────┐                  │
│              │  HTM::Observability   │                  │
│              └───────────┬───────────┘                  │
└──────────────────────────┼──────────────────────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │   OpenTelemetry SDK     │
              └───────────┬─────────────┘
                          │
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │Prometheus│   │  Jaeger │   │ Datadog │
      └─────────┘   └─────────┘   └─────────┘
```

## Example: Live Demo

Run the included telemetry demo:

```bash
cd examples/telemetry
ruby demo.rb
```

This will:
1. Start Prometheus and Grafana services
2. Run HTM operations in a loop
3. Export metrics to Prometheus
4. Open Grafana dashboard in your browser

## Best Practices

### Development

```ruby
# Disable telemetry in development (default)
HTM.configure do |config|
  config.telemetry_enabled = false
end
```

### Production

```ruby
# Enable with OTLP export
HTM.configure do |config|
  config.telemetry_enabled = true
end

# Environment variables for backend
ENV['OTEL_METRICS_EXPORTER'] = 'otlp'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://your-backend.com:4318'
```

### Testing

```ruby
# Always disable in tests
HTM.configure do |config|
  config.telemetry_enabled = false
end
```

## See Also

- [Telemetry Example](../examples/telemetry.md)
- [Observability API](../api/yard/HTM/Observability.md)
- [OpenTelemetry Ruby](https://opentelemetry.io/docs/languages/ruby/)
