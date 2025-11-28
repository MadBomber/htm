# HTM Class

The main interface for HTM's intelligent memory management system.

## Overview

`HTM` is the primary class that orchestrates the two-tier memory system:

- **Working Memory**: Token-limited active context for immediate LLM use
- **Long-term Memory**: Durable PostgreSQL storage with vector embeddings

Key features:

- Never forgets unless explicitly told (`forget`)
- RAG-based retrieval (temporal + semantic search)
- Multi-robot "hive mind" - all robots share global memory via content deduplication
- Hierarchical tagging for knowledge organization
- Tag-enhanced hybrid search for improved relevance

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
  robot_name: nil,
  db_config: nil,
  db_pool_size: 5,
  db_query_timeout: 30_000,
  db_cache_size: 1000,
  db_cache_ttl: 300
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `working_memory_size` | Integer | `128_000` | Maximum tokens for working memory |
| `robot_name` | String, nil | `"robot_#{uuid[0..7]}"` | Human-readable name |
| `db_config` | Hash, nil | From `ENV['HTM_DBURL']` | Database configuration |
| `db_pool_size` | Integer | `5` | Database connection pool size |
| `db_query_timeout` | Integer | `30_000` | Query timeout in milliseconds |
| `db_cache_size` | Integer | `1000` | Query cache size (0 to disable) |
| `db_cache_ttl` | Integer | `300` | Cache TTL in seconds |

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

# Custom database configuration
htm = HTM.new(
  db_config: {
    host: 'localhost',
    port: 5432,
    dbname: 'htm_db',
    user: 'postgres',
    password: 'secret'
  }
)

# With caching disabled
htm = HTM.new(
  robot_name: "No Cache Bot",
  db_cache_size: 0
)
```

---

## Instance Attributes

### `robot_id` {: #robot_id }

Unique integer identifier for this robot instance.

- **Type**: Integer
- **Read-only**: Yes

```ruby
htm.robot_id  # => 42
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

### `remember(content, tags:)` {: #remember }

Remember new information by storing it in long-term memory.

```ruby
remember(content, tags: [])
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | String | *required* | The information to remember |
| `tags` | Array\<String\> | `[]` | Manual tags to assign (in addition to auto-extracted tags) |

#### Returns

- `Integer` - Database ID of the memory node

#### Side Effects

- Stores node in PostgreSQL with content deduplication (via SHA-256 hash)
- Creates/updates `robot_nodes` association for this robot
- Adds node to working memory (evicts if needed)
- Enqueues background job for embedding generation (new nodes only)
- Enqueues background job for tag extraction (new nodes only)
- Updates robot activity timestamp

#### Content Deduplication

When `remember()` is called:

1. A SHA-256 hash of the content is computed
2. If a node with the same hash exists, the existing node is reused
3. A new `robot_nodes` association is created (or `remember_count` is incremented)
4. This ensures identical memories are stored once but can be "remembered" by multiple robots

#### Examples

```ruby
# Basic usage
node_id = htm.remember("PostgreSQL supports vector similarity search via pgvector")

# With manual tags
node_id = htm.remember(
  "Time-series data works great with hypertables",
  tags: ["database:timescaledb", "performance"]
)

# Multiple robots remembering the same content
robot1 = HTM.new(robot_name: "assistant_1")
robot2 = HTM.new(robot_name: "assistant_2")

