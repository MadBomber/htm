#!/usr/bin/env ruby
# frozen_string_literal: true

# HTM Telemetry Demo with Grafana Visualization
#
# This demo shows HTM metrics in a live Grafana dashboard using
# locally installed Prometheus and Grafana (via Homebrew).
#
# Prerequisites:
#   1. Set up examples database: rake examples:setup
#   2. brew install grafana prometheus
#   3. gem install prometheus-client webrick
#
# Usage:
#   cd examples/telemetry
#   ruby demo.rb
#
# The demo will:
#   1. Check/start Prometheus and Grafana
#   2. Clean up any previous demo data
#   3. Run HTM operations and export metrics
#   4. Open Grafana in your browser

require 'fileutils'

ROBOT_NAME = "Telemetry Demo Robot"
METRICS_PORT = 9394

class TelemetryDemo
  def initialize
    @metrics_server = nil
    @metrics_server_thread = nil
  end

  def run
    puts banner
    check_ruby_dependencies
    load_htm
    check_brew_services
    start_services
    configure_prometheus_scrape
    setup_metrics_server
    cleanup_previous_data
    import_grafana_dashboard
    open_grafana
    run_demo_loop
  ensure
    stop_metrics_server
  end

  private

  def banner
    <<~BANNER

      ╔══════════════════════════════════════════════════════════════════╗
      ║         HTM Telemetry Demo - Live Grafana Visualization          ║
      ╚══════════════════════════════════════════════════════════════════╝

    BANNER
  end

  # =========================================================================
  # Dependency Checks
  # =========================================================================

  def check_ruby_dependencies
    puts "Checking Ruby dependencies..."

    missing = []

    # Check for prometheus-client (installed as system gem)
    begin
      gem 'prometheus-client'
      require 'prometheus/client'
      require 'prometheus/client/formats/text'
      puts "  [OK] prometheus-client gem"
    rescue LoadError, Gem::MissingSpecError
      missing << 'prometheus-client'
    end

    # Check for webrick (installed as system gem)
    begin
      gem 'webrick'
      require 'webrick'
      puts "  [OK] webrick gem"
    rescue LoadError, Gem::MissingSpecError
      missing << 'webrick'
    end

    unless missing.empty?
      puts
      puts "  Missing gems. Install with:"
      puts "    gem install #{missing.join(' ')}"
      puts
      exit 1
    end

    puts
  end

  def load_htm
    puts "Loading HTM..."

    # Use examples_helper which sets up examples environment and database
    require_relative '../examples_helper'

    puts "  [OK] HTM #{HTM::VERSION}"
    puts "  [OK] Environment: #{HTM.config.environment}"
    puts "  [OK] Database: #{HTM.config.actual_database_name}"

    ExamplesHelper.require_database!
    puts
  end

  def check_brew_services
    puts "Checking Homebrew services..."

    %w[prometheus grafana].each do |service|
      print "  #{service}: "

      # Check if installed
      result = `brew list #{service} 2>/dev/null`
      if $?.success?
        puts "installed"
      else
        puts "NOT INSTALLED"
        puts
        puts "  Install with:"
        puts "    brew install #{service}"
        puts
        exit 1
      end
    end

    puts
  end

  def start_services
    puts "Starting services..."

    %w[prometheus grafana].each do |service|
      print "  #{service}: "

      if service_running?(service)
        puts "already running"
      else
        # Start the service
        `brew services start #{service} 2>/dev/null`
        sleep 2

        # Verify it started
        if service_running?(service)
          puts "started"
        else
          puts "FAILED TO START"
          puts "    Try: brew services start #{service}"
          exit 1
        end
      end
    end

    # Give services a moment to fully initialize
    sleep 2
    puts
  end

  def service_running?(service)
    status = `brew services info #{service} --json 2>/dev/null`
    # Handle both "running": true and "running":true formats
    status.include?('"running": true') || status.include?('"running":true')
  end

  # =========================================================================
  # Prometheus Configuration
  # =========================================================================

  def configure_prometheus_scrape
    puts "Configuring Prometheus to scrape demo metrics..."

    require 'yaml'

    # The actual prometheus.yml location
    prometheus_yml = "/opt/homebrew/etc/prometheus.yml"
    prometheus_yml = "/usr/local/etc/prometheus.yml" unless File.exist?(prometheus_yml)

    unless File.exist?(prometheus_yml)
      puts "  [WARN] Could not find prometheus.yml"
      puts "         Metrics may not be scraped automatically."
      puts "         Add this to your prometheus.yml:"
      puts
      puts "         scrape_configs:"
      puts "           - job_name: 'htm-demo'"
      puts "             static_configs:"
      puts "               - targets: ['localhost:#{METRICS_PORT}']"
      puts
      return
    end

    # Parse YAML properly
    config = YAML.load_file(prometheus_yml)
    config['scrape_configs'] ||= []

    # Check if our job already exists
    job_exists = config['scrape_configs'].any? do |job|
      job['job_name'] == 'htm-demo'
    end

    if job_exists
      puts "  [OK] htm-demo job already configured"
    else
      # Add our scrape config
      htm_job = {
        'job_name' => 'htm-demo',
        'scrape_interval' => '5s',
        'static_configs' => [
          { 'targets' => ["localhost:#{METRICS_PORT}"] }
        ]
      }
      config['scrape_configs'] << htm_job

      # Write back with proper YAML formatting
      File.write(prometheus_yml, YAML.dump(config))
      puts "  [OK] Added htm-demo scrape job"

      # Restart Prometheus to pick up new config
      print "  Restarting Prometheus... "
      `brew services restart prometheus 2>/dev/null`
      sleep 3
      puts "done"
    end

    puts
  end

  # =========================================================================
  # Metrics Server (exposes /metrics for Prometheus to scrape)
  # =========================================================================

  def setup_metrics_server
    puts "Starting metrics server on port #{METRICS_PORT}..."

    # Create Prometheus registry and metrics
    @registry = Prometheus::Client.registry

    @jobs_counter = @registry.counter(
      :htm_jobs_total,
      docstring: 'HTM job execution counts',
      labels: [:job, :status]
    )

    @embedding_histogram = @registry.histogram(
      :htm_embedding_latency_milliseconds,
      docstring: 'Embedding generation latency',
      labels: [:provider, :status],
      buckets: [10, 25, 50, 100, 250, 500, 1000, 2500, 5000]
    )

    @tag_histogram = @registry.histogram(
      :htm_tag_latency_milliseconds,
      docstring: 'Tag extraction latency',
      labels: [:provider, :status],
      buckets: [100, 250, 500, 1000, 2500, 5000, 10000]
    )

    @search_histogram = @registry.histogram(
      :htm_search_latency_milliseconds,
      docstring: 'Search operation latency',
      labels: [:strategy],
      buckets: [5, 10, 25, 50, 100, 250, 500, 1000]
    )

    @cache_counter = @registry.counter(
      :htm_cache_operations_total,
      docstring: 'Cache hit/miss counts',
      labels: [:operation]
    )

    # Start WEBrick server in background thread
    @metrics_server = WEBrick::HTTPServer.new(
      Port: METRICS_PORT,
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )

    @metrics_server.mount_proc '/metrics' do |req, res|
      res['Content-Type'] = 'text/plain; version=0.0.4'
      res.body = Prometheus::Client::Formats::Text.marshal(@registry)
    end

    @metrics_server_thread = Thread.new { @metrics_server.start }

    puts "  [OK] Metrics available at http://localhost:#{METRICS_PORT}/metrics"
    puts
  end

  def stop_metrics_server
    if @metrics_server
      @metrics_server.shutdown
      @metrics_server_thread&.join(2)
    end
  end

  # =========================================================================
  # Data Cleanup
  # =========================================================================

  def cleanup_previous_data
    puts "Cleaning up previous demo data..."

    begin
      # Find the robot
      robot = HTM::Models::Robot.find_by(name: ROBOT_NAME)

      if robot
        # Find all nodes associated with this robot
        node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).pluck(:node_id)

        if node_ids.any?
          # Hard delete the nodes
          deleted_count = HTM::Models::Node.where(id: node_ids).delete_all

          # Clean up robot_nodes join table
          HTM::Models::RobotNode.where(robot_id: robot.id).delete_all

          # Clean up any orphaned node_tags
          HTM::Models::NodeTag.where(node_id: node_ids).delete_all

          puts "  [OK] Deleted #{deleted_count} previous demo nodes"
        else
          puts "  [OK] No previous demo data found"
        end
      else
        puts "  [OK] No previous demo robot found"
      end
    rescue => e
      puts "  [WARN] Cleanup failed: #{e.message}"
    end

    puts
  end

  # =========================================================================
  # Grafana Dashboard
  # =========================================================================

  def import_grafana_dashboard
    puts "Grafana dashboard setup..."
    puts "  Dashboard JSON: examples/telemetry/grafana/dashboards/htm-metrics.json"
    puts "  To import: Grafana > Dashboards > Import > Upload JSON"
    puts
  end

  def open_grafana
    puts "Opening Grafana..."
    system("open http://localhost:3000/d/htm-metrics/htm-metrics 2>/dev/null || " \
           "xdg-open http://localhost:3000 2>/dev/null || " \
           "echo '  Open http://localhost:3000 in your browser'")
    puts "  Default login: admin / admin"
    puts
  end

  # =========================================================================
  # Demo Loop
  # =========================================================================

  def run_demo_loop
    puts "=" * 60
    puts "Starting demo loop..."
    puts "  Metrics: http://localhost:#{METRICS_PORT}/metrics"
    puts "  Grafana: http://localhost:3000"
    puts "=" * 60
    puts
    puts "Press Ctrl+C to stop"
    puts

    # Quiet loggers
    HTM.configure do |config|
      config.logger = Logger.new(File::NULL)
    end
    RubyLLM.logger = Logger.new(File::NULL) if defined?(RubyLLM)

    htm = HTM.new(robot_name: ROBOT_NAME)
    iteration = 0

    loop do
      iteration += 1
      puts "[#{Time.now.strftime('%H:%M:%S')}] Iteration #{iteration}"

      # Remember something (track embedding + tag metrics)
      content = sample_content(iteration)
      print "  > Remember: #{content[0..45]}... "

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      node_id = htm.remember(content)
      puts "node #{node_id}"

      # Wait for background jobs and record metrics
      sleep 3

      # Simulate job completion metrics (in real app, jobs would record these)
      record_job_metrics

      # Search with different strategies
      %w[fulltext vector hybrid].each do |strategy|
        query = sample_query(iteration)
        print "  > Recall (#{strategy.ljust(8)}): '#{query.ljust(12)}' "

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        results = htm.recall(query, strategy: strategy.to_sym, limit: 3)
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

        @search_histogram.observe(elapsed_ms, labels: { strategy: strategy })

        # Simulate cache behavior
        if rand < 0.3
          @cache_counter.increment(labels: { operation: 'hit' })
        else
          @cache_counter.increment(labels: { operation: 'miss' })
        end

        puts "-> #{results.length} results (#{elapsed_ms}ms)"
      end

      puts "  Metrics exported to Prometheus"
      puts

      sleep 5
    end
  rescue Interrupt
    puts
    puts "Shutting down..."
    ask_to_stop_services
  end

  def ask_to_stop_services
    print "\nStop Prometheus and Grafana services? (y/N): "
    response = $stdin.gets&.strip&.downcase

    if response == 'y' || response == 'yes'
      print "  Stopping prometheus... "
      `brew services stop prometheus 2>/dev/null`
      puts "done"

      print "  Stopping grafana... "
      `brew services stop grafana 2>/dev/null`
      puts "done"

      puts "  Services stopped."
    else
      puts "  Services left running."
      puts "  To stop later: brew services stop prometheus grafana"
    end
  end

  def record_job_metrics
    # Record successful embedding job
    @jobs_counter.increment(labels: { job: 'embedding', status: 'success' })
    @embedding_histogram.observe(
      rand(50..200),
      labels: { provider: 'ollama', status: 'success' }
    )

    # Record successful tag job
    @jobs_counter.increment(labels: { job: 'tags', status: 'success' })
    @tag_histogram.observe(
      rand(500..2000),
      labels: { provider: 'ollama', status: 'success' }
    )

    # Occasionally record failures for demo variety
    if rand < 0.1
      @jobs_counter.increment(labels: { job: 'embedding', status: 'error' })
    end
  end

  def sample_content(iteration)
    contents = [
      "PostgreSQL supports vector similarity search through the pgvector extension.",
      "OpenTelemetry provides unified observability for distributed systems.",
      "Ruby on Rails is a popular web application framework.",
      "Machine learning models can be used for semantic search.",
      "The HTM gem provides intelligent memory management for LLM applications.",
      "Grafana is an open-source analytics and monitoring platform.",
      "Prometheus is a systems monitoring and alerting toolkit.",
      "Background job processing improves application responsiveness.",
      "Hierarchical tags help organize information semantically.",
      "Vector embeddings capture semantic meaning of text."
    ]
    contents[(iteration - 1) % contents.length]
  end

  def sample_query(iteration)
    queries = %w[database observability ruby search memory monitoring metrics jobs tags vectors]
    queries[(iteration - 1) % queries.length]
  end
end

# Run the demo
if __FILE__ == $PROGRAM_NAME
  TelemetryDemo.new.run
end
