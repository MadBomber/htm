# ADR-005: RAG-Based Retrieval with Hybrid Search

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

## Context

Traditional memory systems for LLMs face challenges in retrieving relevant information:

- **Keyword-only search**: Misses semantic relationships ("car" vs "automobile")
- **Vector-only search**: May miss exact keyword matches ("PostgreSQL 17.2" vs "database")
- **No temporal context**: Doesn't leverage time-based relevance
- **Scalability**: Simple linear scans don't scale to thousands of memories

HTM needs intelligent retrieval that balances:

- Semantic understanding (what does the query mean?)
- Keyword precision (exact term matching)
- Temporal relevance (recent vs historical context)
- Performance (fast retrieval from large datasets)

Alternative approaches:

1. **Pure vector search**: Semantic only, no keyword precision
2. **Pure full-text search**: Keywords only, no semantic understanding
3. **Hybrid search**: Combine vector + full-text + temporal filtering
4. **LLM-as-retriever**: Use LLM to generate retrieval queries (slow, expensive)

## Decision

We will implement **RAG-based retrieval with three search strategies**: vector, full-text, and hybrid, all with temporal filtering.

### Search Strategies

**1. Vector Search (`:vector`)**

- Generate embedding for query
- Compute cosine similarity with stored embeddings
- Temporal filtering on timeframe
- Best for: Semantic queries, conceptual relationships

**2. Full-Text Search (`:fulltext`)**

- PostgreSQL `to_tsvector` and `plainto_tsquery`
- `ts_rank` scoring for relevance
- Temporal filtering on timeframe
- Best for: Exact keywords, technical terms, proper nouns

**3. Hybrid Search (`:hybrid`)**

- Full-text pre-filter to get candidates (top 100)
- Vector reranking of candidates for semantic relevance
- Temporal filtering on timeframe
- Best for: Balanced retrieval with precision + recall

### Default Strategy

**Hybrid** is recommended for most use cases as it provides the best balance of semantic understanding and keyword precision.

## Rationale

### Why RAG-Based Retrieval?

**Temporal filtering is foundational**:

- "What did we discuss last week?" - time is the primary filter
- Recent context often more relevant than old context
- TimescaleDB optimized for time-range queries

**Semantic search handles synonyms**:

- User says "database", finds memories about "PostgreSQL"
- "Bug fix" matches "resolved issue"
- Captures conceptual relationships

**Full-text handles precision**:

- "PostgreSQL 17.2" needs exact version match
- Technical terminology like "pgvector", "HNSW"
- Proper nouns like robot names, project names

**Hybrid combines strengths**:

- Pre-filter with keywords reduces vector search space
- Vector reranking improves relevance of keyword matches
- Avoids false positives from pure vector search
- Avoids missing results from pure keyword search

### Implementation Details

```ruby
# Vector search
def search(timeframe:, query:, limit:, embedding_service:)
  query_embedding = embedding_service.embed(query)

  SELECT *, 1 - (embedding <=> $1::vector) as similarity
  FROM nodes
  WHERE created_at BETWEEN $2 AND $3
  ORDER BY embedding <=> $1::vector
  LIMIT $4
end
```

```ruby
# Full-text search
def search_fulltext(timeframe:, query:, limit:)
  SELECT *, ts_rank(to_tsvector('english', value), plainto_tsquery('english', $1)) as rank
  FROM nodes
  WHERE created_at BETWEEN $2 AND $3
  AND to_tsvector('english', value) @@ plainto_tsquery('english', $1)
  ORDER BY rank DESC
  LIMIT $4
end
```

```ruby
# Hybrid search
def search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100)
  query_embedding = embedding_service.embed(query)

  WITH candidates AS (
    SELECT *
    FROM nodes
    WHERE created_at BETWEEN $2 AND $3
    AND to_tsvector('english', value) @@ plainto_tsquery('english', $1)
    LIMIT $5  -- Pre-filter to 100 candidates
  )
  SELECT *, 1 - (embedding <=> $4::vector) as similarity
  FROM candidates
  ORDER BY embedding <=> $4::vector
  LIMIT $6  -- Final top results
end
```

### User API

```ruby
# Use hybrid search (recommended)
memories = htm.recall(
  timeframe: "last week",
  topic: "PostgreSQL performance",
  limit: 20,
  strategy: :hybrid  # default recommended
)

# Use pure vector search
memories = htm.recall(
  timeframe: "last month",
  topic: "database design philosophy",
  strategy: :vector  # best for conceptual queries
)

# Use pure full-text search
memories = htm.recall(
  timeframe: "yesterday",
  topic: "PostgreSQL 17.2 upgrade",
  strategy: :fulltext  # best for exact keywords
)
```

