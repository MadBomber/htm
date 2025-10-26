# ADR-007: Working Memory Eviction Strategy

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM implements a **hybrid eviction strategy** that prioritizes memories by both importance and recency, evicting low-importance older memories first when working memory reaches token capacity. Evicted memories are preserved in long-term storage, never deleted.

**Why**: Token limits are hard constraints, but eviction policy determines which context stays active. Hybrid approach balances preserving critical knowledge with maintaining temporal relevance.

**Impact**: Predictable eviction behavior with never-forget guarantees, at the cost of requiring meaningful importance scoring from users.

---

## Context

Working memory is token-limited (default 128,000 tokens). When adding new memories that would exceed the token limit, HTM must decide which existing memories to evict.

### Eviction Challenges

- **Token limits**: Hard constraint, cannot exceed working memory capacity
- **Importance preservation**: Critical memories should remain in working memory
- **Recency**: Recent context often more relevant than old context
- **Fairness**: Don't always evict the same types of memories
- **Performance**: Eviction should be fast (< 10ms)
- **Never forget**: Evicted memories must be preserved in long-term memory

### Alternative Eviction Policies

1. **FIFO (First-In-First-Out)**: Evict oldest memories
2. **LRU (Least Recently Used)**: Evict least recently accessed
3. **LFU (Least Frequently Used)**: Evict least frequently accessed
4. **Random**: Evict random memories
5. **Importance-only**: Evict lowest importance first
6. **Hybrid**: Combine importance and recency with scoring function

---

## Decision

We will implement a **hybrid eviction strategy** that prioritizes memories by both importance and recency, evicting low-importance older memories first.

