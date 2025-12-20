# HTM Multi-Framework Support

HTM works seamlessly in three types of applications:
1. **CLI Applications** - Command-line tools with synchronous execution
2. **Sinatra Applications** - Web apps with Sidekiq background jobs
3. **Rails Applications** - Full Rails integration with ActiveJob

## Quick Start by Framework

### CLI Applications

```ruby
#!/usr/bin/env ruby
require 'htm'

# Configure for CLI (synchronous execution)
HTM.configure do |config|
  config.job.backend = :inline  # Jobs run immediately
end

htm = HTM.new(robot_name: "cli_assistant")

# Store information (waits for embedding + tags)
node_id = htm.remember("PostgreSQL is great for time-series data")
puts "Stored as node #{node_id}"

# Search memories
memories = htm.recall("PostgreSQL", limit: 10)
puts "Found #{memories.length} memories"
```

**Example:** [`examples/cli_app/htm_cli.rb`](https://github.com/madbomber/htm/blob/main/examples/cli_app/htm_cli.rb)

---

### Sinatra Applications

```ruby
require 'sinatra'
require 'htm'
require 'htm/integrations/sinatra'

class MyApp < Sinatra::Base
  # Automatically configures HTM with Sidekiq
  register_htm

  enable :sessions

  before do
    init_htm(robot_name: session[:user_id] || 'guest')
  end

  post '/remember' do
    node_id = remember(params[:content])
    json status: 'ok', node_id: node_id
  end

  get '/recall' do
    memories = recall(params[:topic], limit: 10)
    json memories: memories
  end
end
```

**Example:** [`examples/sinatra_app/app.rb`](https://github.com/madbomber/htm/blob/main/examples/sinatra_app/app.rb)

---

### Rails Applications

```ruby
# HTM automatically configures itself in Rails

# app/controllers/memories_controller.rb
class MemoriesController < ApplicationController
  def create
    htm = HTM.new(robot_name: "user_#{current_user.id}")
    node_id = htm.remember(params[:content], source: 'user')

    render json: { status: 'ok', node_id: node_id }
  end

  def index
    htm = HTM.new(robot_name: "user_#{current_user.id}")
    memories = htm.recall(params[:topic], limit: 10)

    render json: { memories: memories }
  end
end
```

Rails auto-configuration happens via `HTM::Railtie`:
- Uses Rails.logger
- Uses ActiveJob for background jobs
- Inline jobs in test environment
- Rake tasks auto-loaded

---

## Job Backend Comparison

| Backend | Best For | Speed | Infrastructure | Use Case |
|---------|----------|-------|----------------|----------|
| `:inline` | CLI, Tests | Slow (synchronous) | None | Development, testing, CLI tools |
| `:thread` | Simple apps | Fast | None | Quick prototypes, standalone |
| `:sidekiq` | Sinatra | Fast | Redis required | Microservices, Sinatra apps |
| `:active_job` | Rails | Fast | Rails required | Rails applications |

### Performance Characteristics

**:inline (Synchronous)**
```ruby
# User waits for completion
node_id = htm.remember("text")  # ~1-3 seconds
# Embedding and tags already generated
```

**:sidekiq/:active_job (Asynchronous)**
```ruby
# User gets immediate response
node_id = htm.remember("text")  # ~15ms
# Embedding and tags generated in background (~1 second)
```

---

## Configuration

### Auto-Detection

HTM automatically detects the appropriate backend:

```ruby
# Test environment → :inline (uses HTM.env which checks HTM_ENV > RAILS_ENV > RACK_ENV)
ENV['HTM_ENV'] = 'test'
HTM.configuration.job_backend  # => :inline

# Rails app → :active_job
defined?(ActiveJob)
HTM.configuration.job_backend  # => :active_job

# Sidekiq available → :sidekiq
defined?(Sidekiq)
HTM.configuration.job_backend  # => :sidekiq

# Default → :thread
HTM.configuration.job_backend  # => :thread
```

### Manual Override

```ruby
HTM.configure do |config|
  config.job.backend = :inline  # Force synchronous
end
```

### Environment Variable

```bash
export HTM_JOB_BACKEND=inline  # Override auto-detection
```

---

## Framework-Specific Features

### CLI Applications

**Features:**
- Synchronous execution (`:inline` backend)
- Progress feedback in terminal
- No background infrastructure needed
- Simple error handling

**Best Practices:**
```ruby
# Use inline backend
HTM.configure do |config|
  config.job.backend = :inline

  # CLI-friendly logging
  config.logger.formatter = proc do |severity, datetime, progname, msg|
    case severity
    when 'INFO'  then "[✓] #{msg}\n"
    when 'ERROR' then "[✗] #{msg}\n"
    else "[•] #{msg}\n"
    end
  end
end
```

---

### Sinatra Applications

**Features:**
- Sidekiq background jobs
- Session-based robot identification
- Thread-safe request handling
- RESTful API integration

**Setup:**
```ruby
# Gemfile
gem 'sinatra'
gem 'sidekiq'
gem 'redis'
gem 'htm'

# app.rb
require 'htm/integrations/sinatra'

class MyApp < Sinatra::Base
  register_htm  # Auto-configures HTM

  enable :sessions

  before do
    robot_name = session[:user_id] || 'guest'
    init_htm(robot_name: "user_#{robot_name}")
  end
end
```

**Deployment:**
```bash
# Start Redis
redis-server

# Start Sidekiq worker
bundle exec sidekiq -r ./app.rb

# Start web server
bundle exec ruby app.rb
```

---

### Rails Applications

**Features:**
- Automatic configuration via Railtie
- ActiveJob integration
- Rails logger integration
- Rake tasks loaded automatically
- Test environment auto-configured

**Setup:**
```ruby
# Gemfile
gem 'htm'

# config/initializers/htm.rb (optional)
HTM.configure do |config|
  config.embedding.model = 'nomic-embed-text'
  config.tag.model = 'llama3'
end
```

**Usage in Controllers:**
```ruby
class MemoriesController < ApplicationController
  def create
    htm = HTM.new(robot_name: "user_#{current_user.id}")
    node_id = htm.remember(params[:content])

    # Job enqueued via ActiveJob
    # Returns immediately

    render json: { node_id: node_id }
  end
end
```

**Testing:**
```ruby
# test/test_helper.rb or spec/rails_helper.rb

# Jobs run synchronously in tests (auto-configured)
RSpec.describe MemoriesController do
  it "creates memory" do
    post :create, params: { content: "Test memory" }

    # Embedding and tags already generated (inline in tests)
    node = HTM::Models::Node.last
    expect(node.embedding).to be_present
    expect(node.tags).not_to be_empty
  end
end
```

---

## Thread Safety

HTM is thread-safe for concurrent web requests:

✅ **Thread-Safe Components:**
- `HTM::WorkingMemory` - Per-instance state
- `HTM::LongTermMemory` - Connection pooling
- Database operations - PostgreSQL ACID compliance
- Job enqueueing - Atomic operations

⚠️ **Considerations:**
- Each HTM instance is independent
- Connection pool sized appropriately (`db_pool_size`)
- Concurrent node creation is safe
- Shared memory across robots (by design)

**Example: Concurrent Requests**
```ruby
# Sinatra/Rails - Multiple requests simultaneously
# Request 1:
htm1 = HTM.new(robot_name: "user_123")
htm1.remember("Message 1")  # ✓ Thread-safe

# Request 2 (concurrent):
htm2 = HTM.new(robot_name: "user_456")
htm2.remember("Message 2")  # ✓ Thread-safe

# Separate instances, no conflicts
```

---

## Database Connection Management

### CLI Applications
```ruby
# Single connection, simple usage
htm = HTM.new
# Connection established once
```

### Sinatra Applications
```ruby
# Connection pooling handled by middleware
class MyApp < Sinatra::Base
  use HTM::Sinatra::Middleware  # Manages connections
end
```

### Rails Applications
```ruby
# Rails manages connections automatically
# HTM shares Rails' connection pool
```

### Connection Pool Settings
```ruby
htm = HTM.new(
  db_pool_size: 10,         # Max connections
  db_query_timeout: 30_000  # 30 seconds
)
```

---

## Troubleshooting

### Jobs Not Running (Sinatra)

**Problem:** Memories created but no embeddings/tags

**Solution:**
```bash
# Check Sidekiq is running
ps aux | grep sidekiq

# Start Sidekiq worker
bundle exec sidekiq -r ./app.rb -q htm

# Check Redis
redis-cli ping
```

### Jobs Not Running (Rails)

**Problem:** Background jobs not processing

**Solution:**
```bash
# Check ActiveJob backend configured
# config/application.rb
config.active_job.queue_adapter = :sidekiq

# Start Sidekiq
bundle exec sidekiq
```

### Slow CLI Performance

**Problem:** CLI operations take too long

**Solution:**
```ruby
# Use faster/smaller models
HTM.configure do |config|
  config.embedding.model = 'all-minilm'  # Smaller, faster
  config.tag.model = 'gemma2:2b'         # Smaller model
end

# Or disable features
HTM.configure do |config|
  config.tag_extractor = ->(_text, _ontology) { [] }  # Skip tags
end
```

### Thread Safety Issues

**Problem:** Concurrent request errors

**Solution:**
```ruby
# Increase connection pool
htm = HTM.new(db_pool_size: 20)

# Check for shared state (anti-pattern)
# DON'T:
$htm = HTM.new  # Global shared instance

# DO:
def htm
  @htm ||= HTM.new(robot_name: current_user.id)
end
```

---

## Migration Guide

### Existing CLI Apps

```ruby
# Before (blocking):
# Jobs run in threads (may not complete)

# After (explicit inline):
HTM.configure do |config|
  config.job.backend = :inline
end
# Jobs run synchronously, guaranteed to complete
```

### Existing Sinatra Apps

```ruby
# Before:
require 'htm'
# Threads used (not production-ready)

# After:
require 'htm/integrations/sinatra'
register_htm  # Auto-configures Sidekiq
# Production-ready background jobs
```

### Existing Rails Apps

```ruby
# Before:
# Manual configuration required

# After:
# Just add gem 'htm' - auto-configures via Railtie
# Uses ActiveJob automatically
```

---

## Best Practices

### CLI Applications
1. Use `:inline` backend for predictability
2. Add progress indicators for user feedback
3. Handle Ollama connection errors gracefully
4. Consider caching for repeated queries

### Sinatra Applications
1. Use `register_htm` for auto-configuration
2. Always use sessions for robot identification
3. Run Sidekiq workers in production
4. Monitor Redis memory usage

### Rails Applications
1. Create initializer for custom configuration
2. Use per-user robot names
3. Let Rails manage database connections
4. Use ActiveJob for all background processing

---

## Examples

See working examples in the repository:

- **CLI:** [`examples/cli_app/htm_cli.rb`](https://github.com/madbomber/htm/blob/main/examples/cli_app/htm_cli.rb)
- **Sinatra:** [`examples/sinatra_app/app.rb`](https://github.com/madbomber/htm/blob/main/examples/sinatra_app/app.rb)
- **Rails:** `examples/rails_app/` (full Rails 7 app)

---

## Summary

| Feature | CLI | Sinatra | Rails |
|---------|-----|---------|-------|
| Job Backend | inline | sidekiq | active_job |
| Setup Complexity | Low | Medium | Low (auto) |
| Infrastructure | Database only | +Redis | +Rails |
| Response Time | Slow (1-3s) | Fast (15ms) | Fast (15ms) |
| Production Ready | ✓ (small scale) | ✓ | ✓ |
| Background Jobs | No | Yes | Yes |
| Auto-Configuration | Manual | `register_htm` | Railtie |

**Recommendation:**
- CLI tools → Use `:inline` backend
- Sinatra apps → Use `:sidekiq` backend
- Rails apps → Use `:active_job` backend (default)
