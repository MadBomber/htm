# LongTermMemory Class

PostgreSQL-backed permanent memory storage with RAG-based retrieval.

## Overview

`HTM::LongTermMemory` provides durable storage for all memory nodes with advanced search capabilities:

- **Vector similarity search** - Semantic understanding via embeddings
- **Full-text search** - Fast keyword and phrase matching
- **Tag-enhanced hybrid search** - Combines fulltext + vector + tag matching
- **Content deduplication** - SHA-256 based node deduplication
- **Query result caching** - LRU cache for frequent queries
- **Hierarchical tagging** - Colon-separated tag namespaces

## Class Definition

```ruby
class HTM::LongTermMemory
  attr_reader :query_timeout
end
```

## Initialization

### `new(config, **options)` {: #new }

Create a new long-term memory instance.

```ruby
HTM::LongTermMemory.new(
  config,
  pool_size: nil,
  query_timeout: 30_000,
  cache_size: 1000,
  cache_ttl: 300
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config` | Hash | *required* | PostgreSQL connection configuration |
| `pool_size` | Integer, nil | `nil` | Connection pool size (managed by ActiveRecord) |
| `query_timeout` | Integer | `30_000` | Query timeout in milliseconds |
| `cache_size` | Integer | `1000` | LRU cache size (0 to disable) |
| `cache_ttl` | Integer | `300` | Cache TTL in seconds |

#### Configuration Hash

```ruby
{
  host: "hostname",
  port: 5432,
  dbname: "database_name",
  user: "username",
  password: "password",
  sslmode: "require"
}
```

#### Examples

```ruby
# From environment variable
config = HTM::Database.default_config
ltm = HTM::LongTermMemory.new(config)

# With custom timeout and cache
ltm = HTM::LongTermMemory.new(
  config,
  query_timeout: 60_000,  # 60 seconds
  cache_size: 5000,
  cache_ttl: 600
)

# Disable caching
ltm = HTM::LongTermMemory.new(config, cache_size: 0)
```

---

## Public Methods

### `add(**params)` {: #add }

Add a node to long-term memory with content deduplication.

```ruby
add(
  content:,
  token_count: 0,
  robot_id:,
  embedding: nil
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | String | *required* | Node content |
| `token_count` | Integer | `0` | Token count |
| `robot_id` | Integer | *required* | Robot identifier |
| `embedding` | Array\<Float\>, nil | `nil` | Pre-generated embedding vector |

#### Returns

- `Hash` - `{ node_id:, is_new:, robot_node: }`

#### Content Deduplication

When `add()` is called:

1. A SHA-256 hash of the content is computed
2. If a node with the same hash exists:
   - Links the robot to the existing node (or updates `remember_count`)
   - Returns `is_new: false`
3. If no match:
   - Creates a new node
   - Links the robot to it
   - Returns `is_new: true`

#### Examples

```ruby
# Add new content
result = ltm.add(
  content: "PostgreSQL is our primary database",
  token_count: 8,
  robot_id: 1
)
# => { node_id: 123, is_new: true, robot_node: <RobotNode> }

# Add duplicate content (different robot)
result = ltm.add(
  content: "PostgreSQL is our primary database",
  token_count: 8,
  robot_id: 2
)
# => { node_id: 123, is_new: false, robot_node: <RobotNode> }
# Same node_id, robot_node tracks this robot's remember_count

# With pre-generated embedding
result = ltm.add(
  content: "Vector search is powerful",
  token_count: 5,
  robot_id: 1,
  embedding: [0.1, 0.2, 0.3, ...]  # Will be padded to 2000 dims
)
```

---

### `retrieve(node_id)` {: #retrieve }

Retrieve a node by its database ID.

```ruby
retrieve(node_id)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |

#### Returns

- `Hash` - Node attributes if found
- `nil` - If node doesn't exist

#### Side Effects

- Increments `access_count`
- Updates `last_accessed` timestamp

#### Examples

