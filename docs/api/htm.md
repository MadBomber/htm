# HTM Class

The main interface for HTM's intelligent memory management system.

## Overview

`HTM` is the primary class that orchestrates the two-tier memory system:

- **Working Memory**: Token-limited active context for immediate LLM use
- **Long-term Memory**: Durable PostgreSQL storage

Key features:

- Never forgets unless explicitly told (`forget`)
- RAG-based retrieval (temporal + semantic search)
- Multi-robot "hive mind" - all robots share global memory
- Relationship graphs for knowledge connections
- Time-series optimized with TimescaleDB

## Class Definition

```ruby
class HTM
  attr_reader :robot_id, :robot_name, :working_memory, :long_term_memory
end
```

## Initialization

### `new(**options)` {: #new }

Create a new HTM instance.

```ruby
HTM.new(
  working_memory_size: 128_000,
  robot_id: nil,
  robot_name: nil,
  db_config: nil,
  embedding_service: :ollama,
  embedding_model: 'gpt-oss'
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `working_memory_size` | Integer | `128_000` | Maximum tokens for working memory |
| `robot_id` | String, nil | Auto-generated UUID | Unique identifier for this robot |
| `robot_name` | String, nil | `"robot_#{id[0..7]}"` | Human-readable name |
| `db_config` | Hash, nil | From `ENV['HTM_DBURL']` | Database configuration |
| `embedding_service` | Symbol | `:ollama` | Embedding provider (`:ollama`, `:openai`, `:cohere`, `:local`) |
| `embedding_model` | String | `'gpt-oss'` | Model name for embeddings |

#### Returns

- `HTM` instance

#### Examples

```ruby
# Basic initialization
htm = HTM.new(robot_name: "Code Assistant")

# Custom working memory size
htm = HTM.new(
  robot_name: "Large Context Bot",
  working_memory_size: 256_000
)

# OpenAI embeddings
htm = HTM.new(
  robot_name: "Research Bot",
  embedding_service: :openai,
  embedding_model: 'text-embedding-3-small'
)