## Consequences

### Positive

✅ **Flexible retrieval**: Choose strategy based on query type
✅ **Temporal context**: Time-range filtering built into all strategies
✅ **Semantic understanding**: Vector search captures relationships
✅ **Keyword precision**: Full-text search handles exact matches
✅ **Balanced hybrid**: Best of both worlds with pre-filter optimization
✅ **Scalable**: HNSW indexing on vectors, GIN indexing on tsvectors
✅ **Transparent scoring**: Return similarity/rank scores for debugging

### Negative

❌ **Complexity**: Three strategies to understand and choose from
❌ **Embedding latency**: Vector/hybrid require embedding generation
❌ **Storage overhead**: Both embeddings and full-text indexes
❌ **English-only**: Full-text optimized for English language
❌ **Tuning required**: Hybrid prefilter_limit may need adjustment

### Neutral

➡️ **Strategy selection**: User must choose appropriate strategy
➡️ **Timeframe parsing**: Natural language time parsing adds complexity
➡️ **Embedding consistency**: Different embedding models produce different results

## Design Decisions

### Decision: Three Strategies Instead of One
**Rationale**: Different queries benefit from different approaches. Give users flexibility.

**Alternative**: Single hybrid strategy for all queries
**Rejected**: Forces hybrid approach even when pure vector or full-text is better

### Decision: Temporal Filtering is Mandatory
**Rationale**: HTM is time-oriented. All retrieval should consider temporal context.

**Alternative**: Optional timeframe parameter
**Rejected**: Easy to forget, defeats TimescaleDB optimization benefits

### Decision: Hybrid Pre-filter Limit = 100
**Rationale**: Balances recall (enough candidates) with performance (vector search cost)

**Alternative**: Dynamic limit based on result count
**Deferred**: Can optimize later based on real-world usage patterns

### Decision: Return Similarity/Rank Scores
**Rationale**: Enables debugging, threshold filtering, and understanding retrieval quality

**Alternative**: Just return nodes without scores
**Rejected**: Lose valuable signal for debugging and optimization

## Use Cases

### Use Case 1: Semantic Concept Retrieval
```ruby
# Query: "What architectural decisions have we made?"
# Best strategy: :vector (semantic concept matching)

memories = htm.recall(
  timeframe: "last month",
  topic: "architectural decisions design choices",
  strategy: :vector
)

# Finds: "We decided to use PostgreSQL", "Chose two-tier memory model", etc.
# Matches conceptually even without exact keywords
```

### Use Case 2: Exact Technical Term
```ruby
# Query: "Find all mentions of PostgreSQL 17.2"
# Best strategy: :fulltext (exact version number)

memories = htm.recall(
  timeframe: "this week",
  topic: "PostgreSQL 17.2",
  strategy: :fulltext
)

# Finds: Exact "PostgreSQL 17.2" mentions
# Avoids false matches to "PostgreSQL 16" or generic "database"
```

### Use Case 3: Balanced Query
```ruby
# Query: "What did we discuss about database performance?"
# Best strategy: :hybrid (keyword + semantic)

memories = htm.recall(
  timeframe: "last week",
  topic: "database performance optimization",
  strategy: :hybrid
)

# Pre-filters: Documents containing "database", "performance", "optimization"
# Reranks: By semantic similarity to full query
# Result: Best balance of precision + recall
```

### Use Case 4: Conversation Timeline
```ruby
# Get chronological conversation about a topic
timeline = htm.conversation_timeline("HTM design", limit: 50)

# Returns memories sorted by created_at
# Useful for replaying decision evolution over time
```

## Performance Characteristics

### Vector Search

- **Latency**: ~10-50ms for embedding generation + index lookup
- **Index**: HNSW (Hierarchical Navigable Small World)
- **Scalability**: O(log n) with HNSW, sublinear
- **Best case**: Conceptual queries, semantic relationships

### Full-Text Search

- **Latency**: ~5-20ms (no embedding generation)
- **Index**: GIN (Generalized Inverted Index) on tsvector
- **Scalability**: O(log n) with GIN index
- **Best case**: Exact keywords, technical terms

### Hybrid Search

- **Latency**: Full-text pre-filter + vector reranking
- **Total**: ~15-70ms (faster than pure vector on large datasets)
- **Optimization**: Pre-filter reduces vector search space
- **Best case**: Large datasets where full-text can narrow candidates

