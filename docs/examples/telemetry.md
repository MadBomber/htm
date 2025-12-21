# Telemetry Demo

This example demonstrates HTM's OpenTelemetry-based metrics with live Prometheus and Grafana visualization.

**Source:** [`examples/telemetry/demo.rb`](https://github.com/madbomber/htm/blob/main/examples/telemetry/demo.rb)

## Overview

The telemetry demo shows:

- Setting up Prometheus metrics collection
- Visualizing metrics in Grafana dashboards
- Available HTM metrics (jobs, latency, cache)
- Real-time monitoring during HTM operations

## Prerequisites

### macOS (Homebrew)

```bash
# Install Prometheus and Grafana
brew install prometheus grafana

# Install Ruby gems (system gems, not bundled)
gem install prometheus-client webrick

# Set database connection
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
```

## Running the Demo

```bash
cd examples/telemetry
ruby demo.rb
```

The demo will:

1. Check and start Prometheus/Grafana services
2. Configure Prometheus to scrape HTM metrics
3. Start a metrics server on port 9394
4. Run HTM operations in a loop
5. Open Grafana in your browser

## Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `htm_jobs_total` | Counter | job, status | Job execution counts |
| `htm_embedding_latency_milliseconds` | Histogram | provider, status | Embedding generation time |
| `htm_tag_latency_milliseconds` | Histogram | provider, status | Tag extraction time |
| `htm_search_latency_milliseconds` | Histogram | strategy | Search operation time |
| `htm_cache_operations_total` | Counter | operation | Cache hit/miss counts |

## Enabling Telemetry in Your App

### Configuration

```ruby
HTM.configure do |config|
  config.telemetry_enabled = true
end

# Or via environment variable
# HTM_TELEMETRY_ENABLED=true
```

### Required Gems

```ruby
# Add to your Gemfile
gem 'opentelemetry-sdk'
gem 'opentelemetry-metrics-sdk'
gem 'opentelemetry-exporter-otlp'  # For OTLP export
```

### OpenTelemetry Configuration

```bash
# Export to OTLP-compatible backend
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
```

## Grafana Dashboard

The demo includes a pre-configured Grafana dashboard:

**Location:** `examples/telemetry/grafana/dashboards/htm-metrics.json`

### Import Dashboard

1. Open Grafana at http://localhost:3000
2. Default login: admin / admin
3. Go to Dashboards > Import
4. Upload the JSON file

### Dashboard Panels

- **Job Success Rate**: Percentage of successful jobs
- **Embedding Latency**: P50, P95, P99 latencies
- **Tag Latency**: Tag extraction performance
- **Search Performance**: Query latency by strategy
- **Cache Hit Rate**: Cache effectiveness

## Architecture

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
│              │  Telemetry Collector  │                  │
│              └───────────┬───────────┘                  │
└──────────────────────────┼──────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │   /metrics endpoint     │
              │     (port 9394)         │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │      Prometheus         │
              │   (scrapes /metrics)    │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │        Grafana          │
              │    (visualization)      │
              └─────────────────────────┘
```

## Compatible Backends

HTM telemetry is OTLP-compatible and works with:

### Open Source

- Jaeger
- Prometheus + Grafana
- Grafana Tempo/Mimir
- SigNoz
- Uptrace

### Commercial

- Datadog
- New Relic
- Honeycomb
- Splunk
- Dynatrace
- AWS X-Ray
- Google Cloud Trace
- Azure Monitor

## Demo Output

```
╔══════════════════════════════════════════════════════════════════╗
║         HTM Telemetry Demo - Live Grafana Visualization          ║
╚══════════════════════════════════════════════════════════════════╝

Checking Ruby dependencies...
  [OK] prometheus-client gem
  [OK] webrick gem

Loading HTM...
  [OK] HTM 0.1.0

Starting services...
  prometheus: already running
  grafana: already running

Starting metrics server on port 9394...
  [OK] Metrics available at http://localhost:9394/metrics

Opening Grafana...
  Default login: admin / admin

============================================================
Starting demo loop...
  Metrics: http://localhost:9394/metrics
  Grafana: http://localhost:3000
============================================================

Press Ctrl+C to stop

[10:30:15] Iteration 1
  > Remember: PostgreSQL supports vector similarity search... node 42
  > Recall (fulltext): 'database    ' -> 3 results (12ms)
  > Recall (vector  ): 'database    ' -> 3 results (45ms)
  > Recall (hybrid  ): 'database    ' -> 3 results (52ms)
  Metrics exported to Prometheus
```

## Cleanup

The demo prompts to stop services on exit:

```
Stop Prometheus and Grafana services? (y/N): y
  Stopping prometheus... done
  Stopping grafana... done
  Services stopped.
```

Or stop manually:

```bash
brew services stop prometheus grafana
```

## See Also

- [Telemetry Guide](../guides/telemetry.md)
- [Observability API](../api/yard/HTM/Observability.md)
- [OpenTelemetry Ruby](https://opentelemetry.io/docs/languages/ruby/)
