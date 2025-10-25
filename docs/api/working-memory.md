# WorkingMemory Class

Token-limited active context for immediate LLM use.

## Overview

`HTM::WorkingMemory` manages the active conversation context within strict token limits. When capacity is reached, it intelligently evicts less important or older nodes back to long-term storage.

**Key Features:**

- Token-based capacity management
- LRU (Least Recently Used) tracking
- Importance-weighted eviction
- Multiple context assembly strategies
- Real-time utilization monitoring

## Class Definition

```ruby
class HTM::WorkingMemory
  attr_reader :max_tokens
end
```

## Initialization

### `new(max_tokens:)` {: #new }

Create a new working memory instance.

```ruby
HTM::WorkingMemory.new(max_tokens: 128_000)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_tokens` | Integer | *required* | Maximum tokens allowed in working memory |

#### Returns

- `HTM::WorkingMemory` instance

#### Examples

```ruby
# Standard working memory (128K tokens)
wm = HTM::WorkingMemory.new(max_tokens: 128_000)

# Large context window (256K tokens)
wm = HTM::WorkingMemory.new(max_tokens: 256_000)

# Small working memory (32K tokens)
wm = HTM::WorkingMemory.new(max_tokens: 32_000)
```

---

## Instance Attributes

### `max_tokens` {: #max_tokens }

Maximum token capacity for this working memory.

- **Type**: Integer
- **Read-only**: Yes

```ruby
wm.max_tokens  # => 128000
```

---

## Public Methods

### `add(key, value, **options)` {: #add }

Add a node to working memory.

```ruby
add(key, value,
  token_count:,
  importance: 1.0,
  from_recall: false
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `key` | String | *required* | Node identifier |
| `value` | String | *required* | Node content |
| `token_count` | Integer | *required* | Number of tokens in this node |
| `importance` | Float | `1.0` | Importance score (0.0-10.0) |
| `from_recall` | Boolean | `false` | Whether this node was recalled from long-term memory |

#### Returns

- `void`

#### Side Effects

- Adds node to internal hash
- Updates access order (LRU tracking)
- Records timestamp

#### Examples

```ruby
# Add a simple node
wm.add("fact_001", "PostgreSQL is our database",
  token_count: 50,
  importance: 7.0
)

# Add recalled node
wm.add("decision_001", "Use microservices architecture",
  token_count: 120,
  importance: 9.0,
  from_recall: true
)