```ruby
node = ltm.retrieve(123)

if node
  puts node['content']
  puts "Accessed #{node['access_count']} times"
  puts "Created: #{node['created_at']}"
else
  puts "Node not found"
end
```

---

### `exists?(node_id)` {: #exists }

Check if a node exists.

```ruby
exists?(node_id)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |

#### Returns

- `Boolean` - True if node exists

#### Examples

```ruby
if ltm.exists?(123)
  ltm.delete(123)
end
```

---

### `delete(node_id)` {: #delete }

Delete a node permanently.

```ruby
delete(node_id)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |

#### Side Effects

- Deletes node from database
- Cascades to robot_nodes and node_tags
- Invalidates query cache

#### Warning

Deletion is **permanent** and cannot be undone. Use `HTM#forget` for proper confirmation flow.

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
|-----------|------|-------------|
| `timeframe` | Range | Time range to search (Time..Time) |
| `query` | String | Search query text |
| `limit` | Integer | Maximum results |
| `embedding_service` | Object | Service to generate query embedding |

#### Returns

- `Array<Hash>` - Matching nodes sorted by similarity (highest first)

#### Hash Structure

```ruby
{
  "id" => 123,
  "content" => "content...",
  "access_count" => 5,
  "created_at" => "2025-01-15 10:30:00",
  "token_count" => 50,
  "similarity" => 0.8745  # 0.0-1.0, higher = more similar
}
```

#### Examples

```ruby
timeframe = (Time.now - 7*24*3600)..Time.now

results = ltm.search(
  timeframe: timeframe,
  query: "database performance optimization",
  limit: 20,
  embedding_service: HTM
)

results.each do |node|
  puts "[#{node['similarity']}] #{node['content']}"
end
```

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

```ruby
{
  ...,
  "rank" => 0.456  # Higher = better match
}
```

#### Examples

```ruby
results = ltm.search_fulltext(
  timeframe: (Time.now - 30*24*3600)..Time.now,
  query: "PostgreSQL connection pooling",
  limit: 10
)
```

---

### `search_hybrid(**params)` {: #search_hybrid }

Tag-enhanced hybrid search combining fulltext, vector, and tag matching.

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
| `prefilter_limit` | Integer | `100` | Candidates to consider |

#### Returns

- `Array<Hash>` - Matching nodes with combined scores

#### Hash Structure

```ruby
{
  "id" => 123,
  "content" => "...",
  "similarity" => 0.87,       # Vector similarity (0-1)
  "tag_boost" => 0.3,         # Tag match score (0-1)
  "combined_score" => 0.79    # (similarity × 0.7) + (tag_boost × 0.3)
}
```

#### Strategy

1. **Find matching tags**: Searches tags for query term matches
2. **Build candidate pool**: Fulltext matches + tag-matching nodes
3. **Score candidates**: Vector similarity + tag boost
4. **Return top results**: Sorted by combined_score

#### Examples

```ruby
results = ltm.search_hybrid(
  timeframe: (Time.now - 30*24*3600)..Time.now,
  query: "PostgreSQL performance",
  limit: 15,
  embedding_service: HTM
)

results.each do |node|
  puts "#{node['content']}"
  puts "  Similarity: #{node['similarity']}"
  puts "  Tag boost: #{node['tag_boost']}"
  puts "  Combined: #{node['combined_score']}"
end
```

---

### `find_query_matching_tags(query)` {: #find_query_matching_tags }

Find tags that match terms in the query.

```ruby
find_query_matching_tags(query)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | String | Search query |

#### Returns

- `Array<String>` - Matching tag names

#### How It Works

1. Extracts words from query (3+ chars, lowercase)
2. Searches tags where any hierarchy level matches (ILIKE)
3. Returns all matching tag names

#### Examples

```ruby
# Query: "PostgreSQL database optimization"
# Might return: ["database:postgresql", "database:optimization", "database:sql"]

