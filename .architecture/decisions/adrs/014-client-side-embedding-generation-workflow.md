# ADR-014: Client-Side Embedding Generation Workflow

**Status**: ~~Accepted~~ **SUPERSEDED** (2025-10-29)

**Superseded By**: ADR-016 (Async Embedding and Tag Generation)

**Date**: 2025-10-29

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## ⚠️ DECISION SUPERSEDED (2025-10-29)

**This ADR has been superseded by ADR-016.**

**Reason**: Synchronous embedding generation before save added 50-100ms latency to node creation. The async approach (ADR-016) provides much better user experience:
- Node saved immediately (~15ms)
- Embedding generated in background job
- User doesn't wait for LLM operations

See [ADR-016: Async Embedding and Tag Generation](./016-async-embedding-and-tag-generation.md) for current architecture.

---

## Context (Historical)

After the reversal of ADR-011 (database-side embedding generation with pgai), HTM returned to client-side embedding generation. However, the specific workflow, timing, and error handling strategies for embedding generation were not formally documented.

This ADR establishes the canonical approach for when, how, and where embeddings are generated in the HTM architecture.

### Key Questions

1. **When**: When are embeddings generated during the node lifecycle?
2. **Where**: Client-side (Ruby) vs. database-side (PostgreSQL)?
3. **How**: Synchronous vs. asynchronous generation?
4. **Error Handling**: What happens if embedding generation fails?
5. **Updates**: When/how are embeddings regenerated?
6. **Dimensions**: How are variable embedding dimensions handled?

---

## Decision

HTM will generate embeddings **client-side in Ruby before database insertion** using the `EmbeddingService` class, with **synchronous generation** and **graceful degradation** on failures.

### Embedding Generation Workflow

```ruby
# 1. Application creates content
content = "PostgreSQL with pgvector provides vector similarity search"

# 2. EmbeddingService generates embedding BEFORE database operation
embedding_service = HTM::EmbeddingService.new(:ollama, model: 'nomic-embed-text')
embedding = embedding_service.embed(content)  # Array<Float>, e.g. 768 dimensions

# 3. Embedding included in database INSERT
ltm.add(
  content: content,
  speaker: 'user',
  robot_id: robot.id,
  embedding: embedding,  # Pre-generated
  embedding_dimension: embedding.length
)

# 4. PostgreSQL stores embedding in vector column
# nodes.embedding::vector(2000)
```

### Key Principles

**Principle 1: Pre-Generation**
- Embeddings generated in application code BEFORE database operation
- Never rely on database triggers for embedding generation
- Embedding passed to database as parameter, not generated in-database

**Principle 2: Synchronous by Default**
- Embeddings generated synchronously in request path
- Acceptable latency (50-100ms per embedding with local Ollama)
- Simplifies error handling and debugging

**Principle 3: Graceful Degradation**
- If embedding generation fails, node still inserted (with `embedding: nil`)
- Background job can retry embedding generation later
- Nodes without embeddings excluded from vector search results

**Principle 4: Dimension Flexibility**
- Support embeddings from 1 to 2000 dimensions
- Store actual dimension in `embedding_dimension` column
- Validate dimension doesn't exceed database column limit (2000)

---

## Rationale

### Why Client-Side?

**Developer Experience**:
- ✅ Works reliably on all platforms (macOS, Linux, Cloud)
- ✅ Simple setup (just Ollama + Ruby gem)
- ✅ Easy debugging (errors visible in Ruby stack traces)
- ✅ No PostgreSQL extension dependencies

**Code Clarity**:
- ✅ Explicit embedding generation visible in code
- ✅ Easy to mock/stub in tests
- ✅ Clear separation: Ruby generates, PostgreSQL stores
- ✅ Embedding logic can be modified without database migrations

**Operational Simplicity**:
- ✅ Unified architecture (no local vs. cloud split)
- ✅ No database trigger management
- ✅ Connection pooling handled by Ruby HTTP library
- ✅ Retry logic in application layer (more flexible)

### Why Synchronous?

**Performance Acceptable**:
- Local Ollama: ~50ms per embedding (nomic-embed-text)
- Batch operations: Can optimize with connection reuse
- Most operations add single nodes (not bulk)

