# HTM Telemetry Demo Setup

This guide walks you through setting up Prometheus and Grafana to visualize HTM metrics.

## Prerequisites

### 1. Install Prometheus and Grafana via Homebrew

```bash
brew install prometheus grafana
```

### 2. Install Required Ruby Gems

```bash
gem install prometheus-client webrick
```

## Starting the Services

### Start Prometheus and Grafana

```bash
brew services start prometheus
brew services start grafana
```

Verify they're running:

```bash
brew services list | grep -E 'prometheus|grafana'
```

Both should show `started` status.

## Configure Grafana

### 1. Access Grafana

Open http://localhost:3000 in your browser.

**Default credentials:**
- Username: `admin`
- Password: `admin`

You'll be prompted to change the password on first login.

### 2. Add Prometheus Data Source

1. Go to **Connections** → **Data sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Enter URL: `http://localhost:9090`
5. Click **Save & test**

You should see "Successfully queried the Prometheus API."

### 3. Import the HTM Dashboard

1. Go to **Dashboards** → **Import**
2. Click **Upload JSON file**
3. Select: `examples/telemetry/grafana/dashboards/htm-metrics.json`
4. Select your Prometheus datasource from the dropdown
5. Click **Import**

## Running the Demo

```bash
cd examples/telemetry
./demo.rb
```

The demo will:
- Verify Prometheus and Grafana are installed and running
- Configure Prometheus to scrape metrics from port 9394
- Clean up any previous demo data
- Open Grafana in your browser
- Run HTM operations in a loop, exporting metrics

## Viewing Metrics

Once the demo is running, view the dashboard at:

http://localhost:3000/d/htm-metrics/htm-metrics

The dashboard shows:
- **Total Successful Jobs** - Embedding and tag job completions
- **Total Failed Jobs** - Job failures
- **Cache Hit Rate** - Query cache effectiveness
- **LLM Job Latency (p95)** - Embedding and tag generation times
- **Search Latency by Strategy** - Vector, fulltext, and hybrid search times
- **Jobs per Minute** - Throughput by job type
- **Cache Operations** - Hit/miss rate over time

## Troubleshooting

### Prometheus won't start

Check the error log:

```bash
cat /opt/homebrew/var/log/prometheus.err.log
```

Common issue: YAML syntax error in config. Verify the config:

```bash
cat /opt/homebrew/etc/prometheus.yml
```

The config should look like:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: 'htm-demo'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9394']
```

### Grafana can't connect to Prometheus

1. Verify Prometheus is running:
   ```bash
   curl http://localhost:9090/api/v1/status/config
   ```

2. If connection refused, restart Prometheus:
   ```bash
   brew services restart prometheus
   ```

### No metrics in Grafana

1. Verify the demo is running and exposing metrics:
   ```bash
   curl http://localhost:9394/metrics
   ```

2. Check Prometheus is scraping the target:
   - Open http://localhost:9090/targets
   - Look for `htm-demo` target with state "UP"

### Port conflicts

If port 9394 is in use, edit `demo.rb` and change `METRICS_PORT`.

## Stopping Services

The demo leaves services running for convenience. To stop them:

```bash
brew services stop prometheus grafana
```

## Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Demo Metrics | http://localhost:9394/metrics | Raw Prometheus metrics |
| Prometheus | http://localhost:9090 | Metrics storage & queries |
| Grafana | http://localhost:3000 | Visualization dashboard |
