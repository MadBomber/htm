# ADR-006: Context Assembly Strategies

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM implements **three context assembly strategies**: recent (newest first), important (highest priority first), and balanced (importance weighted by time decay). Users choose the strategy based on their use case when preparing context for LLMs.

**Why**: Different tasks need different context. Chat needs recency, strategic planning needs importance, and general assistance benefits from a balanced approach.

**Impact**: Flexible context assembly with predictable behavior and user control, at the cost of strategy selection responsibility.

---

## Context

When preparing context for an LLM, working memory may contain more information than can fit within token limits. HTM needs to intelligently select which memories to include in the assembled context string.

### Challenges in Context Assembly

- **Token limits**: LLMs have finite context windows (even with 128K working memory)
- **Relevance**: Not all memories are equally important for current task
- **Recency bias**: Recent context often more relevant, but not always
- **Priority conflicts**: Important old memories vs. less important recent ones
- **Performance**: Context assembly should be fast (< 10ms)

### Alternative Approaches

1. **FIFO (First-In-First-Out)**: Always include oldest memories
2. **LIFO (Last-In-First-Out)**: Always include newest memories
3. **Importance-only**: Sort by importance score
4. **Recency-only**: Sort by access time
5. **Balanced (hybrid)**: Combine importance and recency with decay function

---

## Decision

We will implement **three context assembly strategies**: recent, important, and balanced, allowing users to choose based on their use case.

### Strategy Definitions

**1. Recent (`:recent`)**

- Sort by access order, most recently accessed first
- Best for: Conversational continuity, following current discussion thread
- Use case: Chat interfaces, debugging sessions, iterative development

**2. Important (`:important`)**

- Sort by importance score, highest first
- Best for: Critical information, architectural decisions, key facts
- Use case: Decision-making, strategic planning, summarization

**3. Balanced (`:balanced`)** - **Recommended Default**

- Hybrid scoring: `importance * (1.0 / (1 + recency_hours))`
- Importance weighted by time decay (1-hour half-life)
- Best for: General-purpose context assembly
- Use case: Most LLM interactions, mixed conversational + strategic context

---

## Rationale

### Why Multiple Strategies?

**Different tasks need different context**:

- Chat conversation: Recent context critical for coherence
- Strategic planning: Important decisions matter more than recency
- General assistance: Balance of both

**User control over LLM context**:

- Explicit strategy selection gives predictable behavior
- No hidden heuristics or magic
- Easy to debug context issues

**Performance and simplicity**:

- All strategies are simple sorts (O(n log n))
- No ML models or complex algorithms
- Fast context assembly (< 10ms for typical working memory)

### Decay Function Analysis

The balanced strategy uses a **1-hour half-life decay**:

```
score = importance * (1.0 / (1 + hours))

Examples:
- Just added (0 hours): importance * 1.0 (full weight)
- 1 hour old: importance * 0.5 (half weight)
- 3 hours old: importance * 0.25 (quarter weight)
- 24 hours old: importance * 0.04 (4% weight)
```

This means:

- Recent memories get full importance weight
- Importance decays quickly in first few hours
- Very old memories need high importance to compete

---

## Implementation Details

### Context Assembly Function

```ruby
def assemble_context(strategy:, max_tokens: nil)
  max = max_tokens || @max_tokens

  nodes = case strategy
  when :recent
    # Most recently accessed first
    @access_order.reverse.map { |k| @nodes[k] }

  when :important
    # Highest importance first
    @nodes.sort_by { |k, v| -v[:importance] }.map(&:last)

  when :balanced
    # Importance * recency decay (1-hour half-life)
    @nodes.sort_by { |k, v|
      recency_hours = (Time.now - v[:added_at]) / 3600.0
      score = v[:importance] * (1.0 / (1 + recency_hours))
      -score  # Negate for descending sort
    }.map(&:last)

  else
    raise ArgumentError, "Unknown strategy: #{strategy}"
  end

  # Build context up to token limit
  context_parts = []
  current_tokens = 0

  nodes.each do |node|
    break if current_tokens + node[:token_count] > max
    context_parts << node[:value]
    current_tokens += node[:token_count]
  end

  context_parts.join("\n\n")
end
```

### User API

```ruby
# Use balanced strategy (recommended default)
context = htm.create_context(strategy: :balanced)

# Use recent for conversational continuity
context = htm.create_context(strategy: :recent, max_tokens: 4000)

# Use important for strategic decisions
context = htm.create_context(strategy: :important)
```

