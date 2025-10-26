# EmbeddingService Class

Configuration service for pgai-based database-side embedding generation.

## Overview

!!! warning "Architecture Change (October 2025)"
    `HTM::EmbeddingService` no longer generates embeddings directly. With pgai integration, embedding generation happens automatically via PostgreSQL database triggers. This class now configures pgai settings and provides token counting.

`HTM::EmbeddingService` configures pgai database settings for automatic embedding generation. It supports multiple embedding providers:

- **Ollama** - Local embedding server (default, via `nomic-embed-text` model)
- **OpenAI** - OpenAI's `text-embedding-3-small` model

The service also provides token counting for working memory management.

**Architecture:**
- **Before pgai**: Ruby application → HTTP → Ollama/OpenAI → Embedding → PostgreSQL
- **With pgai**: Ruby application → PostgreSQL → pgai → Ollama/OpenAI → Embedding (automatic via triggers)

## Class Definition

```ruby
class HTM::EmbeddingService
  attr_reader :provider, :model, :dimensions
end
```

## Initialization

### `new(provider, **options)` {: #new }

Create a new embedding service instance and configure pgai database settings.

```ruby
HTM::EmbeddingService.new(
  provider = :ollama,
  model: 'nomic-embed-text',
  ollama_url: nil,
  dimensions: nil,
  db_config: nil
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `provider` | Symbol | `:ollama` | Embedding provider (`:ollama`, `:openai`) |
| `model` | String | `'nomic-embed-text'` | Model name for the provider |
| `ollama_url` | String, nil | From `ENV['OLLAMA_URL']` or `'http://localhost:11434'` | Ollama server URL |
| `dimensions` | Integer, nil | Auto-detected from model | Embedding vector dimensions |
| `db_config` | Hash, nil | Database connection config | Required for pgai configuration |

#### Returns

- `HTM::EmbeddingService` instance

#### Raises

- `RuntimeError` - If provider is unknown (on first `embed` call)

#### Examples

```ruby
# Typical usage within HTM (db_config provided automatically)
htm = HTM.new(robot_name: "My Robot")
# EmbeddingService configured automatically with pgai

# Default: Ollama with nomic-embed-text (768 dimensions)
service = HTM::EmbeddingService.new(
  :ollama,
  db_config: {host: 'localhost', dbname: 'htm_dev', ...}
)
# Automatically calls configure_pgai()

# Ollama with custom model
service = HTM::EmbeddingService.new(
  :ollama,
  model: 'mxbai-embed-large',
  dimensions: 1024,
  db_config: db_config
)

# Custom Ollama URL
service = HTM::EmbeddingService.new(
  :ollama,
  model: 'nomic-embed-text',
  ollama_url: 'http://192.168.1.100:11434',
  db_config: db_config
)

# OpenAI
service = HTM::EmbeddingService.new(
  :openai,
  model: 'text-embedding-3-small',
  db_config: db_config
)
# Requires ENV['OPENAI_API_KEY']

# Without database (no pgai configuration, token counting only)
service = HTM::EmbeddingService.new(:ollama)
# Skips configure_pgai(), only useful for count_tokens()
```

---

## Instance Attributes

### `provider` {: #provider }

The embedding provider being used.

- **Type**: Symbol
- **Read-only**: Yes
- **Values**: `:ollama`, `:openai`

```ruby
service.provider  # => :ollama
```

### `model` {: #model }

The embedding model name.

- **Type**: String
- **Read-only**: Yes

```ruby
service.model  # => "nomic-embed-text"
```

### `dimensions` {: #dimensions }

The embedding vector dimensions.

- **Type**: Integer
- **Read-only**: Yes

```ruby
service.dimensions  # => 768
```

---

## Public Methods

### `configure_pgai()` {: #configure_pgai }

Configure pgai database extension with embedding provider settings.

```ruby
configure_pgai()
```

#### Parameters

None (uses instance variables: `@provider`, `@model`, `@ollama_url`, `@dimensions`)

#### Returns

- `nil`

#### Raises

- `PG::Error` - If database connection fails or pgai extension not available

#### Examples

```ruby
# Automatically called during initialization if db_config provided
service = HTM::EmbeddingService.new(
  :ollama,
  model: 'nomic-embed-text',
  db_config: {host: 'localhost', dbname: 'htm'}
)
# configure_pgai() called automatically