# Add low-importance temporary note
wm.add("temp_note", "Check deployment at 3pm",
  token_count: 30,
  importance: 2.0
)
```

#### Notes

- Does **not** check capacity - use `has_space?` first
- Updates existing node if key already exists
- Automatically updates access order for LRU

---

### `remove(key)` {: #remove }

Remove a node from working memory.

```ruby
remove(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Node identifier |

#### Returns

- `void`

#### Side Effects

- Removes node from internal hash
- Removes from access order tracking

#### Examples

```ruby
# Remove a node
wm.remove("temp_note_123")

# Safe removal (checks existence)
if wm.respond_to?(:has_key?) && wm.has_key?("old_key")
  wm.remove("old_key")
end
```

---

### `has_space?(token_count)` {: #has_space }

Check if there's space for a node.

```ruby
has_space?(token_count)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `token_count` | Integer | Number of tokens needed |

#### Returns

- `Boolean` - `true` if space available, `false` otherwise

#### Examples

```ruby
# Check before adding
if wm.has_space?(500)
  wm.add("new_node", "content...", token_count: 500)
else
  puts "Working memory full, need to evict"
end

# Check capacity for large addition
large_content_tokens = 5000
if wm.has_space?(large_content_tokens)
  wm.add("large_node", large_content, token_count: large_content_tokens)
else
  # Evict to make space
  evicted = wm.evict_to_make_space(large_content_tokens)
  wm.add("large_node", large_content, token_count: large_content_tokens)
end
```

---

### `evict_to_make_space(needed_tokens)` {: #evict_to_make_space }

Evict nodes to free up space for new content.

```ruby
evict_to_make_space(needed_tokens)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `needed_tokens` | Integer | Number of tokens needed |

#### Returns

- `Array<Hash>` - Evicted nodes

Each hash contains:

```ruby
{
  key: "node_key",
  value: "node content..."
}
```

#### Eviction Strategy

Nodes are sorted by:

1. **Importance** (ascending) - Lower importance evicted first
2. **Recency** (descending) - Older nodes evicted first

Formula: `[importance, -recency_in_seconds]`

#### Side Effects

- Removes evicted nodes from working memory
- Updates access order tracking

#### Examples

```ruby
# Make space for 10,000 tokens
evicted = wm.evict_to_make_space(10_000)

puts "Evicted #{evicted.length} nodes:"
evicted.each do |node|
  puts "  - #{node[:key]}"
end

# Make space and log to long-term memory
evicted = wm.evict_to_make_space(needed_tokens)
evicted_keys = evicted.map { |n| n[:key] }
long_term_memory.mark_evicted(evicted_keys)

# Check how much was freed
tokens_freed = evicted.sum { |n| n[:token_count] }
puts "Freed #{tokens_freed} tokens"
```

#### Notes

- Evicts just enough to meet `needed_tokens`
- May evict more than one node
- Preserves high-importance and recent nodes

---

### `assemble_context(strategy:, max_tokens:)` {: #assemble_context }

Assemble context string for LLM consumption.

```ruby
assemble_context(strategy:, max_tokens: nil)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strategy` | Symbol | *required* | Assembly strategy (`:recent`, `:important`, `:balanced`) |
| `max_tokens` | Integer, nil | `@max_tokens` | Optional token limit |

#### Assembly Strategies

**`:recent`** - Most recently accessed first

```ruby
# Ordered by access time (newest first)
# Good for: Conversational continuity
```

**`:important`** - Highest importance scores first

```ruby
# Ordered by importance score (highest first)
# Good for: Critical information prioritization
```

**`:balanced`** - Weighted by importance and recency

```ruby
# Formula: importance × (1.0 / (1 + age_in_hours))
# Good for: General-purpose use (recommended)
```

#### Returns

- `String` - Assembled context with nodes separated by `"\n\n"`

#### Examples

```ruby
# Balanced context (recommended)
context = wm.assemble_context(strategy: :balanced)

# Recent conversations only
context = wm.assemble_context(strategy: :recent)

# Most important information
context = wm.assemble_context(strategy: :important)

# Limited tokens
context = wm.assemble_context(
  strategy: :balanced,
  max_tokens: 50_000
)

# Use in LLM prompt
prompt = <<~PROMPT
  Context:
  #{context}

  Question: #{user_question}
PROMPT
```

#### Balanced Strategy Details

The balanced strategy uses a decay function:

```ruby
score = importance × (1.0 / (1 + recency_in_hours))
```

Examples:

| Importance | Age | Score |
|------------|-----|-------|
| 10.0 | 1 hour | 5.0 |
| 10.0 | 5 hours | 1.67 |
| 5.0 | 1 hour | 2.5 |
| 5.0 | 5 hours | 0.83 |

---

### `token_count()` {: #token_count }

Get current total tokens in working memory.

```ruby
token_count()
```

#### Returns

- `Integer` - Total tokens across all nodes

#### Examples

```ruby
current = wm.token_count
puts "Using #{current} tokens"

# Check if near capacity
if wm.token_count > wm.max_tokens * 0.9
  puts "Warning: Working memory 90% full"
end

# Calculate available space
available = wm.max_tokens - wm.token_count
puts "#{available} tokens available"
```

---

### `utilization_percentage()` {: #utilization_percentage }

Get working memory utilization as a percentage.

```ruby
utilization_percentage()
```

#### Returns

- `Float` - Percentage of capacity used (0.0-100.0, rounded to 2 decimals)

#### Examples

```ruby
util = wm.utilization_percentage
puts "Working memory: #{util}% full"

# Capacity warnings
case util
when 0..50
  puts "Plenty of space"
when 51..80
  puts "Getting full"
when 81..95
  puts "Warning: High utilization"
else
  puts "Critical: Near capacity"
end

# Progress bar
bar_length = (util / 2).round
bar = "█" * bar_length + "░" * (50 - bar_length)
puts "[#{bar}] #{util}%"
```

---

### `node_count()` {: #node_count }

Get the number of nodes in working memory.

```ruby
node_count()
```

#### Returns

- `Integer` - Number of nodes currently stored

#### Examples

```ruby
count = wm.node_count
puts "#{count} nodes in working memory"

# Average tokens per node
if count > 0
  avg = wm.token_count / count
  puts "Average: #{avg} tokens per node"
end

# Density check
if wm.node_count > 100
  puts "Warning: Many small nodes, consider consolidation"
end
```

---

## Usage Patterns

### Capacity Management

```ruby
# Check capacity before operations
def add_with_eviction(wm, ltm, key, value, token_count, importance)
  unless wm.has_space?(token_count)
    # Evict and mark in long-term memory
    evicted = wm.evict_to_make_space(token_count)
    evicted_keys = evicted.map { |n| n[:key] }
    ltm.mark_evicted(evicted_keys) unless evicted_keys.empty?
  end

  wm.add(key, value,
    token_count: token_count,
    importance: importance
  )
end
```

### Monitoring

```ruby
# Working memory dashboard
def print_wm_status(wm)
  puts "Working Memory Status:"
  puts "  Nodes: #{wm.node_count}"
  puts "  Tokens: #{wm.token_count} / #{wm.max_tokens}"
  puts "  Utilization: #{wm.utilization_percentage}%"

  available = wm.max_tokens - wm.token_count
  puts "  Available: #{available} tokens"
end
```

### Strategic Context Assembly

```ruby
# Different contexts for different tasks
class ContextManager
  def initialize(wm)
    @wm = wm
  end

  def for_conversation
    # Recent context for chat continuity
    @wm.assemble_context(strategy: :recent, max_tokens: 8000)
  end

  def for_analysis
    # Important context for deep analysis
    @wm.assemble_context(strategy: :important, max_tokens: 32000)
  end

  def for_general_task
    # Balanced for most tasks
    @wm.assemble_context(strategy: :balanced)
  end
end
```

### Importance-Based Retention

```ruby
# Critical memories persist longer
wm.add("critical_security_alert",
  "SQL injection vulnerability found in user input",
  token_count: 150,
  importance: 10.0  # Maximum importance
)

# Temporary notes evicted first
wm.add("temp_reminder",
  "Check logs after deployment",
  token_count: 50,
  importance: 1.0  # Minimum importance
)
```

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| `add` | O(1) | Hash insertion + array append |
| `remove` | O(n) | Array deletion requires scan |
| `has_space?` | O(n) | Sums all token counts |
| `evict_to_make_space` | O(n log n) | Sorting nodes |
| `assemble_context` | O(n log n) | Sorting + concatenation |
| `token_count` | O(n) | Sums all nodes |
| `node_count` | O(1) | Hash size |

### Space Complexity

- O(n) where n is the number of nodes
- Each node stores: key, value, token_count, importance, timestamp, from_recall flag

### Optimization Tips

1. **Batch Operations**: Add multiple nodes before checking space
2. **Importance Scoring**: Use meaningful scores (1-10) for effective eviction
3. **Token Limits**: Set `max_tokens` based on your LLM's context window
4. **Strategy Selection**: Use `:recent` for speed, `:balanced` for quality

## Internal Data Structures

### Node Storage

```ruby
@nodes = {
  "key1" => {
    value: "content...",
    token_count: 150,
    importance: 7.0,
    added_at: Time.now,
    from_recall: false
  },
  "key2" => { ... }
}
```

### Access Order

```ruby
@access_order = ["key1", "key3", "key2"]
# Most recently accessed at the end
```

## Best Practices

### 1. Check Space Before Adding

```ruby
# Good
if wm.has_space?(tokens)
  wm.add(key, value, token_count: tokens)
else
  wm.evict_to_make_space(tokens)
  wm.add(key, value, token_count: tokens)
end

# Bad - may exceed capacity
wm.add(key, value, token_count: tokens)
```

### 2. Use Appropriate Importance Scores

```ruby
# Critical architectural decisions
importance: 10.0

# Important facts
importance: 7.0-8.0

# Normal information
importance: 4.0-6.0

# Temporary notes
importance: 1.0-3.0
```

### 3. Monitor Utilization

```ruby
# Set up alerts
if wm.utilization_percentage > 90
  warn "Working memory critically full"
end
```

### 4. Choose Right Strategy

```ruby
# For chat/conversation
context = wm.assemble_context(strategy: :recent)

# For analysis/reasoning
context = wm.assemble_context(strategy: :important)

# For general use
context = wm.assemble_context(strategy: :balanced)
```

## See Also

- [HTM API](htm.md) - Main class that uses WorkingMemory
- [LongTermMemory API](long-term-memory.md) - Persistent storage for evicted nodes
- [EmbeddingService API](embedding-service.md) - Token counting