matching_tags = ltm.find_query_matching_tags("PostgreSQL database")
# => ["database:postgresql", "database:postgresql:extensions"]
```

---

### `add_tag(node_id:, tag:)` {: #add_tag }

Add a tag to a node.

```ruby
add_tag(node_id:, tag:)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |
| `tag` | String | Tag name |

#### Examples

```ruby
ltm.add_tag(node_id: 123, tag: "database:postgresql")
ltm.add_tag(node_id: 123, tag: "architecture:decision")
```

---

### `get_node_tags(node_id)` {: #get_node_tags }

Get tags for a specific node.

```ruby
get_node_tags(node_id)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | Node database ID |

#### Returns

- `Array<String>` - Tag names

#### Examples

```ruby
tags = ltm.get_node_tags(123)
# => ["database:postgresql", "architecture:decision"]
```

---

### `node_topics(node_id)` {: #node_topics }

Alias for `get_node_tags` - returns topics/tags for a node.

```ruby
node_topics(node_id)
```

---

### `nodes_by_topic(topic_path, exact:, limit:)` {: #nodes_by_topic }

Retrieve nodes by tag/topic.

```ruby
nodes_by_topic(topic_path, exact: false, limit: 50)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `topic_path` | String | *required* | Topic hierarchy path |
| `exact` | Boolean | `false` | Exact match or prefix match |
| `limit` | Integer | `50` | Maximum results |

#### Returns

- `Array<Hash>` - Matching node attributes

#### Examples

```ruby
# Prefix match (default) - finds all database-related nodes
nodes = ltm.nodes_by_topic("database")

# Exact match - only nodes tagged with exactly "database:postgresql"
nodes = ltm.nodes_by_topic("database:postgresql", exact: true)
```

---

### `search_by_tags(**params)` {: #search_by_tags }

Search nodes by tags with relevance scoring.

```ruby
search_by_tags(
  tags:,
  match_all: false,
  timeframe: nil,
  limit: 20
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tags` | Array\<String\> | *required* | Tags to search for |
| `match_all` | Boolean | `false` | Match ALL tags or ANY tag |
| `timeframe` | Range, nil | `nil` | Optional time range filter |
| `limit` | Integer | `20` | Maximum results |

#### Returns

- `Array<Hash>` - Nodes with relevance scores and tags

#### Examples

```ruby
# Match ANY tag
nodes = ltm.search_by_tags(tags: ["database", "api"])

# Match ALL tags
nodes = ltm.search_by_tags(
  tags: ["database:postgresql", "architecture"],
  match_all: true
)

# With timeframe
nodes = ltm.search_by_tags(
  tags: ["security"],
  timeframe: (Time.now - 7*24*3600)..Time.now
)
```

---

### `popular_tags(limit:, timeframe:)` {: #popular_tags }

Get most frequently used tags.

```ruby
popular_tags(limit: 20, timeframe: nil)
```

#### Returns

- `Array<Hash>` - `[{ name: "tag_name", usage_count: 42 }, ...]`

#### Examples

```ruby
top_tags = ltm.popular_tags(limit: 10)
top_tags.each do |tag|
  puts "#{tag[:name]}: #{tag[:usage_count]} nodes"
end
```

---

### `topic_relationships(min_shared_nodes:, limit:)` {: #topic_relationships }

Get tag co-occurrence relationships.

```ruby
topic_relationships(min_shared_nodes: 2, limit: 50)
```

#### Returns

- `Array<Hash>` - `[{ topic1:, topic2:, shared_nodes: }, ...]`

#### Examples

```ruby
related = ltm.topic_relationships(min_shared_nodes: 3)
related.each do |r|
  puts "#{r['topic1']} <-> #{r['topic2']}: #{r['shared_nodes']} shared"
end
```

---

### `register_robot(robot_name)` {: #register_robot }

Register a robot in the system.

```ruby
register_robot(robot_name)
```

#### Returns

- `Integer` - Robot ID

#### Examples

```ruby
robot_id = ltm.register_robot("Code Assistant")
```

---

### `update_robot_activity(robot_id)` {: #update_robot_activity }