### Temporal Filtering

- **Optimization**: TimescaleDB hypertable partitioning by time
- **Index**: B-tree on `created_at` column
- **Benefit**: Prunes partitions outside timeframe, faster scans

## Risks and Mitigations

### Risk: Wrong Strategy Selection

- **Risk**: User chooses vector for exact keyword query (poor results)
- **Likelihood**: Medium (requires understanding differences)
- **Impact**: Medium (degraded retrieval quality)
- **Mitigation**:
  - Default to hybrid for balanced results
  - Document use cases clearly
  - Provide examples in API docs
  - Consider auto-detection in future

### Risk: Embedding Latency

- **Risk**: Vector/hybrid slow due to embedding generation
- **Likelihood**: High (embedding is I/O bound)
- **Impact**: Medium (100-500ms for Ollama)
- **Mitigation**:
  - Cache embeddings for common queries (future)
  - Use fast local embedding models (gpt-oss)
  - Provide fallback to full-text if embedding fails

### Risk: Language Limitation

- **Risk**: Full-text search optimized for English only
- **Likelihood**: Low (single-user, likely English)
- **Impact**: High (non-English users)
- **Mitigation**:
  - Document English assumption
  - Support language parameter in future
  - Vector search language-agnostic (works for all languages)

### Risk: Pre-filter Misses Results

- **Risk**: Hybrid pre-filter (100) misses relevant candidates
- **Likelihood**: Low (100 is generous)
- **Impact**: Medium (reduced recall)
- **Mitigation**:
  - Make prefilter_limit configurable
  - Monitor recall metrics in practice
  - Adjust default if needed

## Future Enhancements

### Query Auto-Detection
```ruby
# Automatically choose strategy based on query
htm.recall_smart(timeframe: "last week", topic: "PostgreSQL 17.2")
# Detects version number → uses :fulltext

htm.recall_smart(timeframe: "last month", topic: "architectural philosophy")
# Detects conceptual query → uses :vector
```

### Re-ranking Strategies
```ruby
# Custom re-ranking based on multiple signals
memories = htm.recall(
  timeframe: "last week",
  topic: "PostgreSQL",
  strategy: :hybrid,
  rerank: [:similarity, :importance, :recency]  # Multi-factor scoring
)
```

### Query Expansion
```ruby
# LLM-powered query expansion
original = "database"
expanded = ["database", "PostgreSQL", "TimescaleDB", "SQL", "storage"]

memories = htm.recall(
  timeframe: "last month",
  topic: expanded,
  strategy: :fulltext
)
```

### Caching Layer
```ruby
# Cache embedding generation for common queries
@embedding_cache = {}

def search_cached(query)
  @embedding_cache[query] ||= embedding_service.embed(query)
end
```

## Alternatives Considered

### Pure Vector Search Only
**Pros**: Simplest API, semantic by default
**Cons**: Misses exact keyword matches, slower on large datasets
**Decision**: ❌ Rejected - need keyword precision

### Pure Full-Text Only
**Pros**: Fast, no embedding overhead
**Cons**: No semantic understanding, synonym issues
**Decision**: ❌ Rejected - semantic understanding essential for LLMs

### LLM-as-Retriever
**Pros**: Most flexible, natural language queries
**Cons**: Expensive, slow, requires online LLM
**Decision**: ❌ Rejected - too slow and expensive for retrieval path

### Elasticsearch/Meilisearch
**Pros**: Dedicated search engines, advanced features
**Cons**: Additional infrastructure, complexity, cost
**Decision**: ❌ Rejected - PostgreSQL sufficient for v1, consolidation benefits

## References

- [RAG (Retrieval-Augmented Generation)](https://arxiv.org/abs/2005.11401)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [HNSW Algorithm](https://arxiv.org/abs/1603.09320)
- [Hybrid Search Best Practices](https://www.pinecone.io/learn/hybrid-search-intro/)

## Review Notes

**AI Engineer**: ✅ Hybrid search is the right approach for RAG systems. Pre-filter optimization is smart.

**Database Architect**: ✅ TimescaleDB + pgvector + full-text is well-architected. Consider query plan analysis for optimization.

**Performance Specialist**: ✅ HNSW and GIN indexes will scale. Monitor embedding latency in production.

**Systems Architect**: ✅ Three strategies provide good flexibility. Document decision matrix clearly for users.

**Ruby Expert**: ✅ Clean API design. Consider strategy as default parameter: `recall(..., strategy: :hybrid)`
