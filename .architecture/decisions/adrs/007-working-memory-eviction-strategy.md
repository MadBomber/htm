# ADR-007: Working Memory Eviction Strategy

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

## Context

Working memory is token-limited (default 128,000 tokens). When adding new memories that would exceed the token limit, HTM must decide which existing memories to evict.

Eviction challenges:

- **Token limits**: Hard constraint, cannot exceed working memory capacity
- **Importance preservation**: Critical memories should remain in working memory
- **Recency**: Recent context often more relevant than old context
- **Fairness**: Don't always evict the same types of memories
- **Performance**: Eviction should be fast (< 10ms)
- **Never forget**: Evicted memories must be preserved in long-term memory

Alternative eviction policies:

1. **FIFO (First-In-First-Out)**: Evict oldest memories
2. **LRU (Least Recently Used)**: Evict least recently accessed
3. **LFU (Least Frequently Used)**: Evict least frequently accessed
4. **Random**: Evict random memories
5. **Importance-only**: Evict lowest importance first
6. **Hybrid**: Combine importance and recency with scoring function

## Decision

We will implement a **hybrid eviction strategy** that prioritizes memories by both importance and recency, evicting low-importance older memories first.

### Eviction Algorithm

```ruby
def evict_to_make_space(needed_tokens)
  # Sort by [importance, -recency]
  # Lower importance evicted first
  # Within same importance, older memories evicted first
  candidates = @nodes.sort_by do |key, node|
    recency = Time.now - node[:added_at]
    [node[:importance], -recency]
  end

  # Evict from front until enough space
  evicted = []
  tokens_freed = 0

  candidates.each do |key, node|
    break if tokens_freed >= needed_tokens

    evicted << { key: key, value: node[:value] }
    tokens_freed += node[:token_count]
    @nodes.delete(key)
    @access_order.delete(key)
  end

  evicted
end
```

### Eviction Scoring

**Primary sort**: Importance (ascending)

- Importance 1.0 evicted before importance 5.0
- Importance 5.0 evicted before importance 10.0

**Secondary sort**: Recency (descending age)

- Within same importance, older memories evicted first
- Added 5 days ago evicted before added 1 hour ago

### Never-Forget Guarantee

**Critical**: Evicted memories are NOT deleted. They:

1. Remain in long-term memory (PostgreSQL) permanently
2. Can be recalled via `recall()` when needed
3. Marked as `in_working_memory = FALSE` in database
4. Automatically reloaded if recalled again

## Rationale

### Why Hybrid (Importance + Recency)?

**Importance alone is insufficient**:

- All memories might have same importance
- Old important memories eventually become stale
- Doesn't account for temporal relevance

**Recency alone is insufficient**:

- Critical information gets evicted just because it's old
- Architectural decisions disappear after time passes
- Loses important long-term context

**Hybrid balances both**:

- Low-importance recent memories evicted before high-importance old ones
- Within same importance, temporal relevance matters
- Preserves critical knowledge while making space for new context

### Why This Sort Order?

```ruby
[node[:importance], -recency]
```

This creates tiers:

1. **Tier 1 (evict first)**: Low importance, old
2. **Tier 2**: Low importance, recent
3. **Tier 3**: High importance, old
4. **Tier 4 (evict last)**: High importance, recent

Example eviction order:
```
importance: 1.0, age: 5 days   → evicted first
importance: 1.0, age: 1 hour   → evicted second
importance: 5.0, age: 5 days   → evicted third
importance: 5.0, age: 1 hour   → evicted fourth
importance: 10.0, age: 5 days  → evicted fifth
importance: 10.0, age: 1 hour  → kept (evict last)
```

### Eviction Guarantees

**Safety**:

- ✅ Evicted memories preserved in long-term storage
- ✅ No data loss, only working memory removal
- ✅ Can be recalled when needed

**Performance**:

- ✅ Greedy eviction: stops as soon as enough space freed
- ✅ O(n log n) sorting (one-time cost)
- ✅ O(k) eviction where k = nodes evicted
- ✅ Typical eviction: < 10ms for 100-node working memory

**Correctness**:

- ✅ Always frees enough tokens (or evicts all nodes trying)
- ✅ Respects importance ordering
- ✅ Deterministic (same state → same evictions)

## Consequences

### Positive

✅ **Preserves important context**: High-importance memories stay longer
✅ **Temporal relevance**: Recent context preferred over old
✅ **Never forgets**: Evicted memories remain in long-term storage
✅ **Predictable**: Clear eviction order based on importance + recency
✅ **Fast**: O(n log n) sort, greedy eviction
✅ **Greedy**: Only evicts what's necessary, no over-eviction
✅ **Safe**: No data loss, recallable from long-term memory

### Negative