**Simpler Error Handling**:
- Immediate feedback if embedding fails
- Can present error to user or log synchronously
- No need for background job infrastructure for simple case

**Consistency**:
- Embedding available immediately after insertion
- No window where node exists but has no embedding
- Vector search works immediately after node creation

### Why Graceful Degradation?

**Reliability**:
- Ollama service may be down temporarily
- Network issues may prevent embedding generation
- Node data is more valuable than embedding

**Recovery**:
- Background job can retry embedding generation
- Manual re-embedding possible: `UPDATE nodes SET content = content`
- Query can filter for nodes missing embeddings

---

## Implementation

### EmbeddingService API

Located in `lib/htm/embedding_service.rb`:

```ruby
class HTM::EmbeddingService
  # Initialize with provider and model
  def initialize(provider = :ollama, model: nil, ollama_url: nil, dimensions: nil)
    @provider = provider  # :ollama or :openai
    @model = model || default_model_for_provider(provider)
    @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
    @dimensions = dimensions || KNOWN_DIMENSIONS[@model] || 768
  end

  # Generate embedding for text (synchronous)
  # @param text [String] Content to embed
  # @return [Array<Float>] Embedding vector
  # @raises [HTM::EmbeddingError] If generation fails
  def embed(text)
    case @provider
    when :ollama
      embed_with_ollama(text)  # HTTP POST to Ollama API
    when :openai
      embed_with_openai(text)  # HTTP POST to OpenAI API
    end
  end

  # Get expected embedding dimensions for current model
  # @return [Integer] Dimension count
  def embedding_dimensions
    @dimensions
  end

  # Count tokens in text (for working memory management)
  # @param text [String] Text to count
  # @return [Integer] Token count
  def count_tokens(text)
    @tokenizer.encode(text.to_s).length
  end
end
```

### LongTermMemory Integration

Located in `lib/htm/long_term_memory.rb`:

```ruby
class HTM::LongTermMemory
  def add(content:, speaker:, robot_id:, embedding: nil, **options)
    # Embedding is OPTIONAL parameter
    # If not provided, node inserted without embedding
    # If provided, must be Array<Float> with length <= 2000

    node = HTM::Models::Node.create!(
      content: content,
      speaker: speaker,
      robot_id: robot_id,
      embedding: embedding,  # Can be nil
      embedding_dimension: embedding&.length,
      **options
    )

    node
  end
end
```

### Error Handling

```ruby
class HTM
  def add_message(content, speaker: 'user', type: nil, **options)
    # Generate embedding with error handling
    begin
      embedding = @embedding_service.embed(content)
    rescue HTM::EmbeddingError => e
      # Log error but continue with node insertion
      warn "Embedding generation failed: #{e.message}"
      embedding = nil  # Node will be created without embedding
    end

    # Insert node (with or without embedding)
    node = @ltm.add(
      content: content,
      speaker: speaker,
      robot_id: @robot.id,
      type: type,
      embedding: embedding,
      embedding_dimension: embedding&.length,
      **options
    )

    # Add to working memory
    @working_memory.add(node)

    node
  end
end
```

### Vector Search Behavior

```ruby
def vector_search(query_text:, limit: 10)
  # Generate query embedding
  query_embedding = @embedding_service.embed(query_text)

  # Search only nodes WITH embeddings
  HTM::Models::Node
    .where.not(embedding: nil)  # Exclude nodes without embeddings
    .order(Arel.sql("embedding <=> ?", query_embedding))
    .limit(limit)
end
```

---

## Embedding Update Strategies

### Strategy 1: Content Change Detection

```ruby
class HTM::Models::Node < ActiveRecord::Base
  before_update :regenerate_embedding_if_content_changed

  private

  def regenerate_embedding_if_content_changed
    if content_changed? && HTM.embedding_service
      new_embedding = HTM.embedding_service.embed(content)
      self.embedding = new_embedding
      self.embedding_dimension = new_embedding.length
    end
  end
end
```

