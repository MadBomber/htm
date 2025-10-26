# LongTermMemory Class

PostgreSQL/TimescaleDB-backed permanent memory storage with RAG-based retrieval.

## Overview

`HTM::LongTermMemory` provides durable storage for all memory nodes with advanced search capabilities:

- **Vector similarity search** - Semantic understanding via embeddings
- **Full-text search** - Fast keyword and phrase matching
- **Hybrid search** - Combines fulltext prefiltering with vector ranking
- **Time-range queries** - TimescaleDB-optimized temporal search
- **Relationship graphs** - Connect related knowledge
- **Tag system** - Flexible categorization
- **Multi-robot tracking** - Shared global memory

## Class Definition

```ruby
class HTM::LongTermMemory
  # No public attributes
end
```

## Initialization

### `new(config)` {: #new }

Create a new long-term memory instance.

```ruby
HTM::LongTermMemory.new(config)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `config` | Hash | PostgreSQL connection configuration |

#### Configuration Hash

```ruby
{
  host: "hostname",
  port: 5432,
  dbname: "database_name",
  user: "username",
  password: "password",
  sslmode: "require"  # or "prefer", "disable"
}
```

#### Returns

- `HTM::LongTermMemory` instance

#### Raises

- `RuntimeError` - If config is nil

#### Examples

```ruby
# From environment variable
config = HTM::Database.default_config
ltm = HTM::LongTermMemory.new(config)

# Custom configuration
ltm = HTM::LongTermMemory.new(
  host: 'localhost',
  port: 5432,
  dbname: 'htm_production',
  user: 'htm_user',
  password: ENV['DB_PASSWORD'],
  sslmode: 'require'
)