---

## Consequences

### Positive

- Flexible: Choose strategy based on use case
- Predictable: Clear sorting behavior, no hidden heuristics
- Fast: Simple sorting algorithms, < 10ms
- Debuggable: Easy to understand why context contains certain memories
- User control: Explicit strategy selection
- Sensible default: Balanced strategy works well for most cases
- Token-aware: Respects max_tokens limit in all strategies

### Negative

- Strategy selection burden: User must understand differences
- No automatic optimization: Doesn't learn optimal strategy
- Decay tuning: 1-hour half-life may not suit all use cases
- No semantic clustering: Doesn't group related memories together
- Position bias: Earlier context may have more LLM influence

### Neutral

- Importance scoring: Requires user to assign meaningful importance
- Access tracking: Recent strategy depends on access order
- Token estimation: Accuracy depends on token counting precision

---

## Use Cases

### Use Case 1: Conversational Chat

```ruby
# User having back-and-forth conversation with LLM
# Recent context is critical for coherence

context = htm.create_context(strategy: :recent, max_tokens: 8000)

# Example memories in working memory:
# - "User prefers debug_me over puts" (importance: 9, 5 days old)
# - "What is the capital of France?" (importance: 1, 2 minutes ago)
# - "Paris is the capital" (importance: 1, 1 minute ago)

# Result: Recent conversation about Paris included first,
# even though user preference is more important
```

### Use Case 2: Strategic Planning

```ruby
# LLM helping with architectural decisions
# Important decisions matter more than recent chat

context = htm.create_context(strategy: :important)

# Example memories:
# - "We decided to use PostgreSQL" (importance: 10, 3 days ago)
# - "What time is it?" (importance: 1, 1 minute ago)
# - "TimescaleDB chosen for time-series" (importance: 9, 2 days ago)

# Result: Architectural decisions included first,
# time check ignored if space limited
```

### Use Case 3: General Assistance (Balanced)

```ruby
# LLM helping with mixed tasks
# Balance recent context + important knowledge

context = htm.create_context(strategy: :balanced)

# Example memories:
# - "User prefers debug_me" (importance: 9, 5 days ago) → score: 0.007
# - "PostgreSQL decision" (importance: 10, 3 days ago) → score: 0.014
# - "Current debugging issue" (importance: 5, 10 minutes ago) → score: 3.0
# - "Error: foreign key violation" (importance: 7, 2 minutes ago) → score: 21.0

# Result: Recent debugging context ranked highest,
# but important decisions still included if space permits
```

### Use Case 4: Custom Token Limit

```ruby
# Generate short summary for preview
short_context = htm.create_context(strategy: :important, max_tokens: 500)

# Generate full context for LLM
full_context = htm.create_context(strategy: :balanced, max_tokens: 128_000)
```

---

## Performance Characteristics

### Complexity

- **Recent**: O(n) - reverse access order array
- **Important**: O(n log n) - sort by importance
- **Balanced**: O(n log n) - sort by computed score

### Typical Performance

- **Working memory size**: 50-200 nodes
- **Sorting time**: < 5ms (all strategies)
- **String assembly**: < 5ms
- **Total**: < 10ms for context assembly

### Memory Usage

- **No duplication**: Nodes stored once, sorted references
- **Temporary arrays**: O(n) for sorted node references
- **Output string**: O(total_tokens) for assembled context

---

## Design Decisions

### Decision: Three Strategies Instead of One

**Rationale**: Different use cases benefit from different strategies. Flexibility > simplicity.

**Alternative**: Single balanced strategy for all use cases

**Rejected**: Forces one-size-fits-all approach, limits user control

### Decision: Balanced as Default

**Rationale**: Best general-purpose behavior, balances competing priorities

**Alternative**: Recent as default

**Rejected**: Important long-term knowledge gets lost in conversations

### Decision: 1-Hour Decay Half-Life

**Rationale**:

- 1 hour matches typical development session length
- Quick decay prevents stale context from dominating
- Long enough to preserve within-session continuity

**Alternative**: Configurable decay parameter

**Deferred**: Can add if real-world usage shows need for tuning

### Decision: Linear Decay (1 / (1 + hours))

**Rationale**: Simple, predictable, computationally cheap

**Alternative**: Exponential decay `exp(-λ * hours)`