**Trade-offs**:
- ✅ Automatic embedding regeneration on content change
- ❌ Embedding service must be globally accessible
- ❌ Adds latency to UPDATE operations

### Strategy 2: Explicit Re-Embedding

```ruby
class HTM
  def regenerate_embedding(node_id)
    node = HTM::Models::Node.find(node_id)
    embedding = @embedding_service.embed(node.content)

    node.update!(
      embedding: embedding,
      embedding_dimension: embedding.length
    )
  end

  def regenerate_all_embeddings
    HTM::Models::Node.find_each do |node|
      regenerate_embedding(node.id)
    end
  end
end
```

**Trade-offs**:
- ✅ Explicit control over when embeddings regenerate
- ✅ Can batch operations efficiently
- ❌ Manual intervention required

### Strategy 3: Background Job (Future)

```ruby
class EmbeddingRegenerationJob
  def perform(node_id)
    node = HTM::Models::Node.find(node_id)
    return if node.embedding.present?  # Skip if already has embedding

    embedding = HTM::EmbeddingService.new.embed(node.content)
    node.update!(
      embedding: embedding,
      embedding_dimension: embedding.length
    )
  end
end
```

**Trade-offs**:
- ✅ Non-blocking embedding generation
- ✅ Can retry failures automatically
- ❌ Requires background job infrastructure (Sidekiq, etc.)

**Current Decision**: Use **Strategy 2 (Explicit Re-Embedding)** for simplicity.

---

## Embedding Provider Configuration

### Ollama (Default)

```ruby
# Default configuration
embedding_service = HTM::EmbeddingService.new(:ollama)
# Uses:
# - Model: nomic-embed-text (768 dimensions)
# - URL: http://localhost:11434
# - Requires: Ollama running locally

# Custom configuration
embedding_service = HTM::EmbeddingService.new(
  :ollama,
  model: 'mxbai-embed-large',  # 1024 dimensions
  ollama_url: ENV['OLLAMA_URL']
)
```

**Requirements**:
- Ollama installed and running
- Model pulled: `ollama pull nomic-embed-text`
- Accessible at configured URL

### OpenAI

```ruby
# Configure OpenAI
embedding_service = HTM::EmbeddingService.new(
  :openai,
  model: 'text-embedding-3-small'  # 1536 dimensions
)
# Requires: ENV['OPENAI_API_KEY'] set
```

**Requirements**:
- `OPENAI_API_KEY` environment variable
- Internet connectivity
- API rate limits considered

---

## Consequences

### Positive

✅ **Simple and reliable**: Works consistently across all environments
✅ **Debuggable**: Errors occur in Ruby code with full stack traces
✅ **Flexible**: Easy to modify embedding logic without database changes
✅ **Testable**: Can mock EmbeddingService in tests
✅ **No extensions**: No PostgreSQL extension dependencies
✅ **Graceful degradation**: System works even if embeddings fail
✅ **Dimension flexibility**: Supports 1-2000 dimension embeddings

### Negative

❌ **Latency**: 50-100ms per embedding (vs. potential database-side optimization)
❌ **HTTP overhead**: Ruby → Ollama HTTP call for each embedding
❌ **Memory**: Embedding array held in Ruby memory before database insert
❌ **No automatic updates**: Embeddings not automatically regenerated on content change

### Neutral

➡️ **Provider coupling**: Application chooses provider, not database
➡️ **Connection management**: Ruby HTTP client handles connections
➡️ **Error visibility**: Failures visible in application logs, not database logs

---

## Performance Characteristics

### Benchmarks (M2 Mac, Ollama local, nomic-embed-text)

| Operation | Time | Notes |
|-----------|------|-------|
| Generate single embedding | ~50ms | HTTP round-trip to Ollama |
| Insert node with embedding | ~60ms | 50ms embed + 10ms INSERT |
| Batch 100 nodes | ~6s | ~60ms each (can optimize with connection reuse) |
| Vector search (10 results) | ~30ms | HNSW index efficient |

### Optimization Opportunities

**Connection Pooling**:
```ruby
# Reuse HTTP connection for multiple embeddings
Net::HTTP.start(uri.hostname, uri.port) do |http|
  nodes.each do |node|
    embedding = generate_embedding(http, node.content)
    insert_node(node, embedding)
  end
end
```