# Manual configuration (advanced)
service = HTM::EmbeddingService.new(:ollama)
service.instance_variable_set(:@db_config, db_config)
service.configure_pgai
```

#### Technical Details

Sets PostgreSQL session variables via `htm_set_embedding_config()` function:

```sql
-- For Ollama
SELECT htm_set_embedding_config(
  'ollama',                    -- provider
  'nomic-embed-text',          -- model
  'http://localhost:11434',    -- ollama_url
  NULL,                        -- openai_api_key
  768                          -- dimensions
);

-- For OpenAI
SELECT htm_set_embedding_config(
  'openai',                    -- provider
  'text-embedding-3-small',    -- model
  NULL,                        -- ollama_url
  'sk-...',                    -- openai_api_key
  1536                         -- dimensions
);
```

These settings are used by pgai database triggers for automatic embedding generation.

---

### `embed(text)` {: #embed } **DEPRECATED**

!!! danger "Deprecated Method"
    **This method is deprecated and will raise an error.** Embedding generation now happens automatically via pgai database triggers. Do not call this method.

Attempt to generate a vector embedding (raises deprecation error).

```ruby
embed(text)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | String | Text to embed (ignored) |

#### Returns

Never returns - always raises error

#### Raises

- `HTM::EmbeddingError` - Always raises with deprecation message

#### Examples

```ruby
# Old code (no longer works)
embedding = service.embed("text")
# Raises: HTM::EmbeddingError: Direct embedding generation is deprecated in HTM.
#         Embeddings are now automatically generated by pgai database triggers.

# New code (automatic via pgai)
htm.add_node("key", "PostgreSQL is powerful", type: :fact)
# Embedding generated automatically by database trigger!
# No embed() call needed
```

#### Migration Guide

If you have code calling `embed()`:

```ruby
# Before pgai
embedding = embedding_service.embed(text)
htm.add_node(key, value, embedding: embedding)

# After pgai (correct)
htm.add_node(key, value)
# Embedding generated automatically by pgai trigger

# Query embeddings also automatic
memories = htm.recall(timeframe: "last week", topic: "database")
# pgai generates query embedding in SQL automatically
```

---

### `count_tokens(text)` {: #count_tokens }

Count the number of tokens in the text.

```ruby
count_tokens(text)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | String | Text to count |

#### Returns

- `Integer` - Token count

#### Examples

```ruby
# Count tokens
text = "This is a sample sentence for token counting."
tokens = service.count_tokens(text)
# => 11

# Empty string
service.count_tokens("")  # => 0

# Large text
large_text = File.read("document.txt")
token_count = service.count_tokens(large_text)
puts "Document has #{token_count} tokens"

# Check if fits in context window
if service.count_tokens(text) < 8000
  # Fits in 8K context
end
```

#### Technical Details

- Uses `tiktoken_ruby` with GPT-3.5-turbo encoding
- Falls back to simple word count if tokenizer fails
- Token count is approximate (varies by model)

---

## Supported Providers

!!! info "pgai Integration"
    All providers are now accessed via pgai database extension. Configuration happens during initialization, and embedding generation is handled by database triggers.

### Ollama (Default)

**Status**: ✅ Fully implemented via pgai

Local embedding server with various models, accessed via pgai database triggers.

#### Setup

```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull nomic-embed-text model (default)
ollama pull nomic-embed-text

# Or use other embedding models
ollama pull mxbai-embed-large
ollama pull all-minilm

# Verify Ollama is running
curl http://localhost:11434/api/version
```

#### Configuration

```ruby
# Default (nomic-embed-text on localhost)
htm = HTM.new(robot_name: "My Robot")
# Configures pgai automatically

# Custom URL
htm = HTM.new(
  robot_name: "My Robot",
  embedding_provider: :ollama,
  embedding_model: 'nomic-embed-text',
  ollama_url: 'http://192.168.1.100:11434'
)

# From environment
ENV['OLLAMA_URL'] = 'http://ollama.local:11434'
htm = HTM.new(robot_name: "My Robot")
```

#### Available Models

| Model | Dimensions | Size | Speed |
|-------|------------|------|-------|
| `nomic-embed-text` (default) | 768 | ~274MB | Fast |
| `mxbai-embed-large` | 1024 | ~670MB | Medium |
| `all-minilm` | 384 | ~23MB | Very Fast |

#### Error Handling

If Ollama is unavailable, pgai database trigger will fail:

```ruby
htm.add_node("key", "value")
# PG::Error: Connection to server at "localhost" (::1), port 11434 failed
# Ensure Ollama is running: ollama serve
```

Solution:
```bash
# Start Ollama
ollama serve

