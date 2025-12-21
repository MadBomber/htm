# Sinatra Integration Example

A Sinatra web application demonstrating HTM integration with Sidekiq for background job processing.

**Source:** [`examples/sinatra_app/`](https://github.com/madbomber/htm/tree/main/examples/sinatra_app)

## Overview

The Sinatra example demonstrates:

- HTM integration with Sinatra using `register_htm` helper
- Session-based robot identification
- RESTful API endpoints for memory operations
- Sidekiq for background embedding and tag generation
- Thread-safe concurrent request handling

## Prerequisites

```bash
# PostgreSQL with pgvector
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"

# Redis for Sidekiq (optional)
export REDIS_URL="redis://localhost:6379/0"

# Ollama for embeddings and tags
ollama pull nomic-embed-text
ollama pull gemma3:latest
```

## Setup

```bash
cd examples/sinatra_app

# Install dependencies
bundle install
```

## Running

```bash
# Start the Sinatra app
bundle exec ruby app.rb

# In a separate terminal, start Sidekiq (optional, for async processing)
bundle exec sidekiq
```

Then open http://localhost:4567 in your browser.

## Code Walkthrough

### HTM Registration

```ruby
require 'sinatra'
require_relative '../../lib/htm'
require_relative '../../lib/htm/integrations/sinatra'

class HTMApp < Sinatra::Base
  # Register HTM with automatic configuration
  register_htm

  # Enable sessions for robot identification
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(64))
end
```

### Request Initialization

```ruby
before do
  # Use session ID as robot identifier
  robot_name = session[:robot_id] ||= SecureRandom.uuid[0..7]
  init_htm(robot_name: "web_user_#{robot_name}")

  # Set content type for API responses
  content_type :json if request.path.start_with?('/api/')
end
```

### API Endpoints

```ruby
# Remember information
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

# Recall memories
get '/api/recall' do
  topic = params[:topic]
  limit = (params[:limit] || 10).to_i
  strategy = (params[:strategy] || 'hybrid').to_sym

  unless topic && !topic.empty?
    halt 400, json(error: 'Topic is required')
  end

  memories = recall(topic, strategy: strategy, limit: limit)

  json(memories: memories)
end
```

## API Reference

### POST /api/remember

Store information in memory.

**Parameters:**
- `content` (required) - The text content to remember

**Response:**
```json
{
  "status": "ok",
  "node_id": 42,
  "message": "Memory stored. Embedding and tags are being generated in background."
}
```

### GET /api/recall

Recall memories matching a topic.

**Parameters:**
- `topic` (required) - Search topic
- `limit` (optional) - Max results (default: 10)
- `strategy` (optional) - Search strategy: `vector`, `fulltext`, or `hybrid` (default: hybrid)
- `timeframe` (optional) - Time range in seconds

**Response:**
```json
{
  "memories": [
    "PostgreSQL supports vector search via pgvector...",
    "The HTM gem provides intelligent memory management..."
  ]
}
```

### GET /api/stats

Get memory statistics.

**Response:**
```json
{
  "total_nodes": 150,
  "total_robots": 5,
  "total_tags": 42,
  "working_memory_nodes": 12
}
```

## Sidekiq Configuration

```ruby
require 'sidekiq'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

HTM automatically uses Sidekiq for background jobs when available:

- `GenerateEmbeddingJob` - Generates vector embeddings
- `GenerateTagsJob` - Extracts hierarchical tags via LLM

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HTM_DATABASE__URL` | (required) | PostgreSQL connection URL |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis URL for Sidekiq |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |
| `SESSION_SECRET` | (random) | Session encryption secret |

## Testing with curl

```bash
# Remember something
curl -X POST http://localhost:4567/api/remember \
  -d "content=PostgreSQL supports vector similarity search"

# Recall memories
curl "http://localhost:4567/api/recall?topic=database&strategy=hybrid&limit=5"

# Get stats
curl http://localhost:4567/api/stats
```

## See Also

- [Getting Started Guide](../guides/getting-started.md)
- [MCP Server Guide](../guides/mcp-server.md)
- [Configuration Guide](../guides/configuration.md)
