#!/usr/bin/env ruby
# frozen_string_literal: true

# HTM Sinatra Application Example
#
# Demonstrates using HTM in a Sinatra web application with:
# - Sidekiq for background job processing
# - Session-based robot identification
# - RESTful API endpoints
# - Thread-safe concurrent request handling
#
# Usage:
#   bundle install
#   bundle exec ruby app.rb
#
# Environment:
#   HTM_DATABASE__URL - PostgreSQL connection URL (required)
#   REDIS_URL - Redis connection URL (for Sidekiq, default: redis://localhost:6379/0)
#   OLLAMA_URL - Ollama server URL (default: http://localhost:11434)
#

require 'sinatra'
require 'sinatra/json'
require 'sidekiq'
require 'securerandom'
require_relative '../../lib/htm'
require_relative '../../lib/htm/integrations/sinatra'

# Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Sinatra Application
class HTMApp < Sinatra::Base
  # Register HTM with automatic configuration
  register_htm

  # Enable sessions for robot identification
  enable :sessions
  # Session secret must be at least 64 bytes for Rack session encryption
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(64))

  # Enable inline templates (defined after __END__)
  enable :inline_templates

  # Initialize HTM for each request
  before do
    # Use session ID as robot identifier
    robot_name = session[:robot_id] ||= SecureRandom.uuid[0..7]
    init_htm(robot_name: "web_user_#{robot_name}")

    # Set content type for API responses
    content_type :json if request.path.start_with?('/api/')
  end

  # Home page
  get '/' do
    erb :index
  end

  # API: Remember information
  post '/api/remember' do
    content = params[:content]

    unless content && !content.empty?
      halt 400, json(error: 'Content is required')
    end

    node_id = remember(content)

    json(
      status: 'ok',
      node_id: node_id,
      message: 'Memory stored. Embedding and tags are being generated in background.'
    )
  end

  # API: Recall memories
  get '/api/recall' do
    topic = params[:topic]
    limit = (params[:limit] || 10).to_i
    strategy = (params[:strategy] || 'hybrid').to_sym
    timeframe_param = params[:timeframe]

    unless topic && !topic.empty?
      halt 400, json(error: 'Topic is required')
    end

    unless [:vector, :fulltext, :hybrid].include?(strategy)
      halt 400, json(error: 'Invalid strategy. Use: vector, fulltext, or hybrid')
    end

    # Parse timeframe parameter (in seconds)
    # Valid values: "5", "10", "15", "20", "25", "30", "30+", "all", or nil
    timeframe = parse_timeframe_param(timeframe_param)

    memories = recall(topic, limit: limit, strategy: strategy, timeframe: timeframe, raw: true)

    json(
      status: 'ok',
      count: memories.length,
      timeframe: timeframe_param || 'all',
      memories: memories.map { |m| format_memory(m) }
    )
  end

  # API: Get memory statistics
  get '/api/stats' do
    total_nodes = HTM::Models::Node.count
    nodes_with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
    nodes_with_tags = HTM::Models::Node.joins(:tags).distinct.count
    total_tags = HTM::Models::Tag.count

    robot_nodes = HTM::Models::RobotNode.where(robot_id: htm.robot_id).count

    json(
      status: 'ok',
      stats: {
        total_nodes: total_nodes,
        nodes_with_embeddings: nodes_with_embeddings,
        nodes_with_tags: nodes_with_tags,
        total_tags: total_tags,
        current_robot: {
          id: htm.robot_id,
          name: htm.robot_name,
          nodes: robot_nodes
        }
      }
    )
  end

  # API: Health check
  get '/api/health' do
    json(
      status: 'ok',
      job_backend: HTM.configuration.job_backend,
      database: HTM::ActiveRecordConfig.connected?,
      timestamp: Time.now.iso8601
    )
  end

  # API: Get all tags as a tree structure
  get '/api/tags' do
    tags = HTM::Models::Tag.all

    json(
      status: 'ok',
      count: tags.count,
      tree: tags.tree
    )
  end

  private

  # Parse timeframe parameter from query string
  # Returns a string like "last N seconds" or nil for "all"
  def parse_timeframe_param(param)
    return nil if param.nil? || param.empty? || param == 'all'

    case param
    when '5', '10', '15', '20', '25', '30'
      "last #{param} seconds"
    when '30+'
      # 30+ means older than 30 seconds (from beginning of time to 30 seconds ago)
      thirty_seconds_ago = Time.now - 30
      Time.at(0)..thirty_seconds_ago
    else
      nil  # Default to all time
    end
  end

  def format_memory(memory)
    result = {
      id: memory['id'],
      content: memory['content'],
      created_at: memory['created_at'],
      token_count: memory['token_count']
    }

    # Include hybrid search scoring if available
    if memory['similarity']
      result[:similarity] = memory['similarity'].to_f.round(4)
      result[:tag_boost] = memory['tag_boost'].to_f.round(4)
      result[:combined_score] = memory['combined_score'].to_f.round(4)
    end

    result
  end

  # Run the app
  run! if app_file == $0
