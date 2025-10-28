# ADR-002: Two-Tier Memory Architecture

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## ⚠️ UPDATE (2025-10-28)

**References to TimescaleDB in this ADR are now historical.**

After initial struggles with database configuration, the decision was made to drop the TimescaleDB extension as it was not providing sufficient value for the current proof-of-concept applications. The two-tier architecture remains unchanged, but long-term memory now uses **standard PostgreSQL** instead of PostgreSQL + TimescaleDB.

See [ADR-001](001-use-postgresql-timescaledb-storage.md) for details on the TimescaleDB removal.

---

## Context

LLM-based applications ("robots") face a fundamental challenge: LLMs have limited context windows (typically 128K-200K tokens) but need to maintain awareness across long conversations and sessions spanning days, weeks, or months.

Requirements:

- Persist memories across sessions (durable storage)
- Provide fast access to recent/relevant context
- Manage token budgets efficiently
- Never lose data accidentally
- Support contextual recall from the past

Alternative approaches:

1. **Database-only**: Store everything in PostgreSQL, load on demand
2. **Memory-only**: Keep everything in RAM, serialize on shutdown
3. **Two-tier**: Combine fast working memory with durable long-term storage
4. **External service**: Use a managed memory service

## Decision

We will implement a **two-tier memory architecture** with:

- **Working Memory**: Token-limited, in-memory active context
- **Long-term Memory**: Durable PostgreSQL/TimescaleDB storage

## Rationale

### Working Memory (Hot Tier)

- **Purpose**: Immediate context for LLM
- **Storage**: In-memory Ruby data structures
- **Capacity**: Token-limited (default 128K tokens)
- **Eviction**: LRU-based eviction when full
- **Access pattern**: Frequent reads, moderate writes
- **Lifetime**: Process lifetime

### Long-term Memory (Cold Tier)

- **Purpose**: Permanent knowledge base
- **Storage**: PostgreSQL with TimescaleDB
- **Capacity**: Effectively unlimited
- **Retention**: Permanent (explicit deletion only)
- **Access pattern**: RAG-based retrieval
- **Lifetime**: Forever

### Data Flow
```
Add Memory:
  User Input → Working Memory → Long-term Memory
               (immediate)      (persisted)

Recall Memory:
  Query → Long-term Memory (RAG search) → Working Memory
          (semantic + temporal)            (evict if needed)

Eviction:
  Working Memory (full) → Evict LRU → Long-term Memory (already there)
                                       (mark as evicted, not deleted)
```

## Implementation Details

### Working Memory
```ruby
class WorkingMemory
  attr_reader :max_tokens, :token_count

  def initialize(max_tokens: 128_000)
    @nodes = {}           # key => {value, token_count, importance, timestamp}
    @max_tokens = max_tokens
    @token_count = 0
  end

  def add(key, value, token_count:, importance: 1.0)
    evict_to_make_space(token_count) if needs_eviction?(token_count)
    @nodes[key] = {value: value, token_count: token_count, ...}
    @token_count += token_count
  end

  def evict_to_make_space(needed_tokens)
    # LRU eviction based on last access + importance
  end

  def assemble_context(strategy: :balanced, max_tokens: nil)
    # Sort by strategy and assemble within budget
  end
end
```

### Long-term Memory
```ruby
class LongTermMemory
  def add(key:, value:, embedding:, ...)
    # Insert into PostgreSQL with vector embedding
  end

  def search(timeframe:, query:, embedding_service:, limit:)
    # RAG-based retrieval: temporal + semantic
  end

  def mark_evicted(keys)
    # Update in_working_memory flag (not deleted)
  end
end
```

### Coordination (HTM class)
```ruby
class HTM
  def add_node(key, value, ...)
    # 1. Generate embedding
    # 2. Store in long-term memory
    # 3. Add to working memory (evict if needed)
  end

  def recall(timeframe:, topic:, ...)
    # 1. Search long-term memory (RAG)
    # 2. Add results to working memory (evict if needed)
    # 3. Return nodes
  end
end
```

## Consequences

### Positive

✅ **Fast context access**: Working memory provides O(1) lookups
✅ **Durable storage**: Never lose data, survives restarts
✅ **Token budget control**: Automatic management of context size
✅ **Explicit eviction policy**: Transparent behavior
✅ **RAG-enabled**: Search historical context semantically
✅ **Never-delete philosophy**: Eviction moves data, never removes
✅ **Process-isolated**: Each robot instance has independent working memory

### Negative

❌ **Complexity**: Two storage layers to coordinate
❌ **Memory overhead**: Working memory consumes RAM
❌ **Synchronization**: Keep both tiers consistent
❌ **Eviction overhead**: Moving data between tiers

### Neutral

➡️ **Token counting**: Requires accurate token estimation
➡️ **Strategy tuning**: Eviction and assembly strategies need calibration
➡️ **Per-process state**: Working memory not shared across processes

