# ADR-002: Two-Tier Memory Architecture

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM implements a **two-tier memory architecture** with token-limited working memory (hot tier) and unlimited long-term memory (cold tier), managing LLM context windows while preserving all historical data through RAG-based retrieval.

**Why**: LLMs have limited context windows but need awareness across long conversations. Two tiers provide fast access to recent context while maintaining complete history.

**Impact**: Efficient token budget management with never-forget guarantees, at the cost of coordination between two storage layers.

---

## Context

LLM-based applications face a fundamental challenge: LLMs have limited context windows (typically 128K-200K tokens) but need to maintain awareness across long conversations and sessions spanning days, weeks, or months.

### Requirements

- Persist memories across sessions (durable storage)
- Provide fast access to recent/relevant context
- Manage token budgets efficiently
- Never lose data accidentally
- Support contextual recall from the past

### Alternative Approaches

1. **Database-only**: Store everything in PostgreSQL, load on demand
2. **Memory-only**: Keep everything in RAM, serialize on shutdown
3. **Two-tier**: Combine fast working memory with durable long-term storage
4. **External service**: Use a managed memory service

---

## Decision

We will implement a **two-tier memory architecture** with:

- **Working Memory**: Token-limited, in-memory active context
- **Long-term Memory**: Durable PostgreSQL/TimescaleDB storage

---

## Rationale

### Working Memory (Hot Tier)

**Characteristics**:
- **Purpose**: Immediate context for LLM
- **Storage**: In-memory Ruby data structures
- **Capacity**: Token-limited (default 128K tokens)
- **Eviction**: LRU-based eviction when full
- **Access pattern**: Frequent reads, moderate writes
- **Lifetime**: Process lifetime

**Benefits**:
- O(1) hash lookups for fast context access
- Token budget control prevents context overflow
- Explicit eviction policy with transparent behavior

### Long-term Memory (Cold Tier)

**Characteristics**:
- **Purpose**: Permanent knowledge base
- **Storage**: PostgreSQL with TimescaleDB
- **Capacity**: Effectively unlimited
- **Retention**: Permanent (explicit deletion only)
- **Access pattern**: RAG-based retrieval
- **Lifetime**: Forever

**Benefits**:
- Never lose data, survives restarts
- Search historical context semantically
- Time-series queries for temporal context

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

---

## Implementation Details

### Working Memory

```ruby
class WorkingMemory
  attr_reader :max_tokens, :token_count

  def initialize(max_tokens: 128_000)
    @nodes = {}           # key => {value, token_count, importance, timestamp}
    @max_tokens = max_tokens
    @token_count = 0
    @access_order = []    # Track access for LRU
  end

  def add(key, value, token_count:, importance: 1.0)
    evict_to_make_space(token_count) if needs_eviction?(token_count)
    @nodes[key] = {
      value: value,
      token_count: token_count,
      importance: importance,
      added_at: Time.now,
      last_accessed: Time.now
    }
    @token_count += token_count
    @access_order << key
  end

  def evict_to_make_space(needed_tokens)
    # LRU eviction based on last access + importance
    # See ADR-007 for detailed eviction strategy
  end

  def assemble_context(strategy: :balanced, max_tokens: nil)
    # Sort by strategy and assemble within budget
    # See ADR-006 for context assembly strategies
  end
end
```

### Long-term Memory

```ruby
class LongTermMemory
  def add(key:, value:, embedding:, robot_id:, importance: 1.0, type: nil)
    # Insert into PostgreSQL with vector embedding
    @db.exec_params(<<~SQL, [key, value, embedding, robot_id, importance, type])
      INSERT INTO nodes (key, value, embedding, robot_id, importance, type, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
  end

  def search(timeframe:, query:, embedding_service:, limit:, strategy: :hybrid)
    # RAG-based retrieval: temporal + semantic
    # See ADR-005 for retrieval strategies
  end

  def mark_evicted(keys)
    # Update in_working_memory flag (not deleted)
    @db.exec_params(<<~SQL, [keys])
      UPDATE nodes
      SET in_working_memory = FALSE
      WHERE key = ANY($1)
    SQL
  end
end
```

### Coordination (HTM Class)

```ruby
class HTM
  def initialize(robot_name:, robot_id: nil, max_tokens: 128_000, ...)
    @working_memory = WorkingMemory.new(max_tokens: max_tokens)
    @long_term_memory = LongTermMemory.new(db_config)
    @embedding_service = EmbeddingService.new(...)
    @robot_id = robot_id || SecureRandom.uuid
    @robot_name = robot_name
  end

  def add_node(key, value, importance: 1.0, type: nil)
    # 1. Generate embedding
    embedding = @embedding_service.embed(value)

    # 2. Store in long-term memory
    @long_term_memory.add(
      key: key,
      value: value,
      embedding: embedding,
      robot_id: @robot_id,
      importance: importance,
      type: type
    )

    # 3. Add to working memory (evict if needed)
    token_count = estimate_tokens(value)
    @working_memory.add(key, value,
                        token_count: token_count,
                        importance: importance)
  end

  def recall(timeframe:, topic:, limit: 10, strategy: :hybrid)
    # 1. Search long-term memory (RAG)
    results = @long_term_memory.search(
      timeframe: timeframe,
      query: topic,
      embedding_service: @embedding_service,
      limit: limit,
      strategy: strategy
    )

    # 2. Add results to working memory (evict if needed)
    results.each do |node|
      @working_memory.add(node[:key], node[:value],
                          token_count: node[:token_count],
                          importance: node[:importance])
    end

    # 3. Return nodes
    results
  end
end
```

