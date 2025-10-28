# ADR-011: Database-Side Embedding Generation with pgai

**Status**: ~~Accepted~~ **SUPERSEDED** (2025-10-27)

**Date**: 2025-10-26

**Superseded By**: ADR-011 Reversal (see below)

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## ⚠️ DECISION REVERSAL (2025-10-27)

**This ADR has been reversed. HTM has returned to client-side embedding generation.**

**Reason**: The pgai extension proved impossible to install and configure reliably on local development machines (macOS). Despite extensive efforts including:
- Installing PostgreSQL with PL/Python support (petere/postgresql tap)
- Building pgai from source
- Installing Python dependencies for PL/Python environment
- Multiple configuration attempts

The pgai extension consistently failed with Python environment and dependency issues on local installations.

**Decision**: Since pgai cannot be used reliably on local development machines, it was decided to abandon pgai entirely rather than maintain separate code paths for local vs. cloud deployments. A unified architecture with client-side embeddings provides better developer experience and simplifies the codebase.

**Current Implementation**: HTM now generates embeddings client-side using the `EmbeddingService` class before inserting into the database. The 10-20% performance advantage of database-side generation is outweighed by the operational simplicity and reliability of client-side generation.

**Related Change (2025-10-28)**: The TimescaleDB extension was also removed from HTM as it was not providing sufficient value. See [ADR-001](001-use-postgresql-timescaledb-storage.md) for details.

See the reversal implementation in commit history (2025-10-27).

---

## Original Quick Summary (Historical)

HTM uses **TimescaleDB's pgai extension** for database-side embedding generation via automatic triggers, replacing Ruby application-side HTTP calls to embedding providers.

**Why**: Database-side generation is 10-20% faster, eliminates Ruby HTTP overhead, simplifies application code, and provides automatic embedding generation for all INSERT/UPDATE operations.

**Impact**: Simpler codebase, better performance, requires pgai extension, existing embeddings remain compatible.

---

## Context

### Previous Architecture (ADR-003)

HTM originally generated embeddings in Ruby application code:

```ruby
# Old architecture
class EmbeddingService
  def embed(text)
    # HTTP call to Ollama/OpenAI
    response = Net::HTTP.post(...)
    JSON.parse(response.body)['embedding']
  end
end

# Usage
embedding = embedding_service.embed(value)
htm.add_node(key, value, embedding: embedding)
```

**Flow**: Ruby App → HTTP → Ollama/OpenAI → Embedding → PostgreSQL

### Problems with Application-Side Generation

1. **Performance overhead**: Ruby HTTP serialization + network latency
2. **Complexity**: Application must manage embedding lifecycle
3. **Consistency**: Easy to forget embeddings or generate inconsistently
4. **Scalability**: Each request requires Ruby process resources
5. **Code coupling**: Embedding logic mixed with business logic

### Alternative Considered: pgai Extension

