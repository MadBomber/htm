# EmbeddingService Class

Vector embedding generation service for semantic search.

## Overview

`HTM::EmbeddingService` generates vector embeddings from text for semantic similarity search. It supports multiple embedding providers:

- **Ollama** - Local embedding server (default, via `gpt-oss` model)
- **OpenAI** - OpenAI's `text-embedding-3-small` model
- **Cohere** - Cohere embedding API
- **Local** - Local sentence transformers

The service also provides token counting for working memory management.

## Class Definition

```ruby
class HTM::EmbeddingService
  attr_reader :provider, :llm_client
end
```

## Initialization

### `new(provider, **options)` {: #new }

Create a new embedding service instance.

```ruby
HTM::EmbeddingService.new(
  provider = :ollama,
  model: 'gpt-oss',
  ollama_url: nil
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `provider` | Symbol | `:ollama` | Embedding provider (`:ollama`, `:openai`, `:cohere`, `:local`) |
| `model` | String | `'gpt-oss'` | Model name for the provider |
| `ollama_url` | String, nil | From `ENV['OLLAMA_URL']` or `'http://localhost:11434'` | Ollama server URL |

#### Returns

- `HTM::EmbeddingService` instance

#### Raises

- `RuntimeError` - If provider is unknown (on first `embed` call)

#### Examples

```ruby
# Default: Ollama with gpt-oss
service = HTM::EmbeddingService.new

# Ollama with custom model
service = HTM::EmbeddingService.new(:ollama, model: 'nomic-embed-text')

# Custom Ollama URL
service = HTM::EmbeddingService.new(
  :ollama,
  model: 'gpt-oss',
  ollama_url: 'http://192.168.1.100:11434'
)

# OpenAI (stub implementation)
service = HTM::EmbeddingService.new(
  :openai,
  model: 'text-embedding-3-small'
)

# Cohere (stub implementation)
service = HTM::EmbeddingService.new(:cohere)

# Local sentence transformers (stub implementation)
service = HTM::EmbeddingService.new(:local)
```

---

## Instance Attributes

### `provider` {: #provider }

The embedding provider being used.

- **Type**: Symbol
- **Read-only**: Yes
- **Values**: `:ollama`, `:openai`, `:cohere`, `:local`

```ruby
service.provider  # => :ollama
```

### `llm_client` {: #llm_client }

LLM client instance (currently unused, placeholder for future compatibility).

- **Type**: nil
- **Read-only**: Yes

```ruby
service.llm_client  # => nil
```

---

## Public Methods

### `embed(text)` {: #embed }

Generate a vector embedding for the given text.

```ruby
embed(text)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | String | Text to embed |

#### Returns

- `Array<Float>` - Embedding vector (typically 1536 dimensions)

#### Raises

- `RuntimeError` - If provider is unknown

#### Examples

```ruby
# Generate embedding
text = "PostgreSQL is a powerful relational database"
embedding = service.embed(text)
# => [0.123, -0.456, 0.789, ..., 0.234]  # 1536 floats

# Check dimensions
embedding.length  # => 1536

# Embeddings are normalized
magnitude = Math.sqrt(embedding.map { |x| x**2 }.sum)
# magnitude ≈ 1.0 for normalized vectors

# Use in similarity calculation
text1 = "database optimization"
text2 = "performance tuning"

emb1 = service.embed(text1)
emb2 = service.embed(text2)

# Cosine similarity
similarity = emb1.zip(emb2).map { |a, b| a * b }.sum
puts "Similarity: #{similarity}"  # 0.0 to 1.0
```

#### Provider-Specific Behavior

##### Ollama

Makes HTTP POST request to Ollama's `/api/embeddings` endpoint:

```ruby
# Request
{
  "model": "gpt-oss",
  "prompt": "text to embed"
}

# Response
{
  "embedding": [0.123, -0.456, ...]
}
```

If Ollama is unavailable, falls back to random vectors with a warning.

##### OpenAI (Stub)

Currently returns random vectors. Production implementation should:

```ruby
# Intended implementation (not yet implemented)
require 'openai'

client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
response = client.embeddings(
  parameters: {
    model: "text-embedding-3-small",
    input: text
  }
)
embedding = response.dig("data", 0, "embedding")
```

##### Cohere (Stub)

Currently returns random vectors. Production implementation pending.

##### Local (Stub)

Currently returns random vectors. Intended for local sentence transformer models.

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

### Ollama (Default)

**Status**: ✅ Fully implemented

Local embedding server with various models.

#### Setup

```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull gpt-oss model
ollama pull gpt-oss

# Or use other embedding models
ollama pull nomic-embed-text
ollama pull mxbai-embed-large
```

#### Configuration

```ruby
# Default (localhost)
service = HTM::EmbeddingService.new

# Custom URL
service = HTM::EmbeddingService.new(
  :ollama,
  ollama_url: 'http://192.168.1.100:11434'
)

# From environment
ENV['OLLAMA_URL'] = 'http://ollama.local:11434'
service = HTM::EmbeddingService.new
```

#### Available Models

| Model | Dimensions | Size | Speed |
|-------|------------|------|-------|
| `gpt-oss` | 1536 | ~270MB | Fast |
| `nomic-embed-text` | 768 | ~274MB | Fast |
| `mxbai-embed-large` | 1024 | ~670MB | Medium |
| `all-minilm` | 384 | ~23MB | Very Fast |

#### Error Handling

If Ollama is unavailable:

```ruby
embedding = service.embed("text")
# Warning: Error generating embedding with Ollama: Connection refused
# Warning: Falling back to stub embeddings (random vectors)
# Warning: Please ensure Ollama is running and the gpt-oss model is available
# => [random vector]
```

---

### OpenAI

**Status**: ⚠️ Stub implementation

Uses OpenAI's embedding API.

#### Planned Configuration

```ruby
# Set API key
ENV['OPENAI_API_KEY'] = 'sk-...'

# Initialize
service = HTM::EmbeddingService.new(
  :openai,
  model: 'text-embedding-3-small'
)

# Generate embedding
embedding = service.embed("text")
```

#### Models

| Model | Dimensions | Cost (per 1M tokens) |
|-------|------------|---------------------|
| `text-embedding-3-small` | 1536 | $0.02 |
| `text-embedding-3-large` | 3072 | $0.13 |
| `ada-002` (legacy) | 1536 | $0.10 |

#### Current Behavior

Returns random 1536-dimensional vectors with warning:

```
Warning: STUB: Using random embeddings. Implement OpenAI API integration for production.
```

---

### Cohere

**Status**: ⚠️ Stub implementation

Uses Cohere's embedding API.

#### Planned Configuration

```ruby
# Set API key
ENV['COHERE_API_KEY'] = 'xxx'

# Initialize
service = HTM::EmbeddingService.new(:cohere)

# Generate embedding
embedding = service.embed("text")
```

#### Current Behavior

Returns random 1536-dimensional vectors with warning:

```
Warning: STUB: Cohere embedding not yet implemented
```

---

### Local

**Status**: ⚠️ Stub implementation

Intended for local sentence transformer models (Python-based).

#### Planned Implementation

Would use models like:

- `sentence-transformers/all-MiniLM-L6-v2` (384 dim)
- `sentence-transformers/all-mpnet-base-v2` (768 dim)
- `BAAI/bge-large-en-v1.5` (1024 dim)

#### Current Behavior

Returns random 1536-dimensional vectors with warning:

```
Warning: STUB: Local embedding not yet implemented
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