Update robot's last activity timestamp.

```ruby
update_robot_activity(robot_id)
```

---

### `mark_evicted(node_ids)` {: #mark_evicted }

Mark nodes as evicted from working memory.

```ruby
mark_evicted(node_ids)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_ids` | Array\<Integer\> | Node IDs to mark |

---

### `track_access(node_ids)` {: #track_access }

Track access for multiple nodes (bulk update).

```ruby
track_access(node_ids)
```

Updates `access_count` and `last_accessed` for all specified nodes.

---

### `stats()` {: #stats }

Get comprehensive memory statistics.

```ruby
stats()
```

#### Returns

```ruby
{
  total_nodes: 1234,
  nodes_by_robot: { 1 => 500, 2 => 734 },
  total_tags: 890,
  oldest_memory: Time,
  newest_memory: Time,
  active_robots: 3,
  robot_activity: [{ id:, name:, last_active: }, ...],
  database_size: 12345678,  # bytes
  cache: {                  # Only if cache enabled
    hits: 150,
    misses: 50,
    hit_rate: 75.0,
    size: 200
  }
}
```

---

## Database Schema

### Tables Used

#### `nodes`

Primary memory storage:

- `id` - BIGSERIAL primary key
- `content` - TEXT (the memory content)
- `content_hash` - VARCHAR(64) UNIQUE (SHA-256 for deduplication)
- `access_count` - INTEGER (retrieval count)
- `token_count` - INTEGER
- `embedding` - vector(2000)
- `embedding_dimension` - INTEGER
- `created_at`, `updated_at`, `last_accessed` - TIMESTAMPTZ
- `in_working_memory` - BOOLEAN

#### `robot_nodes`

Robot-node associations (many-to-many):

- `id` - BIGSERIAL primary key
- `robot_id` - BIGINT FK
- `node_id` - BIGINT FK
- `first_remembered_at`, `last_remembered_at` - TIMESTAMPTZ
- `remember_count` - INTEGER

#### `tags`

Hierarchical tag registry:

- `id` - BIGSERIAL primary key
- `name` - TEXT UNIQUE (colon-separated hierarchy)
- `created_at` - TIMESTAMPTZ

#### `node_tags`

Node-tag associations (many-to-many):

- `node_id` - BIGINT FK
- `tag_id` - BIGINT FK

---

## Performance Considerations

### Query Caching

Results are cached in an LRU cache with TTL:

```ruby
# Check cache stats
stats = ltm.stats
puts "Cache hit rate: #{stats[:cache][:hit_rate]}%"
```

Cache is automatically invalidated when:
- Nodes are added
- Nodes are deleted

### Indexing

Automatic indexes:

- `content_hash` - UNIQUE index for deduplication
- `embedding` - HNSW index for vector search
- `content` - GIN indexes for fulltext and trigram search
- `created_at` - B-tree for time-range queries
- `robot_nodes` and `node_tags` - Indexes on foreign keys

### Query Optimization

```ruby
# Good: Time-limited searches
ltm.search(timeframe: (Time.now - 7*24*3600)..Time.now, ...)

# Bad: All-time searches (slow)
ltm.search(timeframe: (Time.at(0)..Time.now), ...)

# Good: Reasonable limits
ltm.search_fulltext(query: "...", limit: 20)
```

---

## Error Handling

### PG::Error

```ruby
# Connection errors
ltm = HTM::LongTermMemory.new(invalid_config)
# => PG::ConnectionBad

# Unique constraint violations (rare with deduplication)
# => PG::UniqueViolation
```

### Best Practices

```ruby
# Check existence before operations
if ltm.exists?(node_id)
  ltm.delete(node_id)
end

# Use HTM#forget for safe deletion with confirmation
htm.forget(node_id, confirm: :confirmed)
```

---

## See Also

- [HTM API](htm.md) - Main class that uses LongTermMemory
- [WorkingMemory API](working-memory.md) - Token-limited active context
- [Database Schema](../development/schema.md) - Full schema documentation
