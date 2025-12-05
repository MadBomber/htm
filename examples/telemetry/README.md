# HTM Telemetry Demo

This demo shows HTM metrics in a **live Grafana dashboard** using locally installed Prometheus and Grafana via Homebrew.

> **First time setup?** See [SETUP_README.md](SETUP_README.md) for detailed installation and configuration instructions.

## Quick Start

```bash
# 1. Install Prometheus and Grafana via Homebrew
brew install prometheus grafana

# 2. Install required Ruby gems
gem install prometheus-client webrick

# 3. Run the demo
cd examples/telemetry
ruby demo.rb
```

The demo will automatically:
- Check that Prometheus and Grafana are installed
- Start both services if not already running
- Configure Prometheus to scrape the demo's metrics
- Clean up any previous demo data (hard delete)
- Open Grafana in your browser
- Run HTM operations and export live metrics

## What You'll See

Once running, open Grafana at http://localhost:3000 (login: admin/admin) and import the dashboard.

### Dashboard Panels

| Panel | Description |
|-------|-------------|
| **Total Successful Jobs** | Count of completed embedding and tag jobs |
| **Total Failed Jobs** | Count of failed jobs |
| **Cache Hit Rate** | Percentage of queries served from cache |
| **LLM Job Latency (p95)** | 95th percentile latency for embedding/tag generation |
| **Search Latency by Strategy** | p95 latency for vector, fulltext, hybrid search |
| **Jobs per Minute** | Throughput by job type |
| **Cache Operations** | Hit/miss rate over time |

## Importing the Dashboard

1. Open Grafana: http://localhost:3000
2. Go to: **Dashboards** → **Import**
3. Click "Upload JSON file"
4. Select: `examples/telemetry/grafana/dashboards/htm-metrics.json`
5. Select your Prometheus datasource
6. Click **Import**

If you don't have a Prometheus datasource configured:
1. Go to: **Connections** → **Data sources** → **Add data source**
2. Select **Prometheus**
3. URL: `http://localhost:9090`
4. Click **Save & test**

## Architecture

```
┌─────────────┐                      ┌─────────────────┐
│  demo.rb    │  ──── scrapes ────▶  │   Prometheus    │
│  (metrics   │       :9394          │     :9090       │
│   server)   │                      └────────┬────────┘
└─────────────┘                               │
      │                                 PromQL queries
      │                                       │
      ▼                                       ▼
┌─────────────┐                      ┌─────────────────┐
│    HTM      │                      │    Grafana      │
│  operations │                      │     :3000       │
└─────────────┘                      └─────────────────┘
```

## Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `htm_jobs_total` | Counter | job, status | Job execution count |
| `htm_embedding_latency_milliseconds` | Histogram | provider, status | Embedding time |
| `htm_tag_latency_milliseconds` | Histogram | provider, status | Tag extraction time |
| `htm_search_latency_milliseconds` | Histogram | strategy | Search operation time |
| `htm_cache_operations_total` | Counter | operation | Cache hit/miss count |

## Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Demo Metrics | http://localhost:9394/metrics | Raw Prometheus metrics |
| Prometheus | http://localhost:9090 | Metrics storage & queries |
| Grafana | http://localhost:3000 | Visualization (admin/admin) |

## Stopping Services

The demo leaves Prometheus and Grafana running for convenience. To stop them:

```bash
brew services stop prometheus grafana
```

## Troubleshooting

### No metrics in Grafana

1. Verify the demo is running and exposing metrics:
   ```bash
   curl http://localhost:9394/metrics
   ```

2. Check Prometheus is scraping:
   - Open http://localhost:9090/targets
   - Look for `htm-demo` target with state "UP"

3. If target is missing, check Prometheus config:
   ```bash
   cat /opt/homebrew/etc/prometheus.yml
   # Should include htm-demo job
   ```

### Port already in use

If port 9394 is busy, edit `demo.rb` and change `METRICS_PORT`.

### Services won't start

```bash
# Check service status
brew services list

# View logs
brew services info prometheus
brew services info grafana
```

## Files

```
examples/telemetry/
├── README.md                 # This file
├── SETUP_README.md           # Detailed setup instructions
├── demo.rb                   # Main demo script
└── grafana/
    └── dashboards/
        └── htm-metrics.json  # Import this into Grafana
```