---

## Consequences

### Positive

- Fast context access through O(1) working memory lookups
- Durable storage ensures never lose data, survives restarts
- Token budget control with automatic management
- Explicit eviction policy provides transparent behavior
- RAG-enabled search of historical context semantically
- Never-delete philosophy: eviction moves data, never removes
- Process-isolated: each robot instance has independent working memory

### Negative

- Complexity of coordinating two storage layers
- Memory overhead from working memory consuming RAM
- Synchronization challenges keeping both tiers consistent
- Eviction overhead when moving data between tiers

### Neutral

- Token counting requires accurate estimation
- Strategy tuning for eviction and assembly needs calibration
- Per-process state means working memory not shared across processes

---

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

See [ADR-007: Working Memory Eviction Strategy](007-eviction-strategy.md) for detailed eviction algorithm.

### Future Strategies

- **Importance-only**: Keep most important nodes
- **Recency-only**: Pure LRU cache
- **Frequency-based**: Track access counts
- **Category-based**: Pin certain types (facts, preferences)
- **Smart eviction**: ML-based prediction of future access

---

## Context Assembly Strategies

### Recent (`:recent`)
Sort by `created_at DESC`, newest first

### Important (`:important`)
Sort by `importance DESC`, most important first

### Balanced (`:balanced`)
```ruby
score = importance * (1.0 / (1 + age_in_hours))
```

See [ADR-006: Context Assembly Strategies](006-context-assembly.md) for detailed assembly algorithms.

---

## Design Principles

### Never Forget (Unless Told)

- Eviction moves data, never deletes
- Only `forget(confirm: :confirmed)` deletes
- Long-term memory is append-only (updates rare)

See [ADR-009: Never-Forget Philosophy](009-never-forget.md) for deletion policies.

### Token Budget Management

- Token counting happens at add time
- Working memory enforces hard token limit
- Context assembly respects token budget
- Safety margin (10%) for token estimation errors

### Transparent Behavior

- Log all evictions
- Track `in_working_memory` flag
- Operations log for audit trail

---

## Risks and Mitigations

### Risk: Token Count Inaccuracy

!!! warning "Risk"
    Tiktoken approximation differs from LLM's actual count

**Likelihood**: Medium (different tokenizers)
**Impact**: Medium (context overflow)
**Mitigation**: Add safety margin (10%), use LLM-specific counters

### Risk: Eviction Thrashing

!!! info "Risk"
    Constant eviction/recall cycles

**Likelihood**: Low (with proper sizing)
**Impact**: Medium (performance degradation)
**Mitigation**: Larger working memory, smarter eviction, caching

### Risk: Working Memory Growth

!!! danger "Risk"
    Memory leaks or unbounded growth

**Likelihood**: Low (token budget enforced)
**Impact**: High (OOM crashes)
**Mitigation**: Hard limits, monitoring, alerts

### Risk: Stale Working Memory

!!! note "Risk"
    Working memory doesn't reflect long-term updates

**Likelihood**: Low (single-writer pattern)
**Impact**: Low (eventual consistency OK)
**Mitigation**: Refresh on recall, invalidation on update

---

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

---

## Future Enhancements

1. **Shared working memory**: Redis-backed for multi-process
2. **Lazy loading**: Load nodes on first access
3. **Pre-fetching**: Anticipate needed context
4. **Compression**: Compress old working memory nodes
5. **Tiered eviction**: Multiple working memory levels
6. **Smart assembly**: ML-driven context selection

---

## References

- [Working Memory (Psychology)](https://en.wikipedia.org/wiki/Working_memory)
- [Cache Eviction Policies](https://en.wikipedia.org/wiki/Cache_replacement_policies)
- [LLM Context Window Management](https://www.anthropic.com/research/context-windows)
- [ADR-001: PostgreSQL Storage](001-postgresql-timescaledb.md)
- [ADR-006: Context Assembly](006-context-assembly.md)
- [ADR-007: Eviction Strategy](007-eviction-strategy.md)

---

## Review Notes

**Systems Architect**: Clean separation of concerns. Consider shared cache for horizontal scaling.

**Performance Specialist**: Good balance of speed and durability. Monitor eviction frequency.

**AI Engineer**: Token budget management is critical. Add safety margins for token count variance.

**Ruby Expert**: Consider using Concurrent::Map for thread-safe working memory in future.
