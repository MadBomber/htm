# Basic Usage Example

This example demonstrates the core HTM operations: configuring the system, remembering information, and recalling memories.

**Source:** [`examples/basic_usage.rb`](https://github.com/madbomber/htm/blob/main/examples/basic_usage.rb)

## Overview

The basic usage example shows:

- Configuring HTM with a provider (Ollama by default)
- Initializing an HTM instance for a robot
- Storing memories with `remember()`
- Retrieving memories with `recall()`
- Using different search strategies

## Running the Example

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
ruby examples/basic_usage.rb
```

## Code Walkthrough

### Configuration

```ruby
HTM.configure do |config|
  # Provider configuration (Ollama is default)
  config.embedding.provider = :ollama
  config.embedding.model = 'nomic-embed-text:latest'
  config.embedding.dimensions = 768

  config.tag.provider = :ollama
  config.tag.model = 'gemma3:latest'

  # Use inline job backend for synchronous execution
  # In production, use :thread or :sidekiq for async
  config.job.backend = :inline
end
```

### Initialize HTM

```ruby
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000  # Token limit
)
```

### Storing Memories

```ruby
# Remember automatically generates embeddings and tags
node_id = htm.remember(
  "PostgreSQL supports native vector search with pgvector."
)

# Tags are extracted via LLM
# Embeddings enable semantic search
```

### Recalling Memories

```ruby
# Full-text search (keyword matching)
memories = htm.recall(
  "PostgreSQL",
  timeframe: (Time.now - 3600)..Time.now,
  limit: 5,
  strategy: :fulltext
)

# Vector search (semantic similarity)
memories = htm.recall("database features", strategy: :vector)

# Hybrid search (combines both)
memories = htm.recall("database features", strategy: :hybrid)
```

## Expected Output

```
HTM Basic Usage Example
============================================================

1. Configuring HTM with Ollama provider...
✓ HTM configured with Ollama provider (inline job backend)

2. Initializing HTM for 'Code Helper' robot...
✓ HTM initialized
  Robot ID: 1
  Robot Name: Code Helper
  Embedding Service: ollama (nomic-embed-text:latest)

3. Remembering information...
✓ Remembered decision about database choice (node 1)
✓ Remembered decision about RAG approach (node 2)
✓ Remembered fact about user preferences (node 3)

4. Recalling memories about 'PostgreSQL'...
✓ Found 1 memories
  - Node 1: We decided to use PostgreSQL for HTM storage because...

============================================================
✓ Example completed successfully!
```

## Key Concepts

### Search Strategies

| Strategy | Description | Best For |
|----------|-------------|----------|
| `:fulltext` | Keyword matching with PostgreSQL tsvector | Exact term matches |
| `:vector` | Semantic similarity with pgvector | Conceptual queries |
| `:hybrid` | Combines both with RRF scoring | General queries |

### Job Backends

| Backend | Behavior | Use Case |
|---------|----------|----------|
| `:inline` | Synchronous execution | Examples, testing |
| `:thread` | Background threads | Development |
| `:sidekiq` | Sidekiq workers | Production |

## See Also

- [LLM Configuration Example](llm-configuration.md)
- [Adding Memories Guide](../guides/adding-memories.md)
- [Search Strategies Guide](../guides/search-strategies.md)
