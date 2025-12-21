# LLM Configuration Example

This example demonstrates the various ways to configure LLM providers for embeddings and tag extraction in HTM.

**Source:** [`examples/custom_llm_configuration.rb`](https://github.com/madbomber/htm/blob/main/examples/custom_llm_configuration.rb)

## Overview

HTM uses RubyLLM for multi-provider LLM support. This example shows:

- Using default configuration (Ollama)
- Custom lambda-based embeddings and tags
- Service object integration
- Mixed configuration patterns
- Provider-specific settings

## Running the Example

```bash
ruby examples/custom_llm_configuration.rb
```

## Configuration Patterns

### Default Configuration (Ollama)

```ruby
HTM.configure  # Uses defaults from config files

htm = HTM.new(robot_name: "DefaultBot")
# Uses: ollama/nomic-embed-text for embeddings
# Uses: ollama/gemma3:latest for tag extraction
```

### Custom Lambda Functions

```ruby
HTM.configure do |config|
  # Custom embedding generator
  config.embedding_generator = lambda do |text|
    # Your custom embedding logic
    # Must return Array<Float>
    MyEmbeddingService.embed(text)
  end

  # Custom tag extractor
  config.tag_extractor = lambda do |text, existing_ontology|
    # Your custom tag extraction logic
    # Must return Array<String>
    MyTagService.extract(text, ontology: existing_ontology)
  end
end
```

### Service Object Pattern

```ruby
class MyAppLLMService
  def self.embed(text)
    # Integrate with LangChain, LlamaIndex, or custom infrastructure
    # Returns embedding vector as Array<Float>
    Array.new(1024) { rand }
  end

  def self.extract_tags(text, ontology)
    # Returns array of hierarchical tag strings
    ['app:feature:memory', 'app:component:llm']
  end
end

HTM.configure do |config|
  config.embedding_generator = ->(text) { MyAppLLMService.embed(text) }
  config.tag_extractor = ->(text, ontology) { MyAppLLMService.extract_tags(text, ontology) }
end
```

### Provider Configuration

```ruby
HTM.configure do |config|
  # Configure embedding provider
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
  config.embedding.dimensions = 1536

  # Configure tag extraction provider
  config.tag.provider = :anthropic
  config.tag.model = 'claude-3-haiku-20240307'

  # Provider-specific settings
  config.providers.ollama.url = 'http://localhost:11434'
  config.providers.openai.api_key = ENV['OPENAI_API_KEY']
end
```

### Mixed Configuration

Use custom embedding with default tag extraction:

```ruby
HTM.configure do |config|
  # Custom embedding
  config.embedding_generator = ->(text) {
    MyCustomEmbedder.generate(text)
  }

  # Keep default RubyLLM-based tag extraction
  # (uses configured tag.provider and tag.model)
end
```

## Supported Providers

HTM uses RubyLLM which supports:

| Provider | Embedding Models | Chat Models |
|----------|-----------------|-------------|
| Ollama (default) | `nomic-embed-text`, `mxbai-embed-large` | `gemma3`, `llama3`, `mistral` |
| OpenAI | `text-embedding-3-small`, `text-embedding-3-large` | `gpt-4o-mini`, `gpt-4o` |
| Anthropic | - | `claude-3-haiku`, `claude-3-sonnet` |
| Google Gemini | `text-embedding-004` | `gemini-1.5-flash`, `gemini-1.5-pro` |
| Azure OpenAI | Same as OpenAI | Same as OpenAI |
| HuggingFace | Various | Various |
| AWS Bedrock | Titan, Cohere | Claude, Llama |
| DeepSeek | - | `deepseek-chat` |

## Environment Variables

```bash
# Ollama (default)
export OLLAMA_URL="http://localhost:11434"

# OpenAI
export OPENAI_API_KEY="sk-..."
export OPENAI_ORGANIZATION="org-..."

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Google Gemini
export GEMINI_API_KEY="..."

# Azure OpenAI
export AZURE_OPENAI_API_KEY="..."
export AZURE_OPENAI_ENDPOINT="https://....openai.azure.com/"
```

## Integration with HTM Operations

When you call `htm.remember()`, HTM uses your configured generators:

```ruby
HTM.configure do |config|
  config.embedding_generator = ->(text) {
    puts "Embedding: #{text[0..40]}..."
    MyService.embed(text)
  }
end

# This triggers your custom embedding generator
node_id = htm.remember("PostgreSQL supports vector search")
```

## See Also

- [Basic Usage Example](basic-usage.md)
- [Configuration Guide](../getting-started/quick-start.md)
- [EmbeddingService API](../api/embedding-service.md)