<svg viewBox="0 0 950 750" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <defs>
    <style>
      .flow-box { fill: rgba(33, 150, 243, 0.2); stroke: #2196F3; stroke-width: 2; }
      .tier-box { fill: rgba(76, 175, 80, 0.2); stroke: #4CAF50; stroke-width: 2; }
      .tier1-box { fill: rgba(244, 67, 54, 0.3); stroke: #F44336; stroke-width: 2; }
      .tier2-box { fill: rgba(255, 152, 0, 0.3); stroke: #FF9800; stroke-width: 2; }
      .tier3-box { fill: rgba(255, 235, 59, 0.3); stroke: #FFEB3B; stroke-width: 2; }
      .tier4-box { fill: rgba(76, 175, 80, 0.3); stroke: #4CAF50; stroke-width: 2; }
      .text-header { fill: #E0E0E0; font-size: 18px; font-weight: bold; }
      .text-label { fill: #E0E0E0; font-size: 14px; font-weight: bold; }
      .text-small { fill: #B0B0B0; font-size: 11px; }
      .text-tiny { fill: #A0A0A0; font-size: 10px; }
      .arrow { stroke: #4A9EFF; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
    </style>
    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#4A9EFF" />
    </marker>
  </defs>

  <!-- Title -->
  <text x="475" y="30" text-anchor="middle" class="text-header">Hybrid Eviction Algorithm</text>

  <!-- Algorithm Flow -->
  <text x="50" y="65" class="text-label">Eviction Process</text>

  <!-- Step 1 -->
  <rect x="50" y="80" width="380" height="60" class="flow-box" rx="5"/>
  <text x="60" y="100" class="text-label">1. Calculate Eviction Score</text>
  <text x="60" y="120" class="text-small">score = [importance, -recency]</text>

  <!-- Step 2 -->
  <rect x="50" y="155" width="380" height="60" class="flow-box" rx="5"/>
  <text x="60" y="175" class="text-label">2. Sort Memories by Score</text>
  <text x="60" y="195" class="text-small">Primary: importance (asc), Secondary: age (desc)</text>

  <!-- Step 3 -->
  <rect x="50" y="230" width="380" height="60" class="flow-box" rx="5"/>
  <text x="60" y="250" class="text-label">3. Greedy Eviction</text>
  <text x="60" y="270" class="text-small">Evict from front until needed_tokens freed</text>

  <!-- Step 4 -->
  <rect x="50" y="305" width="380" height="60" class="flow-box" rx="5"/>
  <text x="60" y="325" class="text-label">4. Mark as Evicted</text>
  <text x="60" y="345" class="text-small">Set in_working_memory = false in database</text>

  <!-- Arrows -->
  <path d="M 240 140 L 240 155" class="arrow"/>
  <path d="M 240 215 L 240 230" class="arrow"/>
  <path d="M 240 290 L 240 305" class="arrow"/>

  <!-- Eviction Tiers -->
  <text x="520" y="65" class="text-label">Eviction Priority Tiers</text>
  <text x="520" y="80" class="text-small">(Lower tier = evicted first)</text>

  <!-- Tier 1 -->
  <rect x="520" y="100" width="380" height="110" class="tier1-box" rx="5"/>
  <text x="530" y="120" class="text-label" fill="#F44336">Tier 1: Low Importance + Old</text>
  <text x="530" y="140" class="text-small">Evicted First</text>
  <text x="530" y="165" class="text-tiny">importance: 1.0, age: 5 days → evicted 1st</text>
  <text x="530" y="180" class="text-tiny">importance: 2.0, age: 3 days → evicted 2nd</text>
  <text x="530" y="195" class="text-tiny">Examples: Temporary notes, scratch data</text>

  <!-- Tier 2 -->
  <rect x="520" y="225" width="380" height="110" class="tier2-box" rx="5"/>
  <text x="530" y="245" class="text-label" fill="#FF9800">Tier 2: Low Importance + Recent</text>
  <text x="530" y="265" class="text-small">Evicted Second</text>
  <text x="530" y="290" class="text-tiny">importance: 1.0, age: 1 hour → evicted 3rd</text>
  <text x="530" y="305" class="text-tiny">importance: 2.0, age: 30 min → evicted 4th</text>
  <text x="530" y="320" class="text-tiny">Examples: Recent but low-value context</text>

  <!-- Tier 3 -->
  <rect x="520" y="350" width="380" height="110" class="tier3-box" rx="5"/>
  <text x="530" y="370" class="text-label" fill="#FDD835">Tier 3: High Importance + Old</text>
  <text x="530" y="390" class="text-small">Evicted Third</text>
  <text x="530" y="415" class="text-tiny">importance: 9.0, age: 30 days → evicted 5th</text>
  <text x="530" y="430" class="text-tiny">importance: 10.0, age: 90 days → evicted 6th</text>
  <text x="530" y="445" class="text-tiny">Examples: Old but critical decisions</text>

  <!-- Tier 4 -->
  <rect x="520" y="475" width="380" height="110" class="tier4-box" rx="5"/>
  <text x="530" y="495" class="text-label" fill="#4CAF50">Tier 4: High Importance + Recent</text>
  <text x="530" y="515" class="text-small">Kept (Evicted Last)</text>
  <text x="530" y="540" class="text-tiny">importance: 9.0, age: 1 hour → kept longest</text>
  <text x="530" y="555" class="text-tiny">importance: 10.0, age: 5 min → never evicted (if possible)</text>
  <text x="530" y="570" class="text-tiny">Examples: Critical + actively used data</text>

  <!-- Key Features -->
  <text x="50" y="410" class="text-label">Guarantees</text>

  <rect x="50" y="425" width="170" height="140" fill="rgba(33, 150, 243, 0.15)" stroke="#2196F3" stroke-width="1.5" rx="3"/>
  <text x="60" y="450" class="text-small">✓ Never-forget principle</text>
  <text x="60" y="470" class="text-small">✓ Preserved in long-term</text>
  <text x="60" y="490" class="text-small">✓ Can be recalled</text>
  <text x="60" y="510" class="text-small">✓ No data loss</text>
  <text x="60" y="530" class="text-small">✓ Deterministic order</text>
  <text x="60" y="550" class="text-small">✓ O(n log n) complexity</text>

  <rect x="240" y="425" width="190" height="140" fill="rgba(33, 150, 243, 0.15)" stroke="#2196F3" stroke-width="1.5" rx="3"/>
  <text x="250" y="450" class="text-small">Performance:</text>
  <text x="250" y="470" class="text-tiny">• Sort: O(n log n)</text>
  <text x="250" y="485" class="text-tiny">• Eviction: O(k) greedy</text>
  <text x="250" y="500" class="text-tiny">• Typical: &lt;10ms</text>
  <text x="250" y="515" class="text-tiny">• Memory: O(n) temp</text>
  <text x="250" y="530" class="text-tiny">• Stops when enough</text>
  <text x="250" y="545" class="text-tiny">  space freed</text>

  <!-- Example -->
  <text x="50" y="600" class="text-label">Example: Need 5,000 tokens</text>

  <rect x="50" y="615" width="850" height="110" fill="rgba(33, 150, 243, 0.1)" stroke="#2196F3" stroke-width="1" rx="3"/>

  <text x="60" y="635" class="text-tiny">Working memory contains:</text>
  <text x="70" y="655" class="text-tiny" fill="#F44336">• "random_note" (imp: 1.0, 2000 tok, 1 hr ago) → EVICTED (Tier 2)</text>
  <text x="70" y="670" class="text-tiny" fill="#F44336">• "debug_log" (imp: 2.0, 1500 tok, 2 days ago) → EVICTED (Tier 1)</text>
  <text x="70" y="685" class="text-tiny" fill="#F44336">• "temp_calc" (imp: 1.5, 1600 tok, 5 days ago) → EVICTED (Tier 1)</text>
  <text x="70" y="700" class="text-tiny" fill="#4CAF50">• "user_pref" (imp: 8.0, 100 tok, 5 days ago) → KEPT (Tier 3)</text>
  <text x="70" y="715" class="text-tiny" fill="#4CAF50">• "architecture_decision" (imp: 10.0, 3000 tok, 3 days ago) → KEPT (Tier 3)</text>
</svg>

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

!!! tip "Critical Design Principle"
    Evicted memories are NOT deleted. They:

    1. Remain in long-term memory (PostgreSQL) permanently
    2. Can be recalled via `recall()` when needed
    3. Marked as `in_working_memory = FALSE` in database
    4. Automatically reloaded if recalled again

---

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

- Evicted memories preserved in long-term storage
- No data loss, only working memory removal
- Can be recalled when needed

**Performance**:

- Greedy eviction: stops as soon as enough space freed
- O(n log n) sorting (one-time cost)
- O(k) eviction where k = nodes evicted
- Typical eviction: < 10ms for 100-node working memory

**Correctness**:

- Always frees enough tokens (or evicts all nodes trying)
- Respects importance ordering
- Deterministic (same state → same evictions)

---

## Consequences

### Positive

- Preserves important context: High-importance memories stay longer
- Temporal relevance: Recent context preferred over old
- Never forgets: Evicted memories remain in long-term storage
- Predictable: Clear eviction order based on importance + recency
- Fast: O(n log n) sort, greedy eviction
- Greedy: Only evicts what's necessary, no over-eviction
- Safe: No data loss, recallable from long-term memory

### Negative

- No access frequency: Doesn't track how often memory is used
- No semantic clustering: May split related memories
- Importance subjectivity: Relies on user-assigned importance
- Batch eviction cost: O(n log n) sort on every eviction
- No look-ahead: Doesn't predict which memories will be needed soon

### Neutral

- Importance matters: Users must assign meaningful importance scores
- Eviction visibility: No notification when memories evicted
- Recall overhead: Need to recall evicted memories if needed again

---

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

---

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

---

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

---

## Risks and Mitigations

### Risk: Batch Eviction Cost

!!! info "Risk"
    O(n log n) sort on every eviction is expensive

**Likelihood**: Low (evictions infrequent, n is small)

**Impact**: Low (< 10ms for typical working memory)

**Mitigation**:

- Working memory stays small (128K tokens ≈ 50-200 nodes)
- Sort only when eviction needed
- Consider heap-based eviction if profiling shows bottleneck

### Risk: Importance Scoring Inconsistency

!!! warning "Risk"
    Users assign arbitrary importance, breaks eviction quality

**Likelihood**: Medium (subjective scoring)

**Impact**: Medium (suboptimal evictions)

**Mitigation**:

- Document importance scoring guidelines
- Provide examples of importance ranges
- Default importance: 1.0 for most memories

### Risk: No Access Frequency Signal

!!! info "Risk"
    Frequently accessed memories evicted if old and low importance

**Likelihood**: Low (frequently accessed → likely important or recent)

**Impact**: Low (can recall from long-term)

**Mitigation**:

- Monitor real-world eviction patterns
- Add access_count tracking if needed

### Risk: Related Memories Split

!!! info "Risk"
    Semantically related memories evicted separately

**Likelihood**: Medium (no clustering)

**Impact**: Low (can recall together with topic search)

**Mitigation**:

- Use relationships to co-recall related memories
- Consider cluster-aware eviction in future

---

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

---

## Alternatives Comparison

| Policy | Pros | Cons | Decision |
|--------|------|------|----------|
| **Hybrid (Importance + Recency)** | **Balanced retention** | **Requires importance** | **ACCEPTED** |
| Pure LRU | Standard caching, temporal | Loses important context | Rejected |
| Pure Importance | Preserves critical info | No temporal relevance | Rejected |
| LFU | Captures access patterns | New memories always evicted | Rejected |
| Random | Simple, no sorting | Unpredictable, risky | Rejected |
| Learned Policy | Optimal for patterns | Complex, non-deterministic | Deferred |

---

## References

- [Cache Replacement Policies](https://en.wikipedia.org/wiki/Cache_replacement_policies)
- [LRU Cache](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_recently_used_(LRU))
- [Working Memory Management](https://en.wikipedia.org/wiki/Working_memory)
- [Multi-Level Memory Hierarchies](https://en.wikipedia.org/wiki/Memory_hierarchy)
- [ADR-002: Two-Tier Memory](002-two-tier-memory.md)
- [ADR-006: Context Assembly](006-context-assembly.md)
- [ADR-009: Never-Forget Philosophy](009-never-forget.md)
- [Working Memory Guide](../../guides/working-memory.md)

---

## Review Notes

**Systems Architect**: Hybrid eviction is the right choice. Consider heap-based eviction for better asymptotic complexity.

**Performance Specialist**: O(n log n) is acceptable for n < 200. Monitor real-world eviction frequency.

**Domain Expert**: Never-forget guarantee is essential. Eviction is just working memory management.

**AI Engineer**: Importance + recency works well for LLM context. Consider learned eviction in future.

**Ruby Expert**: Clean implementation. Consider extracting eviction policy to strategy pattern for extensibility.