# Custom database
htm = HTM.new(
  db_config: {
    host: 'localhost',
    port: 5432,
    dbname: 'htm_db',
    user: 'postgres',
    password: 'secret'
  }
)
```

---

## Instance Attributes

### `robot_id` {: #robot_id }

Unique identifier for this robot instance.

- **Type**: String (UUID format)
- **Read-only**: Yes

```ruby
htm.robot_id  # => "a1b2c3d4-e5f6-..."
```

### `robot_name` {: #robot_name }

Human-readable name for this robot.

- **Type**: String
- **Read-only**: Yes

```ruby
htm.robot_name  # => "Code Assistant"
```

### `working_memory` {: #working_memory }

The working memory instance.

- **Type**: `HTM::WorkingMemory`
- **Read-only**: Yes

```ruby
htm.working_memory.token_count  # => 45234
```

### `long_term_memory` {: #long_term_memory }

The long-term memory instance.

- **Type**: `HTM::LongTermMemory`
- **Read-only**: Yes

```ruby
htm.long_term_memory.stats  # => {...}
```

---

## Public Methods

### `add_node(key, value, **options)` {: #add_node }

Add a new memory node to both working and long-term memory.

```ruby
add_node(key, value,
  type: nil,
  category: nil,
  importance: 1.0,
  related_to: [],
  tags: []
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `key` | String | *required* | Unique identifier for this node |
| `value` | String | *required* | Content of the memory |
| `type` | Symbol, nil | `nil` | Memory type (`:fact`, `:context`, `:code`, `:preference`, `:decision`, `:question`) |
| `category` | String, nil | `nil` | Optional category for organization |
| `importance` | Float | `1.0` | Importance score (0.0-10.0) |
| `related_to` | Array\<String\> | `[]` | Keys of related nodes |
| `tags` | Array\<String\> | `[]` | Tags for categorization |

#### Returns

- `Integer` - Database ID of the created node

#### Side Effects

- Stores node in PostgreSQL with vector embedding
- Adds node to working memory (evicts if needed)
- Creates relationships to `related_to` nodes
- Adds tags to the node
- Logs operation to `operations_log` table
- Updates robot activity timestamp

#### Examples

```ruby
# Simple fact
htm.add_node("db_choice", "We chose PostgreSQL for its reliability")

# Architectural decision
htm.add_node(
  "api_gateway_decision",
  "Decided to use Kong as API gateway for rate limiting and auth",
  type: :decision,
  importance: 9.0,
  tags: ["architecture", "api", "gateway"],
  related_to: ["microservices_architecture"]
)

# Code snippet
code = <<~RUBY
  def calculate_total(items)
    items.sum(&:price)
  end
RUBY

htm.add_node(
  "total_calculation_v1",
  code,
  type: :code,
  category: "helpers",
  importance: 5.0,
  tags: ["ruby", "calculation"]
)

# User preference
htm.add_node(
  "user_123_timezone",
  "User prefers UTC timezone for all timestamps",
  type: :preference,
  category: "user_settings",
  importance: 6.0
)
```

#### Notes

- The `key` must be unique across all nodes
- Embeddings are generated automatically
- Token count is calculated automatically
- If working memory is full, less important nodes are evicted

---

### `recall(timeframe:, topic:, **options)` {: #recall }

Recall memories from a timeframe and topic using RAG-based retrieval.

```ruby
recall(
  timeframe:,
  topic:,
  limit: 20,
  strategy: :vector
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `timeframe` | String, Range | *required* | Time range (e.g., `"last week"`, `7.days.ago..Time.now`) |
| `topic` | String | *required* | Topic to search for |
| `limit` | Integer | `20` | Maximum number of nodes to retrieve |
| `strategy` | Symbol | `:vector` | Search strategy (`:vector`, `:fulltext`, `:hybrid`) |

#### Timeframe Formats

String format (natural language):

- `"last week"` - Last 7 days
- `"yesterday"` - Previous day
- `"last N days"` - Last N days (e.g., "last 30 days")
- `"this month"` - Current month to now
- `"last month"` - Previous calendar month
- Default (unrecognized) - Last 24 hours

Range format:

- `Time` range: `(Time.now - 7*24*3600)..Time.now`
- `Date` range: `Date.today-7..Date.today`

#### Search Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `:vector` | Semantic similarity using embeddings | Find conceptually related content |
| `:fulltext` | PostgreSQL full-text search | Find exact terms and phrases |
| `:hybrid` | Fulltext prefilter + vector ranking | Best accuracy + semantic understanding |

#### Returns

- `Array<Hash>` - Retrieved memory nodes

Each hash contains:

```ruby
{
  "id" => 123,                    # Database ID
  "key" => "node_key",            # Node identifier
  "value" => "content...",        # Node content
  "type" => "fact",               # Node type
  "category" => "architecture",   # Category
  "importance" => 8.0,            # Importance score
  "created_at" => "2025-01-15...", # Creation timestamp
  "robot_id" => "abc123...",      # Robot that created it
  "token_count" => 125,           # Token count
  "similarity" => 0.87            # Similarity score (vector/hybrid only)
  # or "rank" => 0.456            # Rank score (fulltext only)
}
```

#### Side Effects

- Adds recalled nodes to working memory
- Evicts existing nodes if working memory is full
- Logs operation to `operations_log` table
- Updates robot activity timestamp

#### Examples

```ruby
# Vector semantic search
memories = htm.recall(
  timeframe: "last week",
  topic: "database performance optimization"
)

# Fulltext search for exact phrases
memories = htm.recall(
  timeframe: "last 30 days",
  topic: "PostgreSQL connection pooling",
  strategy: :fulltext,
  limit: 10
)

# Hybrid search (best of both)
memories = htm.recall(
  timeframe: "this month",
  topic: "API rate limiting implementation",
  strategy: :hybrid,
  limit: 15
)

# Custom time range
start_time = Time.new(2025, 1, 1)
end_time = Time.now

memories = htm.recall(
  timeframe: start_time..end_time,
  topic: "security vulnerabilities",
  limit: 50
)

# Process results
memories.each do |memory|
  puts "#{memory['created_at']}: #{memory['value']}"
  puts "  Similarity: #{memory['similarity']}" if memory['similarity']
  puts "  Robot: #{memory['robot_id']}"
end
```

#### Performance Notes

- Vector search: Best for semantic understanding, requires embedding generation
- Fulltext search: Fastest for exact matches, no embedding overhead
- Hybrid search: Slower but most accurate, combines both approaches

---

### `retrieve(key)` {: #retrieve }

Retrieve a specific memory node by its key.

```ruby
retrieve(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Key of the node to retrieve |

#### Returns

- `Hash` - Node data if found
- `nil` - If node doesn't exist

#### Side Effects

- Updates `last_accessed` timestamp for the node
- Logs operation to `operations_log` table

#### Examples

```ruby
# Retrieve a node
node = htm.retrieve("api_decision_001")

if node
  puts node['value']
  puts "Created: #{node['created_at']}"
  puts "Importance: #{node['importance']}"
else
  puts "Node not found"
end

# Use retrieved data
config = htm.retrieve("database_config")
db_url = JSON.parse(config['value'])['url'] if config
```

---

### `forget(key, confirm:)` {: #forget }

Explicitly delete a memory node. Requires confirmation to prevent accidental deletion.

```ruby
forget(key, confirm: :confirmed)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Key of the node to delete |
| `confirm` | Symbol | Must be `:confirmed` to proceed |

#### Returns

- `true` - If successfully deleted

#### Raises

- `ArgumentError` - If `confirm` is not `:confirmed`

#### Side Effects

- Deletes node from PostgreSQL
- Removes node from working memory
- Logs operation before deletion
- Updates robot activity timestamp

#### Examples

```ruby
# Correct usage
htm.forget("temp_note_123", confirm: :confirmed)

# This will raise ArgumentError
htm.forget("temp_note_123")  # Missing confirm parameter

# Safe deletion with verification
if htm.retrieve("old_data")
  htm.forget("old_data", confirm: :confirmed)
  puts "Deleted old_data"
end
```

#### Notes

- This is the **only** way to delete data from HTM
- Deletion is permanent and cannot be undone
- Related relationships and tags are also deleted (CASCADE)

---

### `create_context(strategy:, max_tokens:)` {: #create_context }

Create a context string from working memory for LLM consumption.

```ruby
create_context(strategy: :balanced, max_tokens: nil)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strategy` | Symbol | `:balanced` | Assembly strategy |
| `max_tokens` | Integer, nil | Working memory max | Optional token limit |

#### Assembly Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `:recent` | Most recently accessed first | Prioritize latest information |
| `:important` | Highest importance scores first | Focus on critical information |
| `:balanced` | Weighted by importance × recency | Best general-purpose strategy |

#### Returns

- `String` - Assembled context with nodes separated by `"\n\n"`

#### Examples

```ruby
# Balanced context (default)
context = htm.create_context(strategy: :balanced)

# Recent context with token limit
context = htm.create_context(
  strategy: :recent,
  max_tokens: 50_000
)

# Important context only
context = htm.create_context(strategy: :important)

# Use in LLM prompt
prompt = <<~PROMPT
  You are a helpful assistant.

  Context from memory:
  #{context}

  User question: #{user_input}
PROMPT
```

#### Notes

- Nodes are concatenated with double newlines
- Token limits are respected (stops adding when limit reached)
- Empty string if working memory is empty

---

### `memory_stats()` {: #memory_stats }

Get comprehensive statistics about memory usage.

```ruby
memory_stats()
```

#### Returns

- `Hash` - Statistics hash

Structure:

```ruby
{
  robot_id: "abc123...",
  robot_name: "Assistant",

  # Long-term memory stats
  total_nodes: 1234,
  nodes_by_robot: {
    "robot-1" => 500,
    "robot-2" => 734
  },
  nodes_by_type: [
    {"type" => "fact", "count" => 400},
    {"type" => "decision", "count" => 200},
    ...
  ],
  total_relationships: 567,
  total_tags: 890,
  oldest_memory: "2025-01-01 12:00:00",
  newest_memory: "2025-01-15 14:30:00",
  active_robots: 3,
  robot_activity: [...],
  database_size: 12345678,

  # Working memory stats
  working_memory: {
    current_tokens: 45234,
    max_tokens: 128000,
    utilization: 35.34,
    node_count: 23
  }
}
```

#### Examples

```ruby
stats = htm.memory_stats

puts "Total memories: #{stats[:total_nodes]}"
puts "Working memory: #{stats[:working_memory][:utilization]}% full"
puts "Active robots: #{stats[:active_robots]}"

# Check if working memory is getting full
if stats[:working_memory][:utilization] > 80
  puts "Warning: Working memory is #{stats[:working_memory][:utilization]}% full"
end

# Display by robot
stats[:nodes_by_robot].each do |robot_id, count|
  puts "#{robot_id}: #{count} nodes"
end
```

---

### `which_robot_said(topic, limit:)` {: #which_robot_said }

Find which robots have discussed a specific topic.

```ruby
which_robot_said(topic, limit: 100)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `topic` | String | *required* | Topic to search for |
| `limit` | Integer | `100` | Maximum results to consider |

#### Returns

- `Hash` - Robot IDs mapped to mention counts

```ruby
{
  "robot-abc123" => 15,
  "robot-def456" => 8,
  "robot-ghi789" => 3
}
```

#### Examples

```ruby
# Find who discussed deployment
robots = htm.which_robot_said("deployment")
# => {"robot-1" => 12, "robot-2" => 5}

# Top contributor
top_robot, count = robots.max_by { |robot, count| count }
puts "#{top_robot} mentioned it #{count} times"

# Check if specific robot discussed it
if robots.key?("robot-123")
  puts "Robot-123 discussed deployment #{robots['robot-123']} times"
end
```

---

### `conversation_timeline(topic, limit:)` {: #conversation_timeline }

Get a chronological timeline of conversation about a topic.

```ruby
conversation_timeline(topic, limit: 50)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `topic` | String | *required* | Topic to search for |
| `limit` | Integer | `50` | Maximum results |

#### Returns

- `Array<Hash>` - Timeline entries sorted by timestamp

Structure:

```ruby
[
  {
    timestamp: "2025-01-15 10:30:00",
    robot: "robot-abc123",
    content: "We should consider PostgreSQL...",
    type: "decision"
  },
  {
    timestamp: "2025-01-15 11:45:00",
    robot: "robot-def456",
    content: "Agreed, PostgreSQL has better...",
    type: "fact"
  },
  ...
]
```

#### Examples

```ruby
# Get timeline
timeline = htm.conversation_timeline("API design", limit: 20)

# Display timeline
timeline.each do |entry|
  puts "[#{entry[:timestamp]}] #{entry[:robot]}:"
  puts "  #{entry[:content]}"
  puts "  (#{entry[:type]})"
  puts
end

# Find first mention
first = timeline.first
puts "First discussed by #{first[:robot]} at #{first[:timestamp]}"

# Group by robot
by_robot = timeline.group_by { |e| e[:robot] }
by_robot.each do |robot, entries|
  puts "#{robot}: #{entries.size} contributions"
end
```

---

## Error Handling

### ArgumentError

```ruby
# Invalid confirm parameter
htm.forget("key")
# => ArgumentError: Must pass confirm: :confirmed to delete

# Invalid timeframe
htm.recall(timeframe: nil, topic: "test")
# => ArgumentError: Invalid timeframe: nil
```

### PG::Error

```ruby
# Database connection issues
htm = HTM.new(db_config: { host: 'invalid' })
# => PG::ConnectionBad: could not translate host name...

# Duplicate key
htm.add_node("existing_key", "value")
# => PG::UniqueViolation: duplicate key value...
```

## Best Practices

### Memory Organization

```ruby
# Use consistent key naming
htm.add_node("decision_20250115_api_gateway", ...)
htm.add_node("fact_20250115_database_choice", ...)

# Use importance strategically
htm.add_node(key, value, importance: 9.0)  # Critical
htm.add_node(key, value, importance: 5.0)  # Normal
htm.add_node(key, value, importance: 2.0)  # Low priority

# Build knowledge graphs
htm.add_node(
  "api_v2_implementation",
  "...",
  related_to: ["api_v1_design", "authentication_decision"]
)
```

### Search Strategies

```ruby
# Use vector for semantic understanding
memories = htm.recall(
  timeframe: "last month",
  topic: "performance issues",
  strategy: :vector  # Finds "slow queries", "optimization", etc.
)

# Use fulltext for exact terms
memories = htm.recall(
  timeframe: "this week",
  topic: "PostgreSQL EXPLAIN ANALYZE",
  strategy: :fulltext  # Exact match
)

# Use hybrid for best results
memories = htm.recall(
  timeframe: "last week",
  topic: "security vulnerability",
  strategy: :hybrid  # Accurate + semantic
)
```

### Resource Management

```ruby
# Check working memory before large operations
stats = htm.memory_stats
if stats[:working_memory][:utilization] > 90
  # Maybe explicitly recall less
end

# Use appropriate limits
htm.recall(topic: "common_topic", limit: 10)  # Not 1000

# Monitor database size
if stats[:database_size] > 1_000_000_000  # 1GB
  # Consider archival strategy
end
```

## See Also

- [WorkingMemory API](working-memory.md)
- [LongTermMemory API](long-term-memory.md)
- [EmbeddingService API](embedding-service.md)
- [Database API](database.md)