# Pull model if needed
ollama pull nomic-embed-text
```

---

### OpenAI

**Status**: ✅ Fully implemented via pgai

Uses OpenAI's embedding API, accessed via pgai database triggers.

#### Configuration

```ruby
# Set API key
ENV['OPENAI_API_KEY'] = 'sk-...'

# Initialize HTM with OpenAI
htm = HTM.new(
  robot_name: "My Robot",
  embedding_provider: :openai,
  embedding_model: 'text-embedding-3-small'
)
# Configures pgai automatically

# Add node - embedding generated via pgai + OpenAI API
htm.add_node("key", "PostgreSQL is powerful", type: :fact)
# pgai calls OpenAI API automatically in database trigger
```

#### Models

| Model | Dimensions | Cost (per 1M tokens) |
|-------|------------|---------------------|
| `text-embedding-3-small` (recommended) | 1536 | $0.02 |
| `text-embedding-ada-002` (legacy) | 1536 | $0.10 |

!!! warning "Dimension Limit"
    `text-embedding-3-large` (3072 dimensions) exceeds pgvector's HNSW index limit of 2000 dimensions and is not supported.

#### Error Handling

If API key is missing or invalid:

```ruby
htm.add_node("key", "value")
# PG::Error: OpenAI API error: Incorrect API key provided
# Ensure OPENAI_API_KEY is set correctly
```

---

## Usage Patterns

### Basic Embedding

```ruby
service = HTM::EmbeddingService.new

# Single embedding
embedding = service.embed("database optimization")

# Batch embeddings
texts = ["fact 1", "fact 2", "fact 3"]
embeddings = texts.map { |text| service.embed(text) }
```

### Token Management

```ruby
service = HTM::EmbeddingService.new

# Check token count before processing
text = "Long document content..."
tokens = service.count_tokens(text)

if tokens > 8000
  puts "Warning: Text is #{tokens} tokens, may need chunking"
end

# Calculate working memory usage
memories = ["memory 1", "memory 2", "memory 3"]
total_tokens = memories.sum { |m| service.count_tokens(m) }
puts "Total: #{total_tokens} tokens"
```

### Similarity Search

```ruby
service = HTM::EmbeddingService.new

# Create embeddings for search
query = "database performance"
query_embedding = service.embed(query)

documents = [
  "PostgreSQL query optimization",
  "API rate limiting",
  "Database indexing strategies"
]

# Calculate similarities
similarities = documents.map do |doc|
  doc_embedding = service.embed(doc)
  similarity = query_embedding.zip(doc_embedding).map { |a, b| a * b }.sum
  { document: doc, similarity: similarity }
end

# Sort by similarity
ranked = similarities.sort_by { |s| -s[:similarity] }
ranked.each do |result|
  puts "[#{result[:similarity].round(3)}] #{result[:document]}"
end
```

### Caching Embeddings

```ruby
# Cache embeddings to avoid regeneration
class CachedEmbeddingService
  def initialize(service)
    @service = service
    @cache = {}
  end

  def embed(text)
    @cache[text] ||= @service.embed(text)
  end

  def count_tokens(text)
    @service.count_tokens(text)
  end
end

# Usage
service = HTM::EmbeddingService.new
cached = CachedEmbeddingService.new(service)

embedding1 = cached.embed("same text")  # Generates
embedding2 = cached.embed("same text")  # From cache
```

---

## Performance Considerations

### Embedding Generation

| Provider | Speed | Notes |
|----------|-------|-------|
| Ollama (local) | ~50-100 ms | Depends on model and hardware |
| OpenAI | ~100-200 ms | Network latency + API processing |
| Cohere | ~100-200 ms | Network latency + API processing |
| Local | ~10-50 ms | Direct model inference |

### Token Counting

- Very fast (~1ms for typical text)
- Uses efficient tokenizer (tiktoken)
- Falls back to simple word count if tokenizer fails

### Optimization Tips

1. **Batch Processing**: Generate embeddings for multiple texts together
2. **Caching**: Cache embeddings for frequently accessed content
3. **Model Selection**: Smaller models (fewer dimensions) are faster
4. **Local Deployment**: Ollama avoids network latency

---

## Error Handling

### Connection Errors

```ruby
# Ollama not running
service = HTM::EmbeddingService.new(:ollama)
embedding = service.embed("text")
# => Warning logged, returns random vector