## Eviction Strategies

### LRU-based (Implemented)
```ruby
def eviction_score(node)
  recency = Time.now - node[:last_accessed]
  importance = node[:importance]

  # Lower score = evict first
  importance / (recency + 1.0)
end
```

### Future Strategies
- **Importance-only**: Keep most important nodes
- **Recency-only**: Pure LRU cache
- **Frequency-based**: Track access counts
- **Category-based**: Pin certain types (facts, preferences)
- **Smart eviction**: ML-based prediction of future access

## Context Assembly Strategies

### Recent (`:recent`)
Sort by `created_at DESC`, newest first

### Important (`:important`)
Sort by `importance DESC`, most important first

### Balanced (`:balanced`)
```ruby
score = importance * (1.0 / age_in_days)
```

### Future Strategies
- **Semantic clustering**: Group related memories
- **Conversation threading**: Follow reply chains
- **Category grouping**: Facts first, then context, etc.
- **Hybrid scoring**: Multiple factors weighted

## Design Principles

### Never Forget (Unless Told)

- Eviction moves data, never deletes
- Only `forget(confirm: :confirmed)` deletes
- Long-term memory is append-only (updates rare)

### Token Budget Management

- Token counting happens at add time
- Working memory enforces hard token limit
- Context assembly respects token budget
- Safety margin (10%) for token estimation errors

### Transparent Behavior

- Log all evictions
- Track in_working_memory flag
- Operations log for audit trail

## Risks and Mitigations

### Risk: Token Count Inaccuracy

- **Risk**: Tiktoken approximation differs from LLM's actual count
- **Likelihood**: Medium (different tokenizers)
- **Impact**: Medium (context overflow)
- **Mitigation**: Add safety margin (10%), use LLM-specific counters

### Risk: Eviction Thrashing

- **Risk**: Constant eviction/recall cycles
- **Likelihood**: Low (with proper sizing)
- **Impact**: Medium (performance degradation)
- **Mitigation**: Larger working memory, smarter eviction, caching

### Risk: Working Memory Growth

- **Risk**: Memory leaks or unbounded growth
- **Likelihood**: Low (token budget enforced)
- **Impact**: High (OOM crashes)
- **Mitigation**: Hard limits, monitoring, alerts

### Risk: Stale Working Memory

- **Risk**: Working memory doesn't reflect long-term updates
- **Likelihood**: Low (single-writer pattern)
- **Impact**: Low (eventual consistency OK)
- **Mitigation**: Refresh on recall, invalidation on update

## Alternatives Considered

### Database-Only
**Pros**: Simple, no synchronization
**Cons**: Slow access, no token budget management
**Decision**: ❌ Rejected - too slow for every LLM call

### Memory-Only
**Pros**: Fast, simple
**Cons**: Not durable, lost on crash
**Decision**: ❌ Rejected - unacceptable data loss risk

### External Service (Redis, Memcached)
**Pros**: Shared across processes, mature caching
**Cons**: Additional dependency, serialization overhead
**Decision**: ⏸️ Deferred - consider for multi-process scenarios

### Three-Tier (L1/L2/L3)
**Pros**: More granular caching
**Cons**: Much higher complexity
**Decision**: ❌ Rejected - YAGNI for v1

## Performance Characteristics

### Working Memory

- **Add**: O(1) amortized (eviction is O(n) when needed)
- **Retrieve**: O(1) hash lookup
- **Eviction**: O(n log n) for sorting, O(k) for removing k nodes
- **Context assembly**: O(n log n) for sorting, O(k) for selecting

### Long-term Memory

- **Add**: O(log n) PostgreSQL insert with indexes
- **Vector search**: O(log n) with HNSW index (approximate)
- **Full-text search**: O(log n) with GIN index
- **Hybrid search**: O(log n) for both, then merge

## Future Enhancements

1. **Shared working memory**: Redis-backed for multi-process
2. **Lazy loading**: Load nodes on first access
3. **Pre-fetching**: Anticipate needed context
4. **Compression**: Compress old working memory nodes
5. **Tiered eviction**: Multiple working memory levels
6. **Smart assembly**: ML-driven context selection

## References

- [Working Memory (Psychology)](https://en.wikipedia.org/wiki/Working_memory)
- [Cache Eviction Policies](https://en.wikipedia.org/wiki/Cache_replacement_policies)
- [LLM Context Window Management](https://www.anthropic.com/research/context-windows)
- [HTM Planning Document](../../htm_teamwork.md)

## Review Notes

**Systems Architect**: ✅ Clean separation of concerns. Consider shared cache for horizontal scaling.

**Performance Specialist**: ✅ Good balance of speed and durability. Monitor eviction frequency.

**AI Engineer**: ✅ Token budget management is critical. Add safety margins for token count variance.

**Ruby Expert**: ✅ Consider using Concurrent::Map for thread-safe working memory in future.
