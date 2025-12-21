# Standalone Application Example

A simple Ruby application demonstrating HTM's core features with full RubyLLM integration.

**Source:** [`examples/example_app/`](https://github.com/madbomber/htm/tree/main/examples/example_app)

## Overview

The standalone example demonstrates:

- HTM initialization and configuration
- RubyLLM integration for embeddings and tags
- Remembering information with automatic processing
- Comparing search strategies (fulltext, vector, hybrid)
- Background job processing for embeddings and tags

## Prerequisites

```bash
# PostgreSQL with pgvector
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"

# Ollama for embeddings and tags
ollama pull nomic-embed-text
ollama pull gemma3:latest
```

## Running

```bash
cd examples/example_app
ruby app.rb
```

## Code Walkthrough

### Configuration

```ruby
require_relative '../../lib/htm'
require 'ruby_llm'

HTM.configure do |c|
  # Logger
  c.logger = Logger.new($stdout)
  c.logger.level = Logger::INFO

  # Embedding generation (using Ollama)
  c.embedding.provider = :ollama
  c.embedding.model = 'nomic-embed-text'
  c.embedding.dimensions = 768
  c.providers.ollama.url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

  # Tag extraction (using Ollama)
  c.tag.provider = :ollama
  c.tag.model = 'gemma3'

  # Apply default implementations
  c.reset_to_defaults
end
```

### Creating an HTM Instance

```ruby
htm = HTM.new(robot_name: "Example App Robot")
```

### Remembering Information

```ruby
# Store conversation messages
node_1 = htm.remember(
  "HTM provides intelligent memory management for LLM-based applications"
)

node_2 = htm.remember(
  "The two-tier architecture includes working memory and long-term storage"
)

node_3 = htm.remember(
  "Can you explain how the working memory eviction algorithm works?"
)

puts "Remembered 3 messages (nodes #{node_1}, #{node_2}, #{node_3})"
puts "Embeddings and tags are being generated asynchronously..."
```

### Waiting for Background Jobs

```ruby
# Tag generation with LLM can take 10-15 seconds
puts "Waiting for background jobs to complete..."
sleep 15

# Check generated tags
[node_1, node_2, node_3].each do |node_id|
  node = HTM::Models::Node.includes(:tags).find(node_id)
  puts "Node #{node_id}: #{node.tags.map(&:name).join(', ')}"
end
```

### Comparing Search Strategies

```ruby
# 1. Full-text search (doesn't require embeddings)
fulltext_memories = htm.recall(
  "memory",
  timeframe: (Time.now - 3600)..Time.now,
  strategy: :fulltext,
  limit: 3
)

# 2. Vector search (requires embeddings)
vector_memories = htm.recall(
  "intelligent memory system",
  timeframe: (Time.now - 3600)..Time.now,
  strategy: :vector,
  limit: 3
)

# 3. Hybrid search (combines both)
hybrid_memories = htm.recall(
  "working memory architecture",
  timeframe: (Time.now - 3600)..Time.now,
  strategy: :hybrid,
  limit: 3
)
```

## Example Output

```
=== HTM Full-Featured Example Application ===

Checking database connection...
✓ Database configured: htm_development @ localhost

Configuring HTM with RubyLLM...
✓ Configured with Ollama:
  - Embeddings: nomic-embed-text
  - Tags: gemma3
  - Ollama URL: http://localhost:11434

Checking Ollama connection...
✓ Ollama is running

Initializing HTM...

Remembering example conversation...
✓ Remembered 3 conversation messages (nodes 1, 2, 3)

Waiting for background jobs to complete (15 seconds)...

--- Generated Tags ---
Node 1:
  - ai:memory-management
  - software:architecture
Node 2:
  - architecture:two-tier
  - memory:working
  - memory:long-term
Node 3:
  - algorithm:eviction
  - memory:working

--- Embedding Status ---
Node 1: ✓ Generated (768 dimensions)
Node 2: ✓ Generated (768 dimensions)
Node 3: ✓ Generated (768 dimensions)

--- Recall Strategies Comparison ---

1. Full-text Search for 'memory':
Found 3 memories:
  - HTM provides intelligent memory management for LLM-based...
  - The two-tier architecture includes working memory and...
  - Can you explain how the working memory eviction algorit...

2. Vector Search for 'intelligent memory system':
Found 3 memories:
  - HTM provides intelligent memory management for LLM-based...
  - The two-tier architecture includes working memory and...
  - Can you explain how the working memory eviction algorit...

3. Hybrid Search for 'working memory architecture':
Found 3 memories:
  - The two-tier architecture includes working memory and...
  - Can you explain how the working memory eviction algorit...
  - HTM provides intelligent memory management for LLM-based...
```

## HTM Core API Summary

```ruby
# 1. Remember - Store information
htm.remember(content, tags: [], metadata: {})
# - Stores in long-term memory
# - Adds to working memory for immediate use
# - Generates embeddings and tags in background

# 2. Recall - Retrieve relevant memories
htm.recall(topic, timeframe:, strategy:, limit:)
# - Strategies: :fulltext, :vector, :hybrid
# - Results added to working memory

# 3. Forget - Delete a memory
htm.forget(node_id)                           # Soft delete (default)
htm.forget(node_id, soft: false, confirm: :confirmed)  # Permanent
```

## See Also

- [Basic Usage Example](basic-usage.md)
- [LLM Configuration Example](llm-configuration.md)
- [Search Strategies Guide](../guides/search-strategies.md)