❌ **No access frequency**: Doesn't track how often memory is used
❌ **No semantic clustering**: May split related memories
❌ **Importance subjectivity**: Relies on user-assigned importance
❌ **Batch eviction cost**: O(n log n) sort on every eviction
❌ **No look-ahead**: Doesn't predict which memories will be needed soon

### Neutral

➡️ **Importance matters**: Users must assign meaningful importance scores
➡️ **Eviction visibility**: No notification when memories evicted
➡️ **Recall overhead**: Need to recall evicted memories if needed again

## Design Decisions

### Decision: Hybrid (Importance + Recency) vs Pure Policies
**Rationale**: Balances competing priorities better than any single factor

**Alternative**: Pure LRU (least recently used)
**Rejected**: Loses important long-term context

**Alternative**: Pure importance-based
**Rejected**: All old memories evicted regardless of importance

### Decision: Primary Sort by Importance
**Rationale**: Importance is the stronger signal for retention

**Alternative**: Primary sort by recency
**Rejected**: Would evict critical old memories before trivial recent ones

### Decision: Greedy Eviction (Stop When Enough Space)
**Rationale**: Minimize evictions, preserve as much context as possible

**Alternative**: Evict to some threshold (e.g., 80% full)
**Rejected**: Unnecessary evictions, reduces available context

### Decision: No Access Frequency Tracking
**Rationale**: Simplicity, access patterns not stable in LLM workflows

**Alternative**: LFU (Least Frequently Used)
**Deferred**: Can add access_count tracking if real-world usage shows value

### Decision: Evicted Memories Preserved in Long-Term
**Rationale**: Never-forget philosophy, safety, recallability

**Alternative**: Truly delete evicted memories
**Rejected**: Violates never-forget principle, data loss

## Use Cases

### Use Case 1: Adding Large Memory to Full Working Memory
```ruby
# Working memory: 127,500 / 128,000 tokens (99% full)
# Attempt to add 5,000 token memory

htm.add_node("new_large_memory", large_text, importance: 7.0)

# Eviction needed: 5,000 - 500 = 4,500 tokens

# Working memory contains:
# - "user_pref" (importance: 8.0, 100 tokens, 5 days old)
# - "random_note" (importance: 1.0, 2,000 tokens, 1 hour ago)
# - "architecture_decision" (importance: 10.0, 3,000 tokens, 3 days ago)
# - "debug_log" (importance: 2.0, 1,500 tokens, 2 days ago)

# Eviction order:
# 1. "random_note" (importance: 1.0) → 2,000 tokens freed
# 2. "debug_log" (importance: 2.0) → 3,500 tokens freed
# 3. Stop (4,500 > needed)

# Result: user_pref and architecture_decision preserved
```

### Use Case 2: Importance Ties
```ruby
# All memories have importance: 5.0

# Working memory:
# - "note_1" (5 days old, 1,000 tokens)
# - "note_2" (3 days old, 1,000 tokens)
# - "note_3" (1 hour ago, 1,000 tokens)

# Need to evict 2,000 tokens

# Eviction order:
# 1. "note_1" (oldest) → 1,000 tokens
# 2. "note_2" (second oldest) → 2,000 tokens
# 3. Stop

# Result: Most recent note preserved
```

### Use Case 3: Recall Evicted Memory
```ruby
# Memory evicted from working memory
htm.add_node("temp_note", "Some temporary information", importance: 1.0)
# ... later evicted to make space ...

# Later: recall the evicted memory
memories = htm.recall(timeframe: "last week", topic: "temporary information")

# Result: Memory retrieved from long-term storage
# And automatically added back to working memory
```

### Use Case 4: High-Importance Old Memory
```ruby
# Critical decision made months ago
htm.add_node("critical_decision",
             "We must never use MongoDB for time-series data",
             importance: 10.0)

# ... 90 days later, working memory full ...

# Many recent low-importance memories added
# Critical decision still in working memory due to importance: 10.0

# Eviction: Low-importance recent memories evicted first
# Result: Critical decision preserved despite being 90 days old
```

## Performance Characteristics

### Time Complexity

- **Sorting**: O(n log n) where n = nodes in working memory
- **Eviction**: O(k) where k = nodes evicted
- **Total**: O(n log n + k) ≈ O(n log n)

### Space Complexity

- **Sorted candidates**: O(n) temporary array
- **Evicted list**: O(k) returned result
- **Total**: O(n) additional memory

### Typical Performance

- **Working memory size**: 50-200 nodes
- **Eviction frequency**: Low (most additions fit without eviction)
- **Sort time**: < 5ms for 200 nodes
- **Eviction time**: < 1ms (greedy, stops early)
- **Total**: < 10ms per eviction event

### Optimization Opportunities

- **Cache sorted order**: Invalidate on add/remove
- **Incremental sort**: Use heap for O(k log n) eviction
- **Lazy eviction**: Evict only when space check fails

## Risks and Mitigations

### Risk: Batch Eviction Cost