**Parallel Generation** (Future):
```ruby
# Generate embeddings in parallel for batch operations
threads = nodes.map do |node|
  Thread.new { [node, embedding_service.embed(node.content)] }
end

results = threads.map(&:value)  # [node, embedding] pairs
```

---

## Risks and Mitigations

### Risk: Ollama Service Down

**Risk**: Embedding generation fails if Ollama not running
- **Likelihood**: Medium (local development)
- **Impact**: Medium (nodes created without embeddings)
- **Mitigation**:
  - Graceful degradation (nodes still created)
  - Health check endpoint for Ollama
  - Clear error messages with troubleshooting steps
  - Background job retry for failed embeddings (future)

### Risk: API Rate Limits (OpenAI)

**Risk**: Hit rate limits with high-volume operations
- **Likelihood**: Medium (for OpenAI provider)
- **Impact**: Medium (batch operations fail)
- **Mitigation**:
  - Rate limiting in application layer
  - Exponential backoff retry logic
  - Prefer local Ollama for development
  - Batch API if available

### Risk: Dimension Mismatch

**Risk**: Model returns unexpected dimension count
- **Likelihood**: Low (models are consistent)
- **Impact**: High (database constraint violation)
- **Mitigation**:
  - Validate embedding dimensions before insert
  - Store actual dimension in `embedding_dimension` column
  - Raise clear error if dimension > 2000
  - Document supported models and dimensions

### Risk: Stale Embeddings

**Risk**: Content updated but embedding not regenerated
- **Likelihood**: Medium (manual updates)
- **Impact**: Low (search quality degrades slightly)
- **Mitigation**:
  - Document re-embedding procedures
  - Provide utility methods for bulk re-embedding
  - Consider ActiveRecord callback (future)
  - Track last embedding generation time (future)

---

## Future Enhancements

### 1. Automatic Re-Embedding on Content Change

```ruby
class HTM::Models::Node < ActiveRecord::Base
  after_update :regenerate_embedding, if: :content_changed?
end
```

### 2. Background Embedding Generation

```ruby
# Queue for asynchronous processing
EmbeddingGenerationJob.perform_later(node_id)
```

### 3. Embedding Caching

```ruby
class EmbeddingCache
  def get_or_generate(content)
    cache_key = Digest::SHA256.hexdigest(content)
    Rails.cache.fetch("embedding:#{cache_key}") do
      embedding_service.embed(content)
    end
  end
end
```

### 4. Batch Embedding Optimization

```ruby
# Generate multiple embeddings in single HTTP request
def embed_batch(texts)
  # Ollama doesn't support batch embedding yet
  # OpenAI supports batches
end
```

### 5. Embedding Versioning

```ruby
# Track which model/version generated embedding
class AddEmbeddingMetadataToNodes < ActiveRecord::Migration
  add_column :nodes, :embedding_model, :text
  add_column :nodes, :embedding_generated_at, :timestamptz
end
```

---

## Related ADRs

- [ADR-001: PostgreSQL Storage](./001-use-postgresql-timescaledb-storage.md) - Database foundation
- [ADR-003: Ollama as Default Embedding Provider](./003-ollama-default-embedding-provider.md) - Provider choice
- [ADR-005: RAG-Based Retrieval](./005-rag-based-retrieval-with-hybrid-search.md) - How embeddings are used
- [ADR-011: Database-Side Embedding (REVERSED)](./011-database-side-embedding-generation-with-pgai.md) - Previous approach

---

## Review Notes

**AI Engineer**: ✅ Client-side generation is pragmatic. Graceful degradation ensures reliability.

**Performance Specialist**: ✅ 50ms latency is acceptable for this use case. Local Ollama performs well.

**Ruby Expert**: ✅ Clear separation of concerns. EmbeddingService is well-designed.

**Systems Architect**: ✅ Synchronous generation simplifies architecture. Async can be added later if needed.

**Database Architect**: ✅ Storing embedding_dimension alongside embedding is smart for future flexibility.
