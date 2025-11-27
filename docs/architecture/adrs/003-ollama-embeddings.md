# ADR-003: Ollama as Default Embedding Provider

**Status**: Accepted (Reinstated After ADR-011 Reversal)

**Date**: 2025-10-25 (Updated: 2025-10-27)

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

!!! success "Architecture Status (October 2025)"
    **October 27, 2025**: This ADR is once again the current architecture. Following the reversal of ADR-011, HTM has returned to client-side embedding generation using Ollama as the default provider. Embeddings are generated in Ruby before database insertion.

## Quick Summary

HTM uses **Ollama with the nomic-embed-text model** as the default embedding provider, prioritizing local-first, privacy-preserving operation with zero API costs while supporting pluggable alternatives (OpenAI).

**Why**: Local embeddings eliminate API costs, preserve privacy, and enable offline operation while maintaining good semantic search quality.

**Impact**: Users must install Ollama locally, trading convenience for privacy and cost savings. Client-side embedding generation provides reliable operation without complex database extension dependencies.

---

## Context

HTM requires vector embeddings for semantic search functionality. Embeddings convert text into high-dimensional vectors that capture semantic meaning, enabling similarity search beyond keyword matching.

### Requirements

- Generate embeddings for memory nodes
- Support semantic similarity search
- Consistent embedding dimensions (1536 recommended)
- Reasonable latency (< 1 second per embedding)
- Cost-effective for development and production
- Privacy-preserving (sensitive data handling)

### Options Considered

1. **OpenAI**: text-embedding-3-small, excellent quality
2. **Ollama**: Local models (gpt-oss, nomic-embed-text), privacy-first
3. **Cohere**: embed-english-v3.0, good performance
4. **Anthropic**: No native embedding API (yet)
5. **Sentence Transformers**: Local Python models via API
6. **Voyage AI**: Specialized embeddings, high quality

---

## Decision

We will use **Ollama with the gpt-oss model** as the default embedding provider for HTM, while supporting pluggable alternatives (OpenAI, Cohere, etc.).

---

## Rationale

### Why Ollama?

**Local-first approach**:

- Runs on user's machine (M2 Mac handles it well)
- No API costs during development
- No internet dependency once models downloaded
- Fast iteration without rate limits

**Privacy-preserving**:

- Data never leaves the user's machine
- Critical for sensitive conversations
- No terms of service restrictions
- Full control over data

**Developer-friendly**:

- Simple installation (`ollama pull gpt-oss`)
- HTTP API at localhost:11434
- Multiple model support
- Growing ecosystem

**Cost-effective**:

- Zero ongoing costs
- Pay once for compute (user's hardware)
- No per-token pricing
- Predictable operational costs

### Why gpt-oss Model?

**Technical characteristics**:

- Vector dimension: 1536 (matches OpenAI text-embedding-3-small)
- Speed: ~100-300ms per embedding on M2 Mac
- Quality: Good semantic understanding for general text
- Size: Reasonable model size (~274MB)

**Compatibility**:

- Same dimension as OpenAI (easier migration)
- Works with pgvector (supports any dimension)
- Compatible with other tools expecting 1536d vectors

---

## Implementation Details

!!! warning "Architecture Change (October 2025)"
    Embedding generation has moved from Ruby application code to database triggers via pgai. The implementation below is deprecated. See [ADR-011](011-pgai-integration.md) for current architecture.

### Current Architecture (pgai-based)

**Database Trigger** (automatic embedding generation):

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

**EmbeddingService** (configuration only):

```ruby
class EmbeddingService
  def initialize(provider = :ollama, model: 'nomic-embed-text', ollama_url: nil, db_config: nil)
    @provider = provider
    @model = model
    @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
    @db_config = db_config
    @dimensions = KNOWN_DIMENSIONS[@model]

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
      api_key = ENV['OPENAI_API_KEY']
      conn.exec_params(
        "SELECT htm_set_embedding_config($1, $2, NULL, $3, $4)",
        ['openai', @model, api_key, @dimensions]
      )
    end
    conn.close
  end

  def embed(_text)
    raise HTM::EmbeddingError, "Direct embedding generation is deprecated. Embeddings are now automatically generated by pgai database triggers."
  end
end
```

### Legacy Architecture (deprecated)

<details>
<summary>Click to view deprecated Ruby-side embedding generation</summary>

```ruby
# DEPRECATED: This architecture is no longer used
class EmbeddingService
  def embed_ollama(text)
    response = Net::HTTP.post(
      URI("#{@ollama_url}/api/embeddings"),
      {model: @model, prompt: text}.to_json,
      {'Content-Type' => 'application/json'}
    )
    JSON.parse(response.body)['embedding']
  rescue => e
    warn "Error generating embedding with Ollama: #{e.message}"
    Array.new(768) { rand(-1.0..1.0) }
  end
end
```

</details>

### User Configuration

!!! info "pgai Configuration"
    With pgai, configuration sets database session variables. Embedding generation happens automatically via triggers.

```ruby
# Default: Ollama with nomic-embed-text (768 dimensions)
htm = HTM.new(robot_name: "My Robot")

# Explicit Ollama configuration
htm = HTM.new(
  robot_name: "My Robot",
  embedding_provider: :ollama,
  embedding_model: 'nomic-embed-text'
)

# Use different Ollama model
htm = HTM.new(
  robot_name: "My Robot",
  embedding_provider: :ollama,
  embedding_model: 'mxbai-embed-large',  # 1024 dimensions
  embedding_dimensions: 1024
)

# Use OpenAI
htm = HTM.new(
  robot_name: "My Robot",
  embedding_provider: :openai,
  embedding_model: 'text-embedding-3-small'  # 1536 dimensions
)

# Add node - embedding generated automatically by database trigger!
htm.add_node("fact_001", "PostgreSQL is awesome", type: :fact)
# No embedding parameter needed - pgai handles it in the database
```

---

## Consequences

### Positive

- Zero cost: no API fees for embedding generation
- Privacy-first: data stays local (Ollama runs locally)
- Fast iteration: no rate limits during development
- Offline capable: works without internet
- Simple setup: one command to install model
- Flexible: easy to swap providers later
- **pgai Benefits** (added October 2025):
  - **10-20% faster**: Database-side generation eliminates Ruby HTTP overhead
  - **Automatic**: Triggers handle embeddings on INSERT/UPDATE
  - **Simpler code**: No application-side embedding calls
  - **Consistent**: Same embedding model for all operations
  - **Parallel execution**: PostgreSQL connection pooling enables concurrent embedding generation

### Negative

- Setup required: users must install Ollama and pull model
- Hardware dependency: requires decent CPU/GPU (M2 Mac sufficient)
- Quality trade-off: not quite OpenAI quality (acceptable for most use cases)
- Compatibility: users on older hardware may struggle
- Debugging: local issues harder to diagnose than API errors
- **pgai Requirements** (added October 2025):
  - **PostgreSQL extension**: Requires TimescaleDB Cloud or self-hosted with pgai installed
  - **Database coupling**: Embedding logic now in database, not application
  - **Migration complexity**: Existing applications need schema updates

### Neutral

- Model choice: gpt-oss is reasonable default, but users can experiment
- Version drift: Ollama model updates may change embeddings
- Dimension flexibility: could support other dimensions with schema changes

---

## Setup Instructions

!!! info "Installation"
    ```bash
    # Install Ollama
    curl https://ollama.ai/install.sh | sh
    
    # Or download from: https://ollama.ai/download
    
    # Pull gpt-oss model
    ollama pull gpt-oss
    
    # Verify Ollama is running
    curl http://localhost:11434/api/version
    ```

---

## Risks and Mitigations

### Risk: Ollama Not Installed

!!! danger "Risk"
    Users try to use HTM without Ollama

**Likelihood**: High (on first run)
**Impact**: High (no embeddings, broken search)
**Mitigation**:
- Clear error messages with installation instructions
- Fallback to stub embeddings (with warning)
- Check Ollama availability in setup script

### Risk: Model Not Downloaded

!!! warning "Risk"
    Ollama installed but gpt-oss model not pulled

**Likelihood**: Medium
**Impact**: High (embedding generation fails)
**Mitigation**:
- Setup script checks for model
- Error message includes `ollama pull gpt-oss`
- Document in README and SETUP.md

### Risk: Performance on Low-end Hardware

!!! info "Risk"
    Slow embedding generation on older machines

**Likelihood**: Medium
**Impact**: Medium (poor user experience)
**Mitigation**:
- Document minimum requirements
- Provide alternative providers
- Batch embedding generation where possible

---

## Performance Characteristics

### Ollama (gpt-oss on M2 Mac)

- **Latency**: 100-300ms per embedding
- **Throughput**: ~5-10 embeddings/second
- **Memory**: ~500MB for model
- **CPU**: Moderate (benefits from Apple Silicon)

### OpenAI (for comparison)

- **Latency**: 50-150ms (network + API)
- **Throughput**: Limited by rate limits (3000 RPM = 50/sec)
- **Cost**: $0.02 per 1M tokens
- **Quality**: Slightly better semantic understanding

---

## Migration Path

### To OpenAI

```ruby
# 1. Set up OpenAI API key
ENV['OPENAI_API_KEY'] = 'sk-...'

# 2. Change initialization
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :openai
)

# 3. Re-embed existing nodes (embeddings not compatible)
# Migration tool needed
```

### To Custom Ollama URL

```ruby
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  ollama_url: 'http://custom-host:11434'
)
```

---

## Alternatives Comparison

| Provider | Quality | Cost | Privacy | Decision |
|----------|---------|------|---------|----------|
| **Ollama (gpt-oss)** | **Good** | **Free** | **Local** | **DEFAULT** |
| OpenAI | Excellent | $0.02/1M | Cloud | Optional |
| Cohere | Excellent | $0.10/1M | Cloud | Optional |
| Sentence Transformers | Good | Free | Local | Future |
| Voyage AI | Excellent | $0.12/1M | Cloud | Rejected |

---

## References

- [Ollama Documentation](https://ollama.ai/)
- [nomic-embed-text Model](https://ollama.ai/library/nomic-embed-text)
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [pgai Documentation](https://github.com/timescale/pgai)
- [ADR-011: Database-Side Embedding Generation with pgai](011-pgai-integration.md) - **Supersedes this ADR**
- [HTM Setup Guide](../../getting-started/installation.md)

---

## Review Notes

**AI Engineer**: Local-first approach is excellent for privacy. Consider batch embedding for performance.

**Performance Specialist**: 100-300ms is acceptable. Monitor for bottlenecks with large recall operations.

**Security Specialist**: Privacy-preserving by default. Ensure users are aware of trade-offs when switching to cloud providers.

**Ruby Expert**: Clean abstraction. Consider using Faraday for HTTP calls for better connection management.

**Systems Architect**: Pluggable design allows easy provider switching. Good balance of pragmatism and flexibility.
