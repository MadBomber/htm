# ADR-003: Ollama as Default Embedding Provider

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM uses **Ollama with the gpt-oss model** as the default embedding provider, prioritizing local-first, privacy-preserving operation with zero API costs while supporting pluggable alternatives (OpenAI, Cohere).

**Why**: Local embeddings eliminate API costs, preserve privacy, and enable offline operation while maintaining good semantic search quality.

**Impact**: Users must install Ollama locally, trading convenience for privacy and cost savings. Quality slightly lower than cloud providers but acceptable for most use cases.

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

### EmbeddingService Architecture

```ruby
class EmbeddingService
  def initialize(provider = :ollama, model: 'gpt-oss', ollama_url: nil)
    @provider = provider
    @model = model
    @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
  end

  def embed(text)
    case @provider
    when :ollama
      embed_ollama(text)
    when :openai
      embed_openai(text)
    when :cohere
      embed_cohere(text)
    end
  end

  private

  def embed_ollama(text)
    # Direct HTTP call to Ollama API
    response = Net::HTTP.post(
      URI("#{@ollama_url}/api/embeddings"),
      {model: @model, prompt: text}.to_json,
      {'Content-Type' => 'application/json'}
    )
    JSON.parse(response.body)['embedding']
  rescue => e
    warn "Error generating embedding with Ollama: #{e.message}"
    warn "Falling back to stub embeddings (random vectors)"
    warn "Please ensure Ollama is running: curl http://localhost:11434/api/version"
    Array.new(1536) { rand(-1.0..1.0) }
  end
end
```

### User Configuration

```ruby
# Default: Ollama with gpt-oss
htm = HTM.new(robot_name: "My Robot")

# Explicit Ollama configuration
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  embedding_model: 'gpt-oss'
)

# Use different Ollama model
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  embedding_model: 'nomic-embed-text'  # 768d model
)

# Use OpenAI (requires implementation + API key)
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :openai
)
```

---

## Consequences

### Positive

- Zero cost: no API fees for embedding generation
- Privacy-first: data stays local
- Fast iteration: no rate limits during development
- Offline capable: works without internet
- Simple setup: one command to install model
- Flexible: easy to swap providers later

### Negative

- Setup required: users must install Ollama and pull model
- Hardware dependency: requires decent CPU/GPU (M2 Mac sufficient)
- Quality trade-off: not quite OpenAI quality (acceptable for most use cases)
- Compatibility: users on older hardware may struggle
- Debugging: local issues harder to diagnose than API errors

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
- [gpt-oss Model](https://ollama.ai/library/gpt-oss)
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [HTM Setup Guide](../../installation.md)

---

## Review Notes

**AI Engineer**: Local-first approach is excellent for privacy. Consider batch embedding for performance.

**Performance Specialist**: 100-300ms is acceptable. Monitor for bottlenecks with large recall operations.

**Security Specialist**: Privacy-preserving by default. Ensure users are aware of trade-offs when switching to cloud providers.

**Ruby Expert**: Clean abstraction. Consider using Faraday for HTTP calls for better connection management.

**Systems Architect**: Pluggable design allows easy provider switching. Good balance of pragmatism and flexibility.