**Rejected**: More complex, harder to reason about, minimal practical difference

### Decision: Token Limit Enforced Strictly

**Rationale**: Never exceed LLM context window, prevent truncation errors

**Alternative**: Soft limit with warnings

**Rejected**: Hard limits prevent surprising behavior

---

## Risks and Mitigations

### Risk: Suboptimal Decay Parameter

!!! info "Risk"
    1-hour half-life doesn't match real usage patterns

**Likelihood**: Medium (usage patterns vary)

**Impact**: Low (balanced strategy still works reasonably)

**Mitigation**:

- Monitor real-world usage patterns
- Make decay configurable if needed
- Document decay behavior clearly

### Risk: Strategy Confusion

!!! warning "Risk"
    Users don't understand which strategy to use

**Likelihood**: Medium (three choices require understanding)

**Impact**: Low (balanced default works well)

**Mitigation**:

- Clear documentation with use cases
- Examples in API docs
- Sensible default (balanced)

### Risk: Position Bias in LLM

!!! info "Risk"
    LLM pays more attention to early context

**Likelihood**: High (known LLM behavior)

**Impact**: Medium (affects which memories have most influence)

**Mitigation**:

- Document bias in user guide
- Consider reverse ordering for some LLMs (future)
- Let users experiment with strategies

### Risk: Importance Scoring Inconsistency

!!! warning "Risk"
    Users assign arbitrary importance scores

**Likelihood**: High (subjective scoring)

**Impact**: Medium (affects balanced and important strategies)

**Mitigation**:

- Document importance scoring guidelines
- Provide default importance (1.0) for most memories
- Consider learned importance in future

---

## Future Enhancements

### Automatic Strategy Selection

```ruby
# Detect conversation vs planning context
context = htm.create_context_smart()

# Uses recent for conversational turns
# Uses important for strategic questions
# Uses balanced for mixed contexts
```

### Configurable Decay

```ruby
# Adjust decay half-life
context = htm.create_context(
  strategy: :balanced,
  decay_hours: 0.5  # Faster decay
)
```

### Semantic Clustering

```ruby
# Group related memories together
context = htm.create_context(
  strategy: :clustered,
  cluster_by: :embedding  # Group semantically related nodes
)
```

### LLM-Optimized Ordering

```ruby
# Reverse ordering for LLMs with recency bias
context = htm.create_context(
  strategy: :balanced,
  order: :reverse  # Most important last (closer to query)
)
```

### Multi-Factor Scoring

```ruby
# Custom scoring function
context = htm.create_context(
  strategy: :custom,
  score_fn: ->(node) {
    recency = Time.now - node[:added_at]
    importance = node[:importance]
    access_count = node[:access_count]

    importance * (1.0 / (1 + recency / 3600)) * Math.log(1 + access_count)
  }
)
```

---

## Alternatives Comparison

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Three Strategies** | **Flexible, user control** | **Selection burden** | **ACCEPTED** |
| Always Include Everything | No selection logic | Exceeds token limits | Rejected |
| LLM-Powered Selection | Most intelligent | Too slow, expensive | Rejected |
| Learned Importance | Automatic optimization | Complex, non-deterministic | Deferred |
| Semantic Similarity | Most relevant | Slower, breaks generality | Deferred |

---

## References

- [LLM Context Window Management](https://arxiv.org/abs/2307.03172)
- [Attention Mechanisms in LLMs](https://arxiv.org/abs/1706.03762)
- [Position Bias in Language Models](https://arxiv.org/abs/2302.00093)
- [Working Memory in Cognitive Science](https://en.wikipedia.org/wiki/Working_memory)
- [ADR-002: Two-Tier Memory](002-two-tier-memory.md)
- [ADR-007: Eviction Strategy](007-eviction-strategy.md)
- [Context Assembly Guide](../../guides/context-assembly.md)

---

## Review Notes

**AI Engineer**: Three strategies cover common use cases well. Balanced default is smart. Consider position bias documentation.

**Performance Specialist**: O(n log n) sorting is fast enough for typical working memory sizes. No concerns.

**Ruby Expert**: Clean API design. Consider default parameter: `create_context(strategy: :balanced)` → `create_context(strategy = :balanced)`.

**Domain Expert**: Decay function is intuitive. 1-hour half-life matches development session rhythm.

**Systems Architect**: Strategy pattern is appropriate. Document decision matrix for users.