# TimescaleDB Cloud
ltm = HTM::LongTermMemory.new(
  host: 'xxx.tsdb.cloud.timescale.com',
  port: 37807,
  dbname: 'tsdb',
  user: 'tsdbadmin',
  password: ENV['HTM_DBPASS'],
  sslmode: 'require'
)
```

---

## Public Methods

### `add(**params)` {: #add }

Add a node to long-term memory.

```ruby
add(
  key:,
  value:,
  type: nil,
  category: nil,
  importance: 1.0,
  token_count: 0,
  robot_id:,
  embedding:
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `key` | String | *required* | Unique node identifier |
| `value` | String | *required* | Node content |
| `type` | String, nil | `nil` | Node type |
| `category` | String, nil | `nil` | Node category |
| `importance` | Float | `1.0` | Importance score (0.0-10.0) |
| `token_count` | Integer | `0` | Token count |
| `robot_id` | String | *required* | Robot identifier |
| `embedding` | Array\<Float\> | *required* | Vector embedding |

#### Returns

- `Integer` - Database ID of the created node

#### Examples

```ruby
embedding = embedding_service.embed("content...")

node_id = ltm.add(
  key: "fact_001",
  value: "PostgreSQL is our primary database",
  type: "fact",
  category: "architecture",
  importance: 8.0,
  token_count: 50,
  robot_id: "robot-abc123",
  embedding: embedding
)
# => 1234

# Minimal add
node_id = ltm.add(
  key: "simple_note",
  value: "Remember to check logs",
  robot_id: robot_id,
  embedding: embedding
)
```

#### Notes

- `key` must be unique (enforced by database)
- `embedding` is stored as a pgvector type
- Automatically sets `created_at` timestamp

---

### `retrieve(key)` {: #retrieve }

Retrieve a node by its key.

```ruby
retrieve(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Node identifier |

#### Returns

- `Hash` - Node data if found
- `nil` - If node doesn't exist

#### Hash Structure

```ruby
{
  "id" => "123",
  "key" => "fact_001",
  "value" => "content...",
  "type" => "fact",
  "category" => "architecture",
  "importance" => "8.0",
  "token_count" => "50",
  "robot_id" => "robot-abc123",
  "created_at" => "2025-01-15 10:30:00",
  "last_accessed" => "2025-01-15 14:20:00",
  "in_working_memory" => "t",
  "evicted_at" => nil
}
```

#### Examples

```ruby
node = ltm.retrieve("fact_001")

if node
  puts node['value']
  puts "Created: #{node['created_at']}"
  puts "Importance: #{node['importance']}"
else
  puts "Node not found"
end
```

---

### `update_last_accessed(key)` {: #update_last_accessed }

Update the last accessed timestamp for a node.

```ruby
update_last_accessed(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Node identifier |

#### Returns

- `void`

#### Examples

```ruby
# After retrieving a node
node = ltm.retrieve("important_fact")
ltm.update_last_accessed("important_fact")

# Track access patterns
accessed_keys = ["key1", "key2", "key3"]
accessed_keys.each { |k| ltm.update_last_accessed(k) }
```

---

### `delete(key)` {: #delete }

Delete a node permanently.

```ruby
delete(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Node identifier |

#### Returns

- `void`

#### Side Effects

- Deletes node from database
- Cascades to related relationships and tags

#### Examples

```ruby
# Delete a node
ltm.delete("temp_note_123")

# Safe deletion
if ltm.retrieve("old_key")
  ltm.delete("old_key")
end
```

#### Warning

Deletion is **permanent** and cannot be undone. Use `HTM#forget` instead for proper confirmation flow.

---

### `get_node_id(key)` {: #get_node_id }

Get the database ID for a node.

```ruby
get_node_id(key)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | String | Node identifier |

#### Returns

- `Integer` - Database ID if found
- `nil` - If node doesn't exist

#### Examples

```ruby
node_id = ltm.get_node_id("fact_001")
# => 123

# Use in relationships
from_id = ltm.get_node_id("decision_001")
to_id = ltm.get_node_id("fact_001")
```

---

### `search(**params)` {: #search }

Vector similarity search using embeddings.

```ruby
search(
  timeframe:,
  query:,
  limit:,
  embedding_service:
)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|---------|
| `timeframe` | Range | Time range to search (Time..Time) |
| `query` | String | Search query text |
| `limit` | Integer | Maximum results |
| `embedding_service` | Object | Service to generate query embedding |

#### Returns

- `Array<Hash>` - Matching nodes sorted by similarity (highest first)

#### Hash Structure

```ruby
{
  "id" => "123",
  "key" => "fact_001",
  "value" => "content...",
  "type" => "fact",
  "category" => "architecture",
  "importance" => "8.0",
  "created_at" => "2025-01-15 10:30:00",
  "robot_id" => "robot-abc123",
  "token_count" => "50",
  "similarity" => "0.8745"  # 0.0-1.0, higher = more similar
}
```

#### Examples

```ruby
# Semantic search
timeframe = (Time.now - 7*24*3600)..Time.now

results = ltm.search(
  timeframe: timeframe,
  query: "database performance optimization",
  limit: 20,
  embedding_service: embedding_service
)

results.each do |node|
  puts "[#{node['similarity']}] #{node['value']}"
end

# Find similar to a specific concept
results = ltm.search(
  timeframe: (Time.at(0)..Time.now),  # All time
  query: "microservices architecture patterns",
  limit: 10,
  embedding_service: embedding_service
)

# Filter by similarity threshold
high_similarity = results.select { |n| n['similarity'].to_f > 0.7 }
```

#### Technical Details

- Uses pgvector's `<=>` cosine distance operator
- Returns `1 - distance` as similarity (0.0-1.0)
- Indexed for fast approximate nearest neighbor search
- Query embedding is generated on-the-fly

---

### `search_fulltext(**params)` {: #search_fulltext }

Full-text search using PostgreSQL's text search.

```ruby
search_fulltext(
  timeframe:,
  query:,
  limit:
)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `timeframe` | Range | Time range to search |
| `query` | String | Search query |
| `limit` | Integer | Maximum results |

#### Returns

- `Array<Hash>` - Matching nodes sorted by rank (highest first)

#### Hash Structure

Similar to `search`, but with `"rank"` instead of `"similarity"`:

```ruby
{
  ...,
  "rank" => "0.456"  # Higher = better match
}
```

#### Examples

```ruby
# Exact phrase search
results = ltm.search_fulltext(
  timeframe: (Time.now - 30*24*3600)..Time.now,
  query: "PostgreSQL connection pooling",
  limit: 10
)

# Multiple keywords
results = ltm.search_fulltext(
  timeframe: (Time.now - 7*24*3600)..Time.now,
  query: "API authentication JWT token",
  limit: 20
)

# Find mentions
results = ltm.search_fulltext(
  timeframe: (Time.at(0)..Time.now),
  query: "security vulnerability",
  limit: 50
)

results.each do |node|
  puts "[#{node['rank']}] #{node['created_at']}: #{node['value']}"
end
```

#### Technical Details

- Uses PostgreSQL `to_tsvector` and `plainto_tsquery`
- English language stemming and stop words
- GIN index for fast search
- Ranks by `ts_rank` (term frequency)

---

### `search_hybrid(**params)` {: #search_hybrid }

Hybrid search combining fulltext prefiltering with vector ranking.

```ruby
search_hybrid(
  timeframe:,
  query:,
  limit:,
  embedding_service:,
  prefilter_limit: 100
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `timeframe` | Range | *required* | Time range to search |
| `query` | String | *required* | Search query |
| `limit` | Integer | *required* | Maximum final results |
| `embedding_service` | Object | *required* | Service for embeddings |
| `prefilter_limit` | Integer | `100` | Fulltext candidates to consider |

#### Returns

- `Array<Hash>` - Matching nodes sorted by vector similarity

#### Strategy

1. **Prefilter**: Use fulltext search to find `prefilter_limit` candidates
2. **Rank**: Compute vector similarity for candidates only
3. **Return**: Top `limit` results by similarity

This combines the **accuracy** of fulltext with the **semantic understanding** of vectors.

#### Examples

```ruby
# Best of both worlds
results = ltm.search_hybrid(
  timeframe: (Time.now - 30*24*3600)..Time.now,
  query: "API rate limiting implementation",
  limit: 15,
  embedding_service: embedding_service,
  prefilter_limit: 100
)

# Adjust prefilter for performance
results = ltm.search_hybrid(
  timeframe: timeframe,
  query: "security best practices",
  limit: 20,
  embedding_service: embedding_service,
  prefilter_limit: 50  # Smaller = faster
)

# Large candidate pool for better recall
results = ltm.search_hybrid(
  timeframe: timeframe,
  query: "deployment strategies",
  limit: 10,
  embedding_service: embedding_service,
  prefilter_limit: 200  # Larger = better recall
)
```

#### Performance Tuning

| `prefilter_limit` | Speed | Recall | Use Case |
|-------------------|-------|--------|----------|
| 50 | Fast | Low | Common queries |
| 100 | Medium | Medium | Default (recommended) |
| 200+ | Slow | High | Rare/complex queries |

---

### `add_relationship(**params)` {: #add_relationship }

Add a relationship between two nodes.

```ruby
add_relationship(
  from:,
  to:,
  type: nil,
  strength: 1.0
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `from` | String | *required* | From node key |
| `to` | String | *required* | To node key |
| `type` | String, nil | `nil` | Relationship type |
| `strength` | Float | `1.0` | Relationship strength (0.0-1.0) |

#### Returns

- `void`

#### Side Effects

- Inserts relationship into `relationships` table
- Skips if relationship already exists (ON CONFLICT DO NOTHING)
- Returns early if either node doesn't exist

#### Examples

```ruby
# Simple relationship
ltm.add_relationship(
  from: "decision_001",
  to: "fact_001"
)

# Typed relationship with strength
ltm.add_relationship(
  from: "api_v2",
  to: "api_v1",
  type: "replaces",
  strength: 0.9
)

# Build knowledge graph
ltm.add_relationship(from: "microservices", to: "docker", type: "requires")
ltm.add_relationship(from: "microservices", to: "api_gateway", type: "requires")
ltm.add_relationship(from: "microservices", to: "service_mesh", type: "optional")

# Related decisions
ltm.add_relationship(
  from: "database_choice",
  to: "timescaledb_decision",
  type: "influences",
  strength: 0.8
)
```

---

### `add_tag(**params)` {: #add_tag }

Add a tag to a node.

```ruby
add_tag(node_id:, tag:)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |
| `tag` | String | Tag name |

#### Returns

- `void`

#### Side Effects

- Inserts tag into `tags` table
- Skips if tag already exists (ON CONFLICT DO NOTHING)

#### Examples

```ruby
node_id = ltm.add(key: "fact_001", ...)

# Add single tag
ltm.add_tag(node_id: node_id, tag: "architecture")

# Add multiple tags
["architecture", "database", "postgresql"].each do |tag|
  ltm.add_tag(node_id: node_id, tag: tag)
end

# Categorize decision
decision_id = ltm.add(key: "decision_001", ...)
ltm.add_tag(node_id: decision_id, tag: "critical")
ltm.add_tag(node_id: decision_id, tag: "security")
ltm.add_tag(node_id: decision_id, tag: "2025-q1")
```

---

### `mark_evicted(keys)` {: #mark_evicted }

Mark nodes as evicted from working memory.

```ruby
mark_evicted(keys)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `keys` | Array\<String\> | Node keys to mark |

#### Returns

- `void`

#### Side Effects

- Sets `in_working_memory = FALSE` for specified nodes
- Sets `evicted_at` timestamp

#### Examples

```ruby
# Mark single eviction
ltm.mark_evicted(["temp_note_123"])

# Mark batch eviction
evicted_keys = ["key1", "key2", "key3"]
ltm.mark_evicted(evicted_keys)

# From working memory eviction
evicted = working_memory.evict_to_make_space(10000)
evicted_keys = evicted.map { |n| n[:key] }
ltm.mark_evicted(evicted_keys) unless evicted_keys.empty?
```

---

### `register_robot(robot_id, robot_name)` {: #register_robot }

Register a robot in the system.

```ruby
register_robot(robot_id, robot_name)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `robot_id` | String | Robot identifier |
| `robot_name` | String | Robot name |

#### Returns

- `void`

#### Side Effects

- Inserts robot into `robots` table
- Updates name and `last_active` if robot exists

#### Examples

```ruby
ltm.register_robot("robot-abc123", "Code Assistant")
ltm.register_robot("robot-def456", "Research Bot")

# Register with UUID
robot_id = SecureRandom.uuid
ltm.register_robot(robot_id, "Analysis Bot")
```

---

### `update_robot_activity(robot_id)` {: #update_robot_activity }

Update robot's last activity timestamp.

```ruby
update_robot_activity(robot_id)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `robot_id` | String | Robot identifier |

#### Returns

- `void`

#### Examples

```ruby
# Update after operations
ltm.update_robot_activity("robot-abc123")

# Automatic heartbeat
loop do
  ltm.update_robot_activity(robot_id)
  sleep 60  # Every minute
end
```

---

### `log_operation(**params)` {: #log_operation }

Log an operation to the operations log.

```ruby
log_operation(
  operation:,
  node_id:,
  robot_id:,
  details:
)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|---------|
| `operation` | String | Operation type |
| `node_id` | Integer, nil | Node database ID (can be nil) |
| `robot_id` | String | Robot identifier |
| `details` | Hash | Operation details (stored as JSON) |

#### Returns

- `void`

#### Examples

```ruby
# Log add operation
ltm.log_operation(
  operation: 'add',
  node_id: 123,
  robot_id: robot_id,
  details: { key: "fact_001", type: "fact" }
)

# Log recall operation
ltm.log_operation(
  operation: 'recall',
  node_id: nil,
  robot_id: robot_id,
  details: {
    timeframe: "last week",
    topic: "postgresql",
    count: 15
  }
)

# Log forget operation
ltm.log_operation(
  operation: 'forget',
  node_id: 456,
  robot_id: robot_id,
  details: { key: "temp_note", reason: "temporary" }
)
```

---

### `stats()` {: #stats }

Get comprehensive memory statistics.

```ruby
stats()
```

#### Returns

- `Hash` - Statistics hash

#### Hash Structure

```ruby
{
  total_nodes: 1234,

  nodes_by_robot: {
    "robot-abc123" => 500,
    "robot-def456" => 734
  },

  nodes_by_type: [
    { "type" => "fact", "count" => 400, "avg_importance" => 6.5 },
    { "type" => "decision", "count" => 200, "avg_importance" => 8.2 },
    ...
  ],

  total_relationships: 567,
  total_tags: 890,

  oldest_memory: "2025-01-01 12:00:00",
  newest_memory: "2025-01-15 14:30:00",

  active_robots: 3,

  robot_activity: [
    { "id" => "robot-1", "name" => "Assistant", "last_active" => "2025-01-15 14:00:00" },
    ...
  ],

  database_size: 12345678  # bytes
}
```

#### Examples

```ruby
stats = ltm.stats

puts "Total memories: #{stats[:total_nodes]}"
puts "Robots: #{stats[:active_robots]}"
puts "Relationships: #{stats[:total_relationships]}"
puts "Tags: #{stats[:total_tags]}"

# By type
stats[:nodes_by_type].each do |type_info|
  puts "#{type_info['type']}: #{type_info['count']} nodes, avg importance #{type_info['avg_importance']}"
end

# Database size
size_mb = stats[:database_size] / 1024.0 / 1024.0
puts "Database size: #{size_mb.round(2)} MB"

# Robot activity
stats[:robot_activity].each do |robot|
  puts "#{robot['name']}: last active #{robot['last_active']}"
end
```

---

## Database Schema Reference

### Tables Used

#### `nodes`

Primary memory storage:

- `id` - Serial primary key
- `key` - Unique text identifier
- `value` - Text content
- `type` - Optional type
- `category` - Optional category
- `importance` - Float (0.0-10.0)
- `token_count` - Integer
- `robot_id` - Foreign key to robots
- `embedding` - Vector (pgvector)
- `created_at` - Timestamp
- `last_accessed` - Timestamp
- `in_working_memory` - Boolean
- `evicted_at` - Timestamp (nullable)

#### `relationships`

Node relationships:

- `id` - Serial primary key
- `from_node_id` - Foreign key to nodes
- `to_node_id` - Foreign key to nodes
- `relationship_type` - Optional type
- `strength` - Float (0.0-1.0)
- `created_at` - Timestamp

#### `tags`

Node tags:

- `id` - Serial primary key
- `node_id` - Foreign key to nodes
- `tag` - Text
- `created_at` - Timestamp

#### `robots`

Robot registry:

- `id` - Text primary key
- `name` - Text
- `created_at` - Timestamp
- `last_active` - Timestamp

#### `operations_log`

Operation audit log:

- `id` - Serial primary key
- `operation` - Text
- `node_id` - Foreign key to nodes (nullable)
- `robot_id` - Foreign key to robots
- `timestamp` - Timestamp
- `details` - JSONB

### Views

#### `node_stats`

Aggregated statistics by type:

```sql
SELECT type, COUNT(*) as count, AVG(importance) as avg_importance
FROM nodes
GROUP BY type
```

#### `robot_activity`

Robot activity summary:

```sql
SELECT id, name, last_active
FROM robots
ORDER BY last_active DESC
```

---

## Performance Considerations

### Indexing

Automatic indexes:

- `nodes.key` - Unique index for fast retrieval
- `nodes.embedding` - IVFFlat index for vector search
- `nodes.value` - GIN index for fulltext search
- `nodes.created_at` - B-tree index for time-range queries
- `relationships (from_node_id, to_node_id, relationship_type)` - Unique index

### Query Optimization

```ruby
# Good: Time-limited searches
ltm.search(timeframe: (Time.now - 7*24*3600)..Time.now, ...)

# Bad: All-time searches (slow)
ltm.search(timeframe: (Time.at(0)..Time.now), ...)

# Good: Reasonable limits
ltm.search_fulltext(query: "...", limit: 20)

# Bad: Unlimited results
ltm.search_fulltext(query: "...", limit: 10000)
```

### Connection Management

Each method call:

1. Opens a new PostgreSQL connection
2. Executes the query
3. Closes the connection

For bulk operations, this can be slow. Consider:

- Using connection pooling (future enhancement)
- Batching operations when possible
- Caching frequently accessed data

### TimescaleDB Optimization

The `nodes` table is a hypertable partitioned by `created_at`:

- Automatic data partitioning by time
- Compression for data older than 30 days
- Optimized for time-series queries

---

## Error Handling

### PG::Error

```ruby
# Connection errors
ltm = HTM::LongTermMemory.new(invalid_config)
# => PG::ConnectionBad

# Unique constraint violations
ltm.add(key: "existing_key", ...)
# => PG::UniqueViolation

# Foreign key violations
ltm.add_relationship(from: "nonexistent", to: "key")
# No error - returns early if nodes don't exist
```

### Best Practices

```ruby
# Wrap in rescue blocks
begin
  node_id = ltm.add(key: key, ...)
rescue PG::UniqueViolation
  # Key already exists
  node = ltm.retrieve(key)
  node_id = node['id'].to_i
end

# Check existence before operations
if ltm.retrieve(key)
  ltm.delete(key)
end

# Validate before adding relationships
from_exists = ltm.get_node_id(from_key)
to_exists = ltm.get_node_id(to_key)

if from_exists && to_exists
  ltm.add_relationship(from: from_key, to: to_key)
end
```

---

## See Also

- [HTM API](htm.md) - Main class that uses LongTermMemory
- [WorkingMemory API](working-memory.md) - Token-limited active context
- [EmbeddingService API](embedding-service.md) - Vector embedding generation
- [Database API](database.md) - Schema setup and configuration
