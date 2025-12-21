# Examples

HTM includes working example programs that demonstrate various features and integration patterns. These examples show real-world usage patterns and can serve as templates for your own applications.

## Running Examples

All examples require the database to be configured:

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
```

Then run any example with:

```bash
ruby examples/<example_name>.rb
```

## Available Examples

### Core Usage

| Example | Description |
|---------|-------------|
| [Basic Usage](basic-usage.md) | Core HTM operations: remember, recall, forget |
| [LLM Configuration](llm-configuration.md) | Configure providers, custom embeddings, and tag extractors |
| [File Loading](file-loading.md) | Load markdown files with frontmatter and chunking |

### Advanced Features

| Example | Description |
|---------|-------------|
| [Timeframes](timeframes.md) | Natural language temporal queries |
| [Robot Groups](robot-groups.md) | Multi-robot coordination with shared memory |
| [MCP Client](mcp-client.md) | Interactive AI chat with memory tools |
| [Telemetry](telemetry.md) | Prometheus metrics and Grafana visualization |

## Quick Reference

### Basic Operations

```ruby
# Initialize HTM
htm = HTM.new(robot_name: "My Robot")

# Remember information
node_id = htm.remember("PostgreSQL supports vector search via pgvector.")

# Recall memories
results = htm.recall("database features", strategy: :hybrid, limit: 5)

# Forget a memory
htm.forget(node_id)
```

### Configuration

```ruby
HTM.configure do |config|
  # Use any RubyLLM-supported provider
  config.embedding.provider = :openai  # or :ollama, :anthropic, etc.
  config.embedding.model = 'text-embedding-3-small'

  config.tag.provider = :openai
  config.tag.model = 'gpt-4o-mini'
end
```

### File Loading

```ruby
# Load markdown files into memory
htm.load_file("docs/guide.md")
htm.load_directory("docs/", pattern: "**/*.md")

# Query nodes from a file
nodes = htm.nodes_from_file("docs/guide.md")
```

## Prerequisites

Most examples require:

1. **PostgreSQL** with pgvector extension
2. **LLM Provider** - Ollama (default), OpenAI, Anthropic, etc.
3. **Ruby 3.2+** with HTM gem installed

### Ollama Setup (Default Provider)

```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull required models
ollama pull nomic-embed-text  # For embeddings
ollama pull gemma3:latest     # For tag extraction
```

### Using Cloud Providers

```bash
# OpenAI
export OPENAI_API_KEY="your-key"

# Anthropic
export ANTHROPIC_API_KEY="your-key"

# Google Gemini
export GEMINI_API_KEY="your-key"
```

## See Also

- [Getting Started Guide](../getting-started/quick-start.md)
- [API Reference](../api/htm.md)
- [Architecture Overview](../architecture/overview.md)