# Both robots remember the same fact - stored once, linked to both
robot1.remember("Ruby 3.3 was released in December 2023")
robot2.remember("Ruby 3.3 was released in December 2023")
# Same node_id returned, remember_count incremented for robot2
```

#### Notes

- Embeddings and hierarchical tags are generated asynchronously via background jobs
- Empty content returns the ID of the most recent node without creating a duplicate
- Token count is calculated automatically using the configured token counter

---

### `recall(topic, **options)` {: #recall }

Recall memories from long-term storage using RAG-based retrieval.

```ruby
recall(
  topic,
  timeframe: "last 7 days",
  limit: 20,
  strategy: :vector,
  with_relevance: false,
  query_tags: [],
  raw: false
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `topic` | String | *required* | Topic to search for |
| `timeframe` | String, Range | `"last 7 days"` | Time range |
| `limit` | Integer | `20` | Maximum number of nodes to retrieve |
| `strategy` | Symbol | `:vector` | Search strategy (`:vector`, `:fulltext`, `:hybrid`) |
| `with_relevance` | Boolean | `false` | Include dynamic relevance scores |
| `query_tags` | Array\<String\> | `[]` | Tags to boost relevance |
| `raw` | Boolean | `false` | Return full node hashes instead of content strings |

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
| `:hybrid` | Vector + fulltext + tag matching | Best accuracy with tag boosting |

#### Tag-Enhanced Hybrid Search

When using `:hybrid` strategy, the search automatically:

1. Finds tags matching query terms (words 3+ chars)
2. Includes nodes with matching tags in the candidate pool
3. Calculates combined score: `(similarity × 0.7) + (tag_boost × 0.3)`
4. Returns results sorted by combined score

#### Returns

- `Array<String>` - Content strings (when `raw: false`, default)
- `Array<Hash>` - Full node hashes (when `raw: true`)

When `raw: true`, each hash contains:

```ruby
{
  "id" => 123,                    # Database ID
  "content" => "...",             # Node content
  "content_hash" => "abc123...",  # SHA-256 hash
  "access_count" => 5,            # Times accessed
  "created_at" => "2025-01-15...", # Creation timestamp
  "token_count" => 125,           # Token count
  "similarity" => 0.87,           # Similarity score (hybrid/vector)
  "tag_boost" => 0.3,             # Tag boost score (hybrid only)
  "combined_score" => 0.79        # Combined score (hybrid only)
}
```

#### Side Effects

- Adds recalled nodes to working memory
- Evicts existing nodes if working memory is full
- Updates robot activity timestamp

#### Examples

```ruby
# Basic usage (returns content strings)
memories = htm.recall("PostgreSQL")
# => ["PostgreSQL supports vector search...", "PostgreSQL with pgvector..."]

# Get full node hashes
nodes = htm.recall("PostgreSQL", raw: true)
# => [{"id" => 1, "content" => "...", "similarity" => 0.92, ...}, ...]

# Vector semantic search
memories = htm.recall(
  "database performance optimization",
  timeframe: "last week",
  strategy: :vector
)

# Fulltext search for exact phrases
memories = htm.recall(
  "PostgreSQL connection pooling",
  timeframe: "last 30 days",
  strategy: :fulltext,
  limit: 10
)

# Hybrid search with tag boosting (recommended)
memories = htm.recall(
  "API rate limiting implementation",
  timeframe: "this month",
  strategy: :hybrid,
  limit: 15,
  raw: true
)

# Check matching tags for a query
matching_tags = htm.long_term_memory.find_query_matching_tags("PostgreSQL")
# => ["database:postgresql", "database:postgresql:extensions"]

# Custom time range
start_time = Time.new(2025, 1, 1)
end_time = Time.now

memories = htm.recall(
  "security vulnerabilities",
  timeframe: start_time..end_time,
  limit: 50
)
```

#### Performance Notes

- Vector search: Best for semantic understanding, requires embedding generation
- Fulltext search: Fastest for exact matches, no embedding overhead
- Hybrid search: Most accurate, combines vector + fulltext + tags with weighted scoring

---

### `forget(node_id, confirm:)` {: #forget }

Explicitly delete a memory node. Requires confirmation to prevent accidental deletion.

```ruby
forget(node_id, confirm: :confirmed)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `node_id` | Integer | ID of the node to delete |
| `confirm` | Symbol | Must be `:confirmed` to proceed |

#### Returns

- `true` - If successfully deleted

#### Raises

- `ArgumentError` - If `confirm` is not `:confirmed`
- `ArgumentError` - If `node_id` is nil
- `HTM::NotFoundError` - If node doesn't exist

#### Side Effects

- Deletes node from PostgreSQL
- Removes node from working memory
- Updates robot activity timestamp

#### Examples

```ruby
# Correct usage
htm.forget(123, confirm: :confirmed)

# This will raise ArgumentError
htm.forget(123)  # Missing confirm parameter

# Safe deletion with verification
if htm.long_term_memory.exists?(node_id)
  htm.forget(node_id, confirm: :confirmed)
  puts "Deleted node #{node_id}"
end
```

#### Notes

- This is the **only** way to delete data from HTM
- Deletion is permanent and cannot be undone
- Related robot_nodes, node_tags are also deleted (CASCADE)
- Other robots' associations to this node are also removed

---

### `load_file(path, force: false)` {: #load_file }

Load a markdown file into long-term memory with automatic chunking and source tracking.

```ruby
load_file(path, force: false)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | *required* | Path to the markdown file to load |
| `force` | Boolean | `false` | Force re-sync even if file hasn't changed |

#### Returns

- `Hash` with keys:
  - `file_source_id` - ID of the FileSource record
  - `chunks_created` - Number of new nodes created
  - `chunks_updated` - Number of existing nodes updated
  - `chunks_deleted` - Number of nodes soft-deleted

#### Side Effects

- Creates or updates a FileSource record for tracking
- Parses YAML frontmatter and stores as metadata
- Chunks content by paragraph, preserving code blocks
- Creates nodes for each chunk with `source_id` linking to file
- Triggers async embedding and tag extraction for new nodes

#### Examples

```ruby
# Load a file
result = htm.load_file("docs/guide.md")
# => { file_source_id: 1, chunks_created: 5, chunks_updated: 0, chunks_deleted: 0 }

# Force reload even if unchanged
result = htm.load_file("docs/guide.md", force: true)

# File with frontmatter
# ---
# title: User Guide
# tags: [documentation, tutorial]
# ---
# Content here...
result = htm.load_file("docs/guide.md")
# Frontmatter stored in FileSource.frontmatter
```

---

### `load_directory(path, pattern: '**/*.md', force: false)` {: #load_directory }

Load all matching files in a directory into long-term memory.

```ruby
load_directory(path, pattern: '**/*.md', force: false)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | *required* | Directory path to scan |
| `pattern` | String | `'**/*.md'` | Glob pattern for matching files |
| `force` | Boolean | `false` | Force re-sync all files |

#### Returns

- `Array<Hash>` - Results for each file loaded, each containing:
  - `file_path` - Path of the loaded file
  - `file_source_id` - ID of the FileSource record
  - `chunks_created` - Number of new nodes created
  - `chunks_updated` - Number of existing nodes updated
  - `chunks_deleted` - Number of nodes soft-deleted

#### Examples

```ruby
# Load all markdown files
results = htm.load_directory("docs/")

# Load with custom pattern
results = htm.load_directory("content/", pattern: "**/*.md")

# Force reload all
results = htm.load_directory("docs/", force: true)
```

---

### `nodes_from_file(file_path)` {: #nodes_from_file }

Get all nodes loaded from a specific file.

```ruby
nodes_from_file(file_path)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `file_path` | String | Path of the source file |

#### Returns

- `Array<HTM::Models::Node>` - Nodes from the file, ordered by chunk position

#### Examples

```ruby
nodes = htm.nodes_from_file("docs/guide.md")
nodes.each do |node|
  puts "Chunk #{node.chunk_position}: #{node.content[0..50]}..."
end
```

---

### `unload_file(file_path)` {: #unload_file }

Remove a file from memory by soft-deleting all its chunks and the file source.

```ruby
unload_file(file_path)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `file_path` | String | Path of the source file to unload |

#### Returns

- `true` if file was found and unloaded
- `false` if file was not found

#### Side Effects

- Soft-deletes all nodes from the file (sets `deleted_at`)
- Destroys the FileSource record

#### Examples

```ruby
# Unload a file
htm.unload_file("docs/guide.md")

# Check if file is loaded
if htm.nodes_from_file("docs/guide.md").empty?
  puts "File not loaded"
end
```

---

## Error Handling

### ArgumentError

```ruby
# Invalid confirm parameter
htm.forget(123)
# => ArgumentError: Must pass confirm: :confirmed to delete

# Nil node_id
htm.forget(nil, confirm: :confirmed)
# => ArgumentError: node_id cannot be nil

# Invalid timeframe
htm.recall("test", timeframe: 123)
# => ValidationError: Timeframe must be a Range or String
```

### HTM::NotFoundError

```ruby
# Node doesn't exist
htm.forget(999999, confirm: :confirmed)
# => HTM::NotFoundError: Node not found: 999999
```

### PG::Error

```ruby
# Database connection issues
htm = HTM.new(db_config: { host: 'invalid' })
# => PG::ConnectionBad: could not translate host name...
```

## Best Practices

### Content Organization

```ruby
# Use meaningful content that stands alone
htm.remember("PostgreSQL was chosen for its reliability and pgvector support")

# Add hierarchical tags for organization
htm.remember(
  "Rate limiting implemented using Redis sliding window algorithm",
  tags: ["architecture:api:rate-limiting", "database:redis"]
)

# Let the system extract tags automatically for most content
htm.remember("The authentication system uses JWT tokens with 1-hour expiry")
# Auto-extracted tags might include: security:authentication, technology:jwt
```

### Search Strategies

```ruby
# Use hybrid for best results (recommended)
memories = htm.recall(
  "security vulnerability",
  strategy: :hybrid  # Combines vector + fulltext + tags
)

# Use vector for semantic understanding
memories = htm.recall(
  "performance issues",
  strategy: :vector  # Finds "slow queries", "optimization", etc.
)

# Use fulltext for exact terms
memories = htm.recall(
  "PostgreSQL EXPLAIN ANALYZE",
  strategy: :fulltext  # Exact match
)
```

### Leveraging Tag-Enhanced Search

```ruby
# Check what tags exist for a topic
tags = htm.long_term_memory.find_query_matching_tags("database")
# => ["database:postgresql", "database:redis", "database:timescaledb"]

# Hybrid search automatically boosts nodes with matching tags
memories = htm.recall("database optimization", strategy: :hybrid, raw: true)
memories.each do |m|
  puts "Score: #{m['combined_score']} (sim: #{m['similarity']}, tag: #{m['tag_boost']})"
end
```

### Multi-Robot Memory Sharing

```ruby
# Content is deduplicated across robots
assistant = HTM.new(robot_name: "assistant")
researcher = HTM.new(robot_name: "researcher")

# Both robots remember the same fact
assistant.remember("Ruby 3.3 supports YJIT by default")
researcher.remember("Ruby 3.3 supports YJIT by default")
# Node stored once, linked to both robots

# Any robot can recall shared memories
memories = assistant.recall("Ruby YJIT")
# Returns the shared memory
```

### Resource Management

```ruby
# Check working memory before large operations
stats = htm.working_memory.stats
if stats[:utilization] > 90
  # Consider clearing working memory or using smaller limits
end

# Use appropriate limits
htm.recall("common_topic", limit: 10)  # Not 1000

# Monitor node counts
node_count = HTM::Models::Node.count
if node_count > 1_000_000
  # Consider archival strategy
end
```

## See Also

- [WorkingMemory API](working-memory.md)
- [LongTermMemory API](long-term-memory.md)
- [EmbeddingService API](embedding-service.md)
- [Database API](database.md)