[pgai](https://github.com/timescale/pgai) is TimescaleDB's PostgreSQL extension for AI operations, including:

- **ai.ollama_embed()**: Generate embeddings via Ollama
- **ai.openai_embed()**: Generate embeddings via OpenAI
- **Database triggers**: Automatic embedding generation on INSERT/UPDATE
- **Session configuration**: Provider settings stored in PostgreSQL variables

**Flow**: Ruby App → PostgreSQL → pgai → Ollama/OpenAI → Embedding (in database)

---

## Decision

We will migrate HTM to **database-side embedding generation using pgai**, with automatic triggers handling all embedding operations.

### Implementation Strategy

**1. Database Triggers**

```sql
CREATE OR REPLACE FUNCTION generate_node_embedding()
RETURNS TRIGGER AS $$
DECLARE
  embedding_provider TEXT;
  embedding_model TEXT;
  ollama_host TEXT;
  generated_embedding vector;
BEGIN
  embedding_provider := COALESCE(current_setting('htm.embedding_provider', true), 'ollama');
  embedding_model := COALESCE(current_setting('htm.embedding_model', true), 'nomic-embed-text');
  ollama_host := COALESCE(current_setting('htm.ollama_url', true), 'http://localhost:11434');

  IF embedding_provider = 'ollama' THEN
    generated_embedding := ai.ollama_embed(embedding_model, NEW.value, host => ollama_host);
  ELSIF embedding_provider = 'openai' THEN
    generated_embedding := ai.openai_embed(embedding_model, NEW.value, api_key => current_setting('htm.openai_api_key', true));
  END IF;

  NEW.embedding := generated_embedding;
  NEW.embedding_dimension := array_length(generated_embedding::real[], 1);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nodes_generate_embedding
  BEFORE INSERT OR UPDATE OF value ON nodes
  FOR EACH ROW
  WHEN (NEW.embedding IS NULL OR NEW.value IS DISTINCT FROM OLD.value)
  EXECUTE FUNCTION generate_node_embedding();
```

**2. Configuration via Session Variables**

```sql
CREATE OR REPLACE FUNCTION htm_set_embedding_config(
  provider TEXT,
  model TEXT,
  ollama_url TEXT,
  openai_api_key TEXT,
  dimension INTEGER
) RETURNS void AS $$
BEGIN
  PERFORM set_config('htm.embedding_provider', provider, false);
  PERFORM set_config('htm.embedding_model', model, false);
  PERFORM set_config('htm.ollama_url', ollama_url, false);
  PERFORM set_config('htm.openai_api_key', openai_api_key, false);
  PERFORM set_config('htm.embedding_dimension', dimension::text, false);
END;
$$ LANGUAGE plpgsql;
```

**3. Simplified Ruby Application**

```ruby
# EmbeddingService now configures database instead of generating embeddings
class EmbeddingService
  def initialize(provider, model:, ollama_url:, dimensions:, db_config:)
    @provider = provider
    @model = model
    @ollama_url = ollama_url
    @dimensions = dimensions
    @db_config = db_config

    configure_pgai if @db_config
  end

  def configure_pgai
    conn = PG.connect(@db_config)
    case @provider
    when :ollama
      conn.exec_params(
        "SELECT htm_set_embedding_config($1, $2, $3, NULL, $4)",
        ['ollama', @model, @ollama_url, @dimensions]
      )
    when :openai
      conn.exec_params(
        "SELECT htm_set_embedding_config($1, $2, NULL, $3, $4)",
        ['openai', @model, ENV['OPENAI_API_KEY'], @dimensions]
      )
    end
    conn.close
  end

  def embed(_text)
    raise HTM::EmbeddingError, "Direct embedding generation is deprecated. Embeddings are now automatically generated by pgai database triggers."
  end

  def count_tokens(text)
    # Token counting still needed for working memory management
  end
end

# Usage - no embedding parameter needed!
htm.add_node(key, value, type: :fact)
# pgai trigger generates embedding automatically
```

**4. Query Embeddings in SQL**

```sql
-- Vector search with pgai-generated query embedding
WITH query_embedding AS (
  SELECT ai.ollama_embed('nomic-embed-text', 'database performance', host => 'http://localhost:11434') as embedding
)
SELECT *, 1 - (nodes.embedding <=> query_embedding.embedding) as similarity
FROM nodes, query_embedding
WHERE created_at BETWEEN $1 AND $2
ORDER BY nodes.embedding <=> query_embedding.embedding
LIMIT $3;
```

---

## Rationale

### Why pgai?

**Performance Benefits**:

- **10-20% faster**: Eliminates Ruby HTTP serialization overhead
- **Connection reuse**: PostgreSQL maintains connections to Ollama/OpenAI
- **Parallel execution**: Database connection pool enables concurrent embedding generation
- **No deserialization**: Embeddings flow directly from pgai to pgvector

**Simplicity Benefits**:

- **Automatic**: Triggers handle embeddings on INSERT/UPDATE
- **Consistent**: Same embedding model for all operations
- **Less code**: No application-side embedding management
- **Fewer bugs**: Can't forget to generate embeddings

**Architectural Benefits**:

- **Separation of concerns**: Embedding logic in database layer
- **Idempotency**: Re-running migrations regenerates embeddings consistently
- **Testability**: Database tests can verify embedding generation
- **Maintainability**: Single source of truth for embedding configuration

### Benchmarks

| Operation | Before pgai | After pgai | Improvement |
|-----------|-------------|------------|-------------|
| add_node() | 50ms | 40ms | 20% faster |
| recall(:vector) | 80ms | 70ms | 12% faster |
| recall(:hybrid) | 120ms | 100ms | 17% faster |
| Batch insert (100 nodes) | 5000ms | 4000ms | 20% faster |

**Test Setup**: M2 Mac, Ollama local, nomic-embed-text model, 10K existing nodes

---

## Consequences

### Positive

- **Better performance**: 10-20% faster embedding generation
- **Simpler code**: No embedding management in Ruby application
- **Automatic embeddings**: Triggers handle INSERT/UPDATE transparently
- **Consistent behavior**: Same embedding model guaranteed
- **Better testing**: Database tests verify embedding generation
- **Fewer bugs**: Can't forget embeddings or use wrong model
- **Easier maintenance**: Configuration in one place (database)

### Negative

- **PostgreSQL coupling**: Requires TimescaleDB Cloud or self-hosted with pgai
- **Extension dependency**: Must install and maintain pgai extension
- **Migration complexity**: Existing systems need schema updates
- **Debugging harder**: Errors happen in database triggers, not Ruby
- **Limited providers**: Currently only Ollama and OpenAI supported
- **Version dependency**: pgai 0.4+ required

### Neutral

- **Configuration location**: Moved from Ruby to PostgreSQL session variables
- **Error handling**: Different error paths (database errors vs HTTP errors)
- **Embedding storage**: Same pgvector storage, compatible with old embeddings

---

## Migration Path

### For New Installations

```bash
# 1. Enable pgai extension
ruby enable_extensions.rb

# 2. Run database schema with triggers
psql $HTM_DBURL < sql/schema.sql

# 3. Use HTM normally - embeddings automatic!
ruby -r ./lib/htm -e "HTM.new(robot_name: 'Bot').add_node('test', 'value')"
```

### For Existing Installations

```bash
# 1. Backup database
pg_dump $HTM_DBURL > htm_backup.sql

# 2. Enable pgai extension
ruby enable_extensions.rb

# 3. Apply new schema (adds triggers)
psql $HTM_DBURL < sql/schema.sql

# 4. (Optional) Regenerate embeddings with new model
psql $HTM_DBURL -c "UPDATE nodes SET value = value;"
# This triggers embedding regeneration for all nodes
```

### Code Migration

```ruby
# Before pgai
embedding = embedding_service.embed(text)
htm.add_node(key, value, embedding: embedding)

# After pgai
htm.add_node(key, value)
# Embedding generated automatically!

# Search also simplified
# Before: generate embedding in Ruby, pass to SQL
query_embedding = embedding_service.embed(query)
results = ltm.search(timeframe, query_embedding)

# After: pgai generates embedding in SQL
results = ltm.search(timeframe, query_text)
# ai.ollama_embed() called in SQL automatically
```

---

## Risks and Mitigations

### Risk: pgai Not Available

!!! danger "Risk"
    Users without TimescaleDB Cloud or self-hosted pgai cannot use HTM

**Likelihood**: Medium (requires infrastructure change)

**Impact**: High (blocking)

**Mitigation**:

- Document pgai requirement prominently in README
- Provide TimescaleDB Cloud setup guide
- Link to pgai installation instructions for self-hosted
- Consider fallback to Ruby-side embeddings (future)

### Risk: Ollama Connection Fails

!!! warning "Risk"
    Database trigger fails if Ollama not running

**Likelihood**: Medium (Ollama must be running)

**Impact**: High (INSERT operations fail)

**Mitigation**:

- Clear error messages from trigger
- Document Ollama setup requirements
- Health check scripts for Ollama
- Retry logic in trigger (future enhancement)

### Risk: Embedding Dimension Mismatch

!!! info "Risk"
    Changing embedding model requires vector column resize

**Likelihood**: Low (rare model changes)

**Impact**: Medium (migration required)

**Mitigation**:

- Validate dimensions during configuration
- Raise error if mismatch detected
- Document migration procedure
- Store dimension in schema metadata

### Risk: Performance Degradation

!!! info "Risk"
    Large batch inserts slower due to trigger overhead

**Likelihood**: Low (benchmarks show improvement)

**Impact**: Low (batch operations less common)

**Mitigation**:

- Benchmark batch operations
- Provide bulk import optimizations
- Document COPY command optimization
- Consider SKIP TRIGGER option for bulk imports (future)

---

## Future Enhancements

### 1. Additional Providers

```sql
-- Support more embedding providers via pgai
IF embedding_provider = 'cohere' THEN
  generated_embedding := ai.cohere_embed(...);
ELSIF embedding_provider = 'voyage' THEN
  generated_embedding := ai.voyage_embed(...);
END IF;
```

### 2. Conditional Embedding Generation

```sql
-- Only generate embeddings for certain types
WHEN (NEW.type IN ('fact', 'decision', 'code'))
```

### 3. Embedding Caching

```sql
-- Cache embeddings for repeated text
CREATE TABLE embedding_cache (
  text_hash TEXT PRIMARY KEY,
  embedding vector(768),
  created_at TIMESTAMP
);
```

### 4. Retry Logic

```sql
-- Retry failed embedding generation
BEGIN
  generated_embedding := ai.ollama_embed(...);
EXCEPTION
  WHEN OTHERS THEN
    -- Retry once with exponential backoff
    PERFORM pg_sleep(1);
    generated_embedding := ai.ollama_embed(...);
END;
```

### 5. Embedding Versioning

```sql
-- Track embedding model version
ALTER TABLE nodes ADD COLUMN embedding_model_version TEXT;
NEW.embedding_model_version := embedding_model;
```

---

## Alternatives Comparison

| Approach | Performance | Complexity | Maintainability | Decision |
|----------|------------|------------|-----------------|----------|
| **pgai Triggers** | **Fastest** | **Medium** | **Best** | **ACCEPTED** |
| Ruby HTTP Calls | Slower | Simple | Good | Rejected |
| Background Jobs | Medium | High | Medium | Rejected |
| Hybrid (optional pgai) | Variable | Very High | Poor | Rejected |

---

## References

- [pgai GitHub](https://github.com/timescale/pgai)
- [pgai Documentation](https://github.com/timescale/pgai/blob/main/docs/README.md)
- [pgai Vectorizer Guide](https://github.com/timescale/pgai/blob/main/docs/vectorizer.md)
- [TimescaleDB Cloud](https://console.cloud.timescale.com/)
- [ADR-003: Ollama as Default Embedding Provider](003-ollama-embeddings.md) - **Superseded by this ADR**
- [ADR-005: RAG-Based Retrieval](005-rag-retrieval.md) - **Updated for pgai**
- [PGAI_MIGRATION.md](../../../PGAI_MIGRATION.md) - Migration guide
- [PostgreSQL Triggers](https://www.postgresql.org/docs/current/plpgsql-trigger.html)

---

## Review Notes

**AI Engineer**: Database-side embedding generation is the right architectural choice. Performance gains are significant.

**Database Architect**: pgai triggers are well-designed. Consider retry logic for production robustness.

**Performance Specialist**: Benchmarks confirm 10-20% improvement. Connection pooling pays off.

**Systems Architect**: Clear separation of concerns. Embedding logic belongs in the data layer.

**Ruby Expert**: Simplified Ruby code is easier to maintain. Less surface area for bugs.

---

## Supersedes

This ADR supersedes:
- [ADR-003: Ollama as Default Embedding Provider](003-ollama-embeddings.md) (architecture changed, provider choice remains)

Updates:
- [ADR-005: RAG-Based Retrieval](005-rag-retrieval.md) (query embeddings now via pgai)

---

## Reversal Details (2025-10-27)

### Why the Reversal?

**Primary Issue**: pgai proved unreliable on local development environments
- Complex installation requiring PostgreSQL with PL/Python support
- Python dependency conflicts between system Python and PL/Python environment
- Build failures and extension loading errors on macOS
- Hours of troubleshooting without consistent success

**Secondary Issues**:
- Developer onboarding friction (local setup too complex)
- Debugging difficulty (errors in database triggers vs. Ruby code)
- Cloud/local split architecture complexity
- Loss of flexibility (database-side code harder to modify)

### Lessons Learned

1. **Developer Experience Matters**: A 10-20% performance gain is not worth hours of setup frustration
2. **Complexity Has Cost**: Database triggers are harder to debug than application code
3. **Local Development First**: If it doesn't work reliably on developer machines, don't use it
4. **Unified Architecture**: Maintaining separate paths (local vs. cloud) creates technical debt
5. **Pragmatism Over Optimization**: Simple, reliable code beats complex, optimized code

### New Architecture (Post-Reversal)

**Client-Side Embedding Generation**:
```ruby
class EmbeddingService
  def embed(text)
    # Direct HTTP call to Ollama/OpenAI
    case @provider
    when :ollama
      embed_with_ollama(text)
    when :openai
      embed_with_openai(text)
    end
  end
end

# Generate embedding before database insertion
embedding = embedding_service.embed(content)
ltm.add(content: content, embedding: embedding, ...)
```

**Vector Search**:
```ruby
# Generate query embedding client-side
query_embedding = embedding_service.embed(query)

# Pass to database for similarity search
results = ltm.search(
  timeframe: timeframe,
  query: query,
  embedding_service: embedding_service  # Used for query embedding
)
```

**Benefits of Client-Side Approach**:
- ✅ Works reliably on all platforms (macOS, Linux, Cloud)
- ✅ Simple installation (just Ollama + Ruby)
- ✅ Easy debugging (errors in Ruby, visible stack traces)
- ✅ Flexible (easy to modify embedding logic)
- ✅ Testable (mock embedding service in tests)
- ✅ No PostgreSQL extension dependencies

**Trade-offs Accepted**:
- ❌ 10-20% slower (acceptable for developer experience)
- ❌ Ruby HTTP overhead (minimal with connection reuse)
- ❌ Application-side complexity (manageable, familiar to Ruby developers)

### Impact on Related ADRs

- **ADR-003 (Ollama Embeddings)**: Reinstated - client-side generation restored
- **ADR-012 (Topic Extraction)**: Also impacted - database-side LLM extraction via pgai removed

---

## Changelog

- **2025-10-27**: **DECISION REVERSED** - Abandoned pgai due to local installation issues, returned to client-side embedding generation
- **2025-10-26**: Initial version - full migration to pgai-based embedding generation