end

__END__

@@index
<!DOCTYPE html>
<html>
<head>
  <title>HTM Sinatra Example</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 20px;
      line-height: 1.6;
    }
    h1 { color: #333; }
    .section {
      background: #f5f5f5;
      padding: 20px;
      margin: 20px 0;
      border-radius: 8px;
    }
    input[type="text"], textarea {
      width: 100%;
      padding: 10px;
      margin: 10px 0;
      border: 1px solid #ddd;
      border-radius: 4px;
      box-sizing: border-box;
    }
    button {
      background: #007bff;
      color: white;
      padding: 10px 20px;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    button:hover { background: #0056b3; }
    .result {
      background: white;
      padding: 15px;
      margin: 10px 0;
      border-radius: 4px;
      border-left: 4px solid #007bff;
    }
    .error {
      border-left-color: #dc3545;
      background: #fff5f5;
    }
    .scores {
      color: #6c757d;
      font-style: italic;
    }
    .tag-tree {
      font-family: monospace;
      margin: 10px 0;
      line-height: 1.4;
    }
    .filter-row {
      display: flex;
      gap: 10px;
      margin: 10px 0;
    }
    .filter-row select {
      flex: 1;
      padding: 10px;
      border: 1px solid #ddd;
      border-radius: 4px;
    }
    .timeframe-badge {
      display: inline-block;
      background: #6c757d;
      color: white;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 0.85em;
      margin-left: 8px;
    }
  </style>
</head>
<body>
  <h1>HTM Sinatra Example</h1>
  <p>Hierarchical Temporal Memory with tag-enhanced hybrid search and Sidekiq background jobs</p>

  <div class="section">
    <h2>Remember Information</h2>
    <textarea id="rememberContent" rows="4" placeholder="Enter information to remember..."></textarea>
    <button onclick="remember()">Remember</button>
    <div id="rememberResult"></div>
  </div>

  <div class="section">
    <h2>Recall Memories</h2>
    <p><small>Hybrid search uses combined scoring: (similarity × 0.7) + (tag_boost × 0.3)</small></p>
    <input type="text" id="recallTopic" placeholder="Enter topic to search...">
    <div class="filter-row">
      <select id="recallStrategy">
        <option value="hybrid">Hybrid (Vector + Fulltext + Tags)</option>
        <option value="vector">Vector Only</option>
        <option value="fulltext">Fulltext Only</option>
      </select>
      <select id="recallTimeframe">
        <option value="all">All Time</option>
        <option value="5">Last 5 seconds</option>
        <option value="10">Last 10 seconds</option>
        <option value="15">Last 15 seconds</option>
        <option value="20">Last 20 seconds</option>
        <option value="25">Last 25 seconds</option>
        <option value="30">Last 30 seconds</option>
        <option value="30+">Older than 30 seconds</option>
      </select>
    </div>
    <button onclick="recall()">Recall</button>
    <div id="recallResult"></div>
  </div>

  <div class="section">
    <h2>Memory Statistics</h2>
    <button onclick="getStats()">Refresh Stats</button>
    <div id="statsResult"></div>
  </div>

  <div class="section">
    <h2>Tag Tree</h2>
    <button onclick="getTags()">Refresh</button>
    <div id="tagsResult"></div>
  </div>

  <script>
    async function remember() {
      const content = document.getElementById('rememberContent').value;
      const resultDiv = document.getElementById('rememberResult');

      if (!content) {
        resultDiv.innerHTML = '<div class="result error">Please enter some content</div>';
        return;
      }

      try {
        const response = await fetch('/api/remember', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `content=${encodeURIComponent(content)}`
        });

        const data = await response.json();

        if (response.ok) {
          resultDiv.innerHTML = `<div class="result">
            ✓ ${data.message}<br>
            Node ID: ${data.node_id}
          </div>`;
          document.getElementById('rememberContent').value = '';
        } else {
          resultDiv.innerHTML = `<div class="result error">✗ ${data.error}</div>`;
        }
      } catch (error) {
        resultDiv.innerHTML = `<div class="result error">✗ ${error.message}</div>`;
      }
    }

    async function recall() {
      const topic = document.getElementById('recallTopic').value;
      const strategy = document.getElementById('recallStrategy').value;
      const timeframe = document.getElementById('recallTimeframe').value;
      const resultDiv = document.getElementById('recallResult');

      if (!topic) {
        resultDiv.innerHTML = '<div class="result error">Please enter a topic</div>';
        return;
      }

      try {
        const response = await fetch(`/api/recall?topic=${encodeURIComponent(topic)}&strategy=${strategy}&timeframe=${timeframe}&limit=10`);
        const data = await response.json();

        if (response.ok) {
          if (data.count === 0) {
            resultDiv.innerHTML = '<div class="result">No memories found</div>';
          } else {
            // Format timeframe for display
            const timeframeDisplay = formatTimeframe(data.timeframe);
            const memoriesHtml = data.memories.map(m => {
              // Build scoring info if available (hybrid search)
              let scoreInfo = '';
              if (m.combined_score !== undefined) {
                scoreInfo = `<br><small class="scores">Score: ${m.combined_score.toFixed(3)} (similarity: ${m.similarity.toFixed(3)}, tag boost: ${m.tag_boost.toFixed(3)})</small>`;
              }
              // Calculate age of memory
              const age = formatAge(m.created_at);
              return `
                <div class="result">
                  <strong>Node ${m.id}</strong> <span class="timeframe-badge">${age}</span><br>
                  ${m.content}<br>
                  <small>${new Date(m.created_at).toLocaleString()} • ${m.token_count} tokens</small>
                  ${scoreInfo}
                </div>
              `;
            }).join('');
            resultDiv.innerHTML = `<p>Found ${data.count} memories (${timeframeDisplay}):</p>${memoriesHtml}`;
          }
        } else {
          resultDiv.innerHTML = `<div class="result error">✗ ${data.error}</div>`;
        }
      } catch (error) {
        resultDiv.innerHTML = `<div class="result error">✗ ${error.message}</div>`;
      }
    }

    function formatTimeframe(tf) {
      switch(tf) {
        case 'all': return 'all time';
        case '5': return 'last 5 seconds';
        case '10': return 'last 10 seconds';
        case '15': return 'last 15 seconds';
        case '20': return 'last 20 seconds';
        case '25': return 'last 25 seconds';
        case '30': return 'last 30 seconds';
        case '30+': return 'older than 30 seconds';
        default: return tf;
      }
    }

    function formatAge(createdAt) {
      const now = new Date();
      const created = new Date(createdAt);
      const diffSeconds = Math.floor((now - created) / 1000);

      if (diffSeconds < 60) {
        return `${diffSeconds}s ago`;
      } else if (diffSeconds < 3600) {
        return `${Math.floor(diffSeconds / 60)}m ago`;
      } else if (diffSeconds < 86400) {
        return `${Math.floor(diffSeconds / 3600)}h ago`;
      } else {
        return `${Math.floor(diffSeconds / 86400)}d ago`;
      }
    }

    async function getStats() {
      const resultDiv = document.getElementById('statsResult');

      try {
        const response = await fetch('/api/stats');
        const data = await response.json();

        if (response.ok) {
          const stats = data.stats;
          resultDiv.innerHTML = `
            <div class="result">
              <strong>Global Statistics:</strong><br>
              Total Nodes: ${stats.total_nodes}<br>
              With Embeddings: ${stats.nodes_with_embeddings}<br>
              With Tags: ${stats.nodes_with_tags}<br>
              Total Tags: ${stats.total_tags}<br><br>
              <strong>Your Session (${stats.current_robot.name}):</strong><br>
              Nodes: ${stats.current_robot.nodes}
            </div>
          `;
        } else {
          resultDiv.innerHTML = `<div class="result error">✗ ${data.error}</div>`;
        }
      } catch (error) {
        resultDiv.innerHTML = `<div class="result error">✗ ${error.message}</div>`;
      }
    }

    async function getTags() {
      const resultDiv = document.getElementById('tagsResult');

      try {
        const response = await fetch('/api/tags');
        const data = await response.json();

        if (response.ok) {
          if (data.count === 0) {
            resultDiv.innerHTML = '<div class="result">No tags found</div>';
          } else {
            const treeHtml = renderTagTree(data.tree);
            resultDiv.innerHTML = `
              <div class="result">
                <pre class="tag-tree">${treeHtml}</pre>
                <small>${data.count} tags</small>
              </div>
            `;
          }
        } else {
          resultDiv.innerHTML = `<div class="result error">✗ ${data.error}</div>`;
        }
      } catch (error) {
        resultDiv.innerHTML = `<div class="result error">✗ ${error.message}</div>`;
      }
    }

    function renderTagTree(tree, prefix = '', isLastArray = []) {
      const keys = Object.keys(tree).sort();
      let result = '';

      keys.forEach((key, index) => {
        const isLast = index === keys.length - 1;

        // Build prefix from parent branches
        let linePrefix = '';
        isLastArray.forEach(wasLast => {
          linePrefix += wasLast ? '    ' : '│   ';
        });

        // Add branch character
        const branch = isLast ? '└── ' : '├── ';
        result += linePrefix + branch + key + '\n';

        // Recurse into children
        const children = tree[key];
        if (Object.keys(children).length > 0) {
          result += renderTagTree(children, prefix, [...isLastArray, isLast]);
        }
      });

      return result;
    }

    // Load stats and tags on page load
    window.onload = function() {
      getStats();
      getTags();
    };
  </script>
</body>
</html>