# OpenAI API key missing
service = HTM::EmbeddingService.new(:openai)
embedding = service.embed("text")
# => Warning: STUB implementation
```

### Invalid Provider

```ruby
service = HTM::EmbeddingService.new(:invalid_provider)
embedding = service.embed("text")
# => RuntimeError: Unknown embedding provider: invalid_provider
```

### Best Practices

```ruby
# Graceful fallback
begin
  service = HTM::EmbeddingService.new(:ollama)
  embedding = service.embed(text)
rescue => e
  warn "Embedding failed: #{e.message}"
  # Use fallback or skip
end

# Check provider before critical operations
if service.provider == :ollama
  # Verify Ollama is running
  begin
    test_embedding = service.embed("test")
    if test_embedding.all? { |x| x.between?(-1, 1) }
      # Valid embedding
    end
  rescue
    # Ollama unavailable
  end
end
```

---

## Embedding Vector Format

### Dimensions

Default: **1536 dimensions** (matches OpenAI embeddings)

```ruby
embedding = service.embed("text")
embedding.length  # => 1536
```

### Value Range

Typically normalized to unit vector:

```ruby
# Values are floats between -1.0 and 1.0
embedding.all? { |x| x.between?(-1.0, 1.0) }  # => true

# Magnitude approximately 1.0
magnitude = Math.sqrt(embedding.map { |x| x**2 }.sum)
magnitude.round(2)  # ≈ 1.0
```

### Storage

Stored in PostgreSQL using pgvector extension:

```sql
CREATE TABLE nodes (
  embedding vector(1536)
);

-- Insert
INSERT INTO nodes (embedding) VALUES ('[0.123, -0.456, ...]'::vector);

-- Search
SELECT * FROM nodes
ORDER BY embedding <=> '[query_embedding]'::vector
LIMIT 10;
```

---

## Advanced Usage

### Custom Similarity Functions

```ruby
class SimilarityCalculator
  def self.cosine(v1, v2)
    dot_product = v1.zip(v2).map { |a, b| a * b }.sum
    magnitude1 = Math.sqrt(v1.map { |x| x**2 }.sum)
    magnitude2 = Math.sqrt(v2.map { |x| x**2 }.sum)
    dot_product / (magnitude1 * magnitude2)
  end

  def self.euclidean(v1, v2)
    Math.sqrt(v1.zip(v2).map { |a, b| (a - b)**2 }.sum)
  end

  def self.dot_product(v1, v2)
    v1.zip(v2).map { |a, b| a * b }.sum
  end
end

# Usage
emb1 = service.embed("text 1")
emb2 = service.embed("text 2")

cosine_sim = SimilarityCalculator.cosine(emb1, emb2)
euclidean_dist = SimilarityCalculator.euclidean(emb1, emb2)
```

### Embedding Arithmetic

```ruby
# Concept: king - man + woman ≈ queen
king = service.embed("king")
man = service.embed("man")
woman = service.embed("woman")

result = king.zip(man, woman).map { |k, m, w| k - m + w }

# Find closest to result
candidates = ["queen", "prince", "princess", "duke"]
similarities = candidates.map do |word|
  emb = service.embed(word)
  sim = result.zip(emb).map { |a, b| a * b }.sum
  { word: word, similarity: sim }
end

best_match = similarities.max_by { |s| s[:similarity] }
puts "Closest: #{best_match[:word]}"  # Likely "queen"
```

### Dimensionality Reduction

```ruby
# For visualization or storage optimization
require 'matrix'

def reduce_dimensions(embedding, target_dim)
  # Simple truncation (not ideal, but fast)
  embedding.take(target_dim)
end

# Reduce 1536 -> 128 dimensions
full_embedding = service.embed("text")
reduced = reduce_dimensions(full_embedding, 128)

# Note: Loses information, use proper PCA/t-SNE for production
```

---

## See Also

- [HTM API](htm.md) - Main class that uses EmbeddingService
- [LongTermMemory API](long-term-memory.md) - Vector search implementation
- [Ollama Documentation](https://ollama.ai/docs) - Ollama setup and models
- [pgvector Documentation](https://github.com/pgvector/pgvector) - PostgreSQL vector extension
