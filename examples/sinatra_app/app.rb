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
#   HTM_DBURL - PostgreSQL connection URL (required)
#   REDIS_URL - Redis connection URL (for Sidekiq, default: redis://localhost:6379/0)
#   OLLAMA_URL - Ollama server URL (default: http://localhost:11434)
#

require 'sinatra'
require 'sinatra/json'
require 'sidekiq'
require_relative '../../lib/htm'
require_relative '../../lib/htm/sinatra'

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
  set :session_secret, ENV.fetch('SESSION_SECRET', 'change_me_in_production')

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

    node_id = remember(content, source: 'web_user')

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

    unless topic && !topic.empty?
      halt 400, json(error: 'Topic is required')
    end

    unless [:vector, :fulltext, :hybrid].include?(strategy)
      halt 400, json(error: 'Invalid strategy. Use: vector, fulltext, or hybrid')
    end

    memories = recall(topic, limit: limit, strategy: strategy, raw: true)

    json(
      status: 'ok',
      count: memories.length,
      memories: memories.map { |m| format_memory(m) }
    )
  end

  # API: Get memory statistics
  get '/api/stats' do
    total_nodes = HTM::Models::Node.count
    nodes_with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
    nodes_with_tags = HTM::Models::Node.joins(:tags).distinct.count
    total_tags = HTM::Models::Tag.count

    robot_nodes = HTM::Models::Node.where(robot_id: htm.robot_id).count

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

  private

  def format_memory(memory)
    {
      id: memory['id'],
      content: memory['content'],
      source: memory['source'],
      created_at: memory['created_at'],
      token_count: memory['token_count']
    }
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
  </style>
</head>
<body>
  <h1>HTM Sinatra Example</h1>
  <p>Hierarchical Temporary Memory with Sidekiq background jobs</p>

  <div class="section">
    <h2>Remember Information</h2>
    <textarea id="rememberContent" rows="4" placeholder="Enter information to remember..."></textarea>
    <button onclick="remember()">Remember</button>
    <div id="rememberResult"></div>
  </div>

  <div class="section">
    <h2>Recall Memories</h2>
    <input type="text" id="recallTopic" placeholder="Enter topic to search...">
    <select id="recallStrategy">
      <option value="hybrid">Hybrid (Vector + Fulltext)</option>
      <option value="vector">Vector Only</option>
      <option value="fulltext">Fulltext Only</option>
    </select>
    <button onclick="recall()">Recall</button>
    <div id="recallResult"></div>
  </div>

  <div class="section">
    <h2>Memory Statistics</h2>
    <button onclick="getStats()">Refresh Stats</button>
    <div id="statsResult"></div>
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
      const resultDiv = document.getElementById('recallResult');

      if (!topic) {
        resultDiv.innerHTML = '<div class="result error">Please enter a topic</div>';
        return;
      }

      try {
        const response = await fetch(`/api/recall?topic=${encodeURIComponent(topic)}&strategy=${strategy}&limit=10`);
        const data = await response.json();

        if (response.ok) {
          if (data.count === 0) {
            resultDiv.innerHTML = '<div class="result">No memories found</div>';
          } else {
            const memoriesHtml = data.memories.map(m => `
              <div class="result">
                <strong>Node ${m.id}</strong> (${m.source})<br>
                ${m.content}<br>
                <small>${new Date(m.created_at).toLocaleString()} • ${m.token_count} tokens</small>
              </div>
            `).join('');
            resultDiv.innerHTML = `<p>Found ${data.count} memories:</p>${memoriesHtml}`;
          }
        } else {
          resultDiv.innerHTML = `<div class="result error">✗ ${data.error}</div>`;
        }
      } catch (error) {
        resultDiv.innerHTML = `<div class="result error">✗ ${error.message}</div>`;
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

    // Load stats on page load
    window.onload = getStats;
  </script>
</body>
</html>