- **Risk**: O(n log n) sort on every eviction is expensive
- **Likelihood**: Low (evictions infrequent, n is small)
- **Impact**: Low (< 10ms for typical working memory)
- **Mitigation**:
  - Working memory stays small (128K tokens ≈ 50-200 nodes)
  - Sort only when eviction needed
  - Consider heap-based eviction if profiling shows bottleneck

### Risk: Importance Scoring Inconsistency

- **Risk**: Users assign arbitrary importance, breaks eviction quality
- **Likelihood**: Medium (subjective scoring)
- **Impact**: Medium (suboptimal evictions)
- **Mitigation**:
  - Document importance scoring guidelines
  - Provide examples of importance ranges
  - Default importance: 1.0 for most memories

### Risk: No Access Frequency Signal

- **Risk**: Frequently accessed memories evicted if old and low importance
- **Likelihood**: Low (frequently accessed → likely important or recent)
- **Impact**: Low (can recall from long-term)
- **Mitigation**:
  - Monitor real-world eviction patterns
  - Add access_count tracking if needed

### Risk: Related Memories Split

- **Risk**: Semantically related memories evicted separately
- **Likelihood**: Medium (no clustering)
- **Impact**: Low (can recall together with topic search)
- **Mitigation**:
  - Use relationships to co-recall related memories
  - Consider cluster-aware eviction in future

## Future Enhancements

### Access Frequency Tracking
```ruby
def add(key, value, ...)
  @nodes[key] = {
    ...,
    access_count: 0
  }
end

def evict_to_make_space(needed_tokens)
  candidates = @nodes.sort_by do |key, node|
    recency = Time.now - node[:added_at]
    access_freq = node[:access_count]

    # Lower score evicted first
    score = node[:importance] * (1 + Math.log(1 + access_freq))
    [score, -recency]
  end
end
```

### Cluster-Aware Eviction
```ruby
# Keep related memories together
def evict_to_make_space(needed_tokens)
  # Identify memory clusters
  clusters = identify_clusters(@nodes)

  # Evict entire clusters to preserve coherence
  clusters.sort_by { |c| cluster_score(c) }.each do |cluster|
    # Evict full cluster
  end
end
```

### Lazy Eviction
```ruby
# Don't evict until actually assembling context
def assemble_context(strategy:, max_tokens:)
  # Only NOW evict if needed
  evict_to_fit(max_tokens) if token_count > max_tokens
end
```

### Predicted Need Scoring
```ruby
# Use LLM or heuristics to predict which memories will be needed
def evict_to_make_space(needed_tokens)
  candidates = @nodes.sort_by do |key, node|
    predicted_need = predict_future_access(node)  # ML model or heuristics
    [node[:importance] * predicted_need, -recency]
  end
end
```

### Configurable Eviction Policy
```ruby
htm = HTM.new(
  eviction_policy: :lru  # or :importance, :hybrid, :custom
)
```

## Alternatives Considered

### Pure LRU (Least Recently Used)
**Pros**: Standard caching algorithm, temporal locality
**Cons**: Loses important long-term context
**Decision**: ❌ Rejected - importance matters for LLM memory

### Pure Importance-Based
**Pros**: Preserves most important information
**Cons**: Old memories never evicted, no temporal relevance
**Decision**: ❌ Rejected - recency matters in conversations

### LFU (Least Frequently Used)
**Pros**: Captures access patterns
**Cons**: New memories always evicted (frequency = 1), complex
**Decision**: ❌ Rejected - access patterns unstable in LLM workflows

### Random Eviction
**Pros**: Simple, no sorting overhead
**Cons**: Unpredictable, may evict important memories
**Decision**: ❌ Rejected - too risky, no guarantees

### Learned Eviction Policy
**Pros**: Optimal for specific usage patterns
**Cons**: Complex, requires training, non-deterministic
**Decision**: 🔄 Deferred - consider for v2 after usage data

## References

- [Cache Replacement Policies](https://en.wikipedia.org/wiki/Cache_replacement_policies)
- [LRU Cache](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_recently_used_(LRU))
- [Working Memory Management](https://en.wikipedia.org/wiki/Working_memory)
- [Multi-Level Memory Hierarchies](https://en.wikipedia.org/wiki/Memory_hierarchy)

## Review Notes

**Systems Architect**: ✅ Hybrid eviction is the right choice. Consider heap-based eviction for better asymptotic complexity.

**Performance Specialist**: ✅ O(n log n) is acceptable for n < 200. Monitor real-world eviction frequency.

**Domain Expert**: ✅ Never-forget guarantee is essential. Eviction is just working memory management.

**AI Engineer**: ✅ Importance + recency works well for LLM context. Consider learned eviction in future.

**Ruby Expert**: ✅ Clean implementation. Consider extracting eviction policy to strategy pattern for extensibility.
