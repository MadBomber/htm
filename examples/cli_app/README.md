# HTM CLI Application Example

This example demonstrates using HTM in a command-line application with synchronous job execution.

## Features

- **Synchronous Execution**: Uses `:inline` job backend for immediate embedding/tag generation
- **Interactive Interface**: Command-line REPL for remembering and recalling information
- **Progress Feedback**: Real-time feedback on operations
- **Database Persistence**: All memories stored in PostgreSQL
- **Full HTM Features**: Vector search, tag extraction, hybrid search

## Prerequisites

1. **PostgreSQL Database**
   ```bash
   # Set database connection URL
   export HTM_DBURL='postgresql://user:pass@host:port/dbname'

   # Or use your existing config
   source ~/.bashrc__tiger
   ```

2. **Ollama** (recommended but optional)
   ```bash
   # Install Ollama
   curl https://ollama.ai/install.sh | sh

   # Pull models
   ollama pull nomic-embed-text  # For embeddings
   ollama pull llama3            # For tag extraction
   ```

3. **Ruby Dependencies**
   ```bash
   # From HTM root directory
   bundle install
   ```

## Usage

### Run the CLI

```bash
# Make executable
chmod +x htm_cli.rb

# Run
./htm_cli.rb
# or
ruby htm_cli.rb
```

### Commands

**Store Information**
```
htm> remember PostgreSQL is great for time-series data
```

**Search Memories**
```
htm> recall PostgreSQL
```

**View Statistics**
```
htm> stats
```

**Show Help**
```
htm> help
```

**Exit**
```
htm> exit
```

## How It Works

### Synchronous Job Execution

Unlike web applications, CLI apps use `:inline` job backend:

```ruby
HTM.configure do |config|
  config.job_backend = :inline  # Execute jobs synchronously
end
```

This means:
- `remember()` waits for embeddings and tags to be generated
- Immediate feedback on completion
- Simpler debugging and testing
- No background job infrastructure needed

### Job Backend Comparison

| Backend | CLI | Web Apps | When to Use |
|---------|-----|----------|-------------|
| `:inline` | ✅ | ❌ | CLI tools, tests |
| `:thread` | ⚠️ | ⚠️ | Simple standalone apps |
| `:sidekiq` | ❌ | ✅ | Sinatra, microservices |
| `:active_job` | ❌ | ✅ | Rails applications |

## Example Session

```
$ ruby htm_cli.rb

============================================================
HTM CLI - Hierarchical Temporary Memory Assistant
============================================================

Job Backend: inline (synchronous execution)
Robot: cli_assistant

Commands:
  remember <text>  - Store information
  recall <topic>   - Search memories
  stats            - Show memory statistics
  help             - Show this help
  exit             - Quit

============================================================

htm> remember PostgreSQL with pgvector enables semantic search

Remembering: "PostgreSQL with pgvector enables semantic search"
Processing...
[✓] Stored as node 1 (1243.56ms)
    Embedding: 768 dimensions
    Tags: database:postgresql, search:semantic, ai:vector-search

htm> remember TimescaleDB is built on PostgreSQL for time-series

Remembering: "TimescaleDB is built on PostgreSQL for time-series"
Processing...
[✓] Stored as node 2 (1189.32ms)
    Embedding: 768 dimensions
    Tags: database:postgresql, database:timescaledb, time-series

htm> recall PostgreSQL

Searching for: "PostgreSQL"
Strategy: hybrid (vector + fulltext)
[✓] Found 2 memories (45.67ms)

1. Node 1 (cli_user)
   Created: 2025-11-09 14:23:15 UTC
   Content: PostgreSQL with pgvector enables semantic search
   Tags: database:postgresql, search:semantic, ai:vector-search

2. Node 2 (cli_user)
   Created: 2025-11-09 14:23:42 UTC
   Content: TimescaleDB is built on PostgreSQL for time-series
   Tags: database:postgresql, database:timescaledb, time-series

htm> stats

Memory Statistics:

Nodes:
  Total: 2
  With embeddings: 2 (100.0%)
  With tags: 2 (100.0%)

Tags:
  Total: 5
  Average per node: 2.5

Robots:
  Total: 1

Current Robot (cli_assistant):
  Nodes: 2

htm> exit

Goodbye!
```

## Configuration Options

### Custom Logger

```ruby
HTM.configure do |config|
  config.logger = Logger.new('htm_cli.log')
  config.logger.level = Logger::DEBUG
end
```

### Custom Models

```ruby
HTM.configure do |config|
  config.embedding_model = 'custom-embedding-model'
  config.tag_model = 'custom-tag-model'
end
```

### Timeouts

```ruby
HTM.configure do |config|
  config.embedding_timeout = 60   # 1 minute
  config.tag_timeout = 120        # 2 minutes
end
```

## Performance Considerations

### Synchronous Execution Trade-offs

**Pros:**
- Immediate feedback
- Simple error handling
- No background infrastructure needed
- Predictable timing

**Cons:**
- Slower user-facing operations (1-3 seconds per remember)
- Blocks on LLM API calls
- Not suitable for high-throughput scenarios

### Optimization Tips

1. **Batch Operations**: Group multiple `remember()` calls
2. **Caching**: Use query cache for repeated searches
3. **Faster Models**: Use smaller embedding models for CLI
4. **Selective Features**: Disable tags if not needed

```ruby
# Disable tag generation for faster CLI
HTM.configure do |config|
  config.tag_extractor = ->(_text, _ontology) { [] }
end
```

## Troubleshooting

### Database Connection Errors

```bash
# Verify database URL
echo $HTM_DBURL

# Test connection
psql $HTM_DBURL -c "SELECT version();"

# Initialize schema if needed
cd ../.. && rake db_setup
```

### Ollama Connection Errors

```bash
# Check if Ollama is running
curl http://localhost:11434/api/version

# Start Ollama
ollama serve

# Verify models are pulled
ollama list
```

### Slow Performance

```bash
# Use faster models
export EMBEDDING_MODEL=all-minilm
export TAG_MODEL=gemma2:2b

# Or disable features
# (modify htm_cli.rb to skip tag generation)
```

## Extending the CLI

### Add New Commands

```ruby
# In htm_cli.rb, add to handle_command:
when 'export'
  handle_export(args)

# Implement handler:
def handle_export(filename)
  nodes = HTM::Models::Node.all
  File.write(filename, nodes.to_json)
  puts "[✓] Exported #{nodes.count} nodes to #{filename}"
end
```

### Custom Search Strategies

```ruby
def handle_recall(topic)
  # Use different strategies
  vector_results = @htm.recall(topic, strategy: :vector)
  fulltext_results = @htm.recall(topic, strategy: :fulltext)
  hybrid_results = @htm.recall(topic, strategy: :hybrid)

  # Compare and choose best
end
```

## See Also

- [HTM README](../../README.md) - Main documentation
- [Sinatra Example](../sinatra_app/README.md) - Web application example
- [Rails Example](../rails_app/README.md) - Rails integration
- [Job Backends Documentation](../../docs/job_backends.md) - Job backend guide
