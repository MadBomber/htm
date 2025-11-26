# Adding Memories to HTM

This guide covers everything you need to know about storing information in HTM effectively.

## Basic Usage

The primary method for adding memories is `remember`:

```ruby
node_id = htm.remember(content, tags: [])
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | String | *required* | The information to remember |
| `tags` | Array\<String\> | `[]` | Manual tags to assign (in addition to auto-extracted tags) |

The method returns the database ID of the created node.

## How Remember Works

When you call `remember()`:

1. **Content hashing**: A SHA-256 hash of the content is computed
2. **Deduplication check**: If a node with the same hash exists, reuse it
3. **Node creation/linking**: Create new node OR link robot to existing node
4. **Working memory**: Add node to working memory (evict if needed)
5. **Background jobs**: Enqueue embedding and tag generation (async)

```ruby
# First robot remembers something
node_id = htm.remember("PostgreSQL supports vector similarity search")
# => 123 (new node created)

# Same content remembered again (by same or different robot)
node_id = htm.remember("PostgreSQL supports vector similarity search")
# => 123 (same node_id returned, just updates remember_count)
```

## Content Types

HTM doesn't enforce content types - just store meaningful text that stands alone:

### Facts

```ruby
# User information
htm.remember("The user's name is Alice Thompson")

# System configuration
htm.remember("System timezone is UTC")

# Domain knowledge
htm.remember("Photosynthesis converts light energy into chemical energy in plants")
```

### Preferences

```ruby
# Communication style
htm.remember("User prefers concise answers with bullet points")

# Technical preferences
htm.remember("User prefers Ruby over Python for scripting tasks")
```

### Decisions

```ruby
# Technology choice
htm.remember(<<~DECISION)
  Decision: Use PostgreSQL with pgvector for HTM storage

  Rationale:
  - Excellent vector search via pgvector
  - Strong consistency guarantees
  - Mature ecosystem

  Alternatives considered:
  - MongoDB (rejected: eventual consistency issues)
  - Redis (rejected: limited persistence)
DECISION
```

### Code Snippets

```ruby
# Function example
htm.remember(<<~CODE)
  def parse_date(date_string)
    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
CODE

# SQL query pattern
htm.remember(<<~SQL)
  SELECT u.id, u.name, COUNT(o.id) as order_count
  FROM users u
  LEFT JOIN orders o ON u.id = o.user_id
  GROUP BY u.id, u.name
  HAVING COUNT(o.id) > 10
SQL
```

## Using Tags

Tags provide hierarchical organization for your memories. HTM automatically extracts tags from content, but you can also specify manual tags.

### Hierarchical Tag Convention

Use colons to create hierarchical namespaces:

```ruby
# Manual tags with hierarchy
htm.remember(
  "PostgreSQL 17 adds MERGE statement improvements",
  tags: ["database:postgresql", "database:sql", "version:17"]
)

# Tags are used in hybrid search for relevance boosting
# A recall for "postgresql" will boost nodes with matching tags
```

### Tag Naming Conventions

```ruby
# Good: Consistent, lowercase, hierarchical
tags: ["database:postgresql", "architecture:api", "security:authentication"]

# Avoid: Inconsistent casing, flat tags, vague terms
tags: ["PostgreSQL", "stuff", "misc"]
```

### Common Tag Patterns

```ruby
# Domain tags
tags: ["database:postgresql", "api:rest", "auth:jwt"]

# Layer tags
tags: ["layer:frontend", "layer:backend", "layer:infrastructure"]

# Technology tags
tags: ["tech:ruby", "tech:javascript", "tech:docker"]

# Project tags
tags: ["project:alpha", "project:beta"]
```

### Automatic Tag Extraction

When a node is created, a background job (GenerateTagsJob) automatically extracts hierarchical tags from the content using an LLM. This happens asynchronously.

```ruby
# Just provide content, tags are auto-extracted
htm.remember("We're using Redis for session caching with a 24-hour TTL")
# Background job might extract: ["database:redis", "caching:session", "performance"]
```

## Content Deduplication

HTM automatically deduplicates content across all robots using SHA-256 hashing.

### How It Works

```ruby
# Robot 1 remembers something
robot1 = HTM.new(robot_name: "assistant_1")
node_id = robot1.remember("Ruby 3.3 supports YJIT by default")
# => 123 (new node)

# Robot 2 remembers the same thing
robot2 = HTM.new(robot_name: "assistant_2")
node_id = robot2.remember("Ruby 3.3 supports YJIT by default")
# => 123 (same node_id! Content matched by hash)
```

### Robot-Node Association

Each robot-node relationship is tracked in `robot_nodes`:

```ruby
# Check how many times a robot has "remembered" content
rn = HTM::Models::RobotNode.find_by(robot_id: htm.robot_id, node_id: node_id)
rn.remember_count      # => 3 (remembered 3 times)
rn.first_remembered_at # => When first encountered
rn.last_remembered_at  # => When last tried to remember
```

## Best Practices

### 1. Make Content Self-Contained

```ruby
# Good: Self-contained, understandable without context
htm.remember(
  "Decided to use Redis for session storage because it provides fast access and automatic expiration"
)

# Bad: Requires external context
htm.remember("Use Redis")  # Why? For what?
```

### 2. Include Rich Context

```ruby
# Good: Includes rationale and alternatives
htm.remember(<<~DECISION)
  Decision: Use OAuth 2.0 for authentication

  Rationale:
  - Industry standard
  - Better security than basic auth
  - Supports SSO

  Alternatives considered:
  - Basic auth (rejected: security concerns)
  - Custom tokens (rejected: maintenance burden)
DECISION
```

### 3. Use Hierarchical Tags

```ruby
# Good: Rich tags for multiple retrieval paths
htm.remember(
  "JWT tokens are stateless authentication tokens",
  tags: ["auth:jwt", "security:tokens", "architecture:stateless"]
)

# Suboptimal: Flat or minimal tags
htm.remember("JWT info", tags: ["jwt"])
```

### 4. Keep Content Focused

```ruby
# Good: One concept per memory
htm.remember("PostgreSQL's EXPLAIN ANALYZE shows actual execution times")
htm.remember("PostgreSQL's EXPLAIN shows the query plan without executing")

# Suboptimal: Multiple unrelated concepts
htm.remember("PostgreSQL has EXPLAIN and also supports JSON and has good performance")
```

## Async Processing

Embedding generation and tag extraction happen asynchronously:

### Workflow

```ruby
# 1. Node created immediately (~15ms)
node_id = htm.remember("Important fact about databases")
# Returns immediately with node_id

# 2. Background jobs enqueue (async)
# - GenerateEmbeddingJob runs (~100ms)
# - GenerateTagsJob runs (~1 second)

# 3. Node is eventually enriched
# - embedding field populated (enables vector search)
# - tags associated (enables tag navigation and boosting)
```

### Immediate vs Eventual Capabilities

| Capability | Available | Notes |
|------------|-----------|-------|
| Full-text search | Immediately | Works on content |
| Basic retrieval | Immediately | By node ID |
| Vector search | After ~100ms | Needs embedding |
| Tag-enhanced search | After ~1s | Needs tags |
| Hybrid search | After ~1s | Needs embedding + tags |

## Working Memory Integration

When you `remember()`, the node is automatically added to working memory:

```ruby
# Remember adds to both LTM and WM
htm.remember("Important fact")

# Check working memory
stats = htm.working_memory.stats
puts "Nodes in WM: #{stats[:node_count]}"
puts "Token usage: #{stats[:utilization]}%"
```

### Eviction

If working memory is full, older/less important nodes are evicted to make room:

```ruby
# Working memory has a token budget
htm = HTM.new(working_memory_size: 128_000)  # 128K tokens

# As you remember more, older items may be evicted from WM
# They remain in LTM and can be recalled later
```

## Performance Considerations

### Batch Operations

Each `remember()` call is a database operation. For bulk inserts:

```ruby
# Multiple memories
facts = [
  "PostgreSQL supports JSONB",
  "PostgreSQL has excellent indexing",
  "PostgreSQL handles concurrent writes well"
]

facts.each do |fact|
  htm.remember(fact)
end
```

### Content Length

Longer content takes more time to process:

```ruby
# Short text: Fast (~15ms save, ~100ms embedding)
htm.remember("User name is Alice")

# Long text: Slower (~15ms save, ~500ms embedding)
htm.remember("..." * 1000)  # 1000 chars
```

For very long content (>1000 tokens), consider splitting into multiple memories.

## Next Steps

Now that you know how to add memories effectively, learn about:

- [**Search Strategies**](search-strategies.md) - Optimize retrieval with different strategies
- [**Recalling Memories**](recalling-memories.md) - Search and retrieve memories

## Complete Example

```ruby
require 'htm'

htm = HTM.new(robot_name: "Memory Demo")

# Add a fact
htm.remember(
  "Alice Thompson is a senior software engineer specializing in distributed systems"
)

# Add a preference
htm.remember(
  "Alice prefers Vim for editing and tmux for terminal management"
)

# Add a decision with context
htm.remember(<<~DECISION, tags: ["architecture", "messaging"])
  Decision: Use RabbitMQ for async job processing

  Rationale:
  - Need reliable message delivery
  - Support for multiple consumer patterns
  - Excellent Ruby client library

  Alternatives:
  - Redis (simpler but less reliable)
  - Kafka (overkill for our scale)
DECISION

# Add implementation code
htm.remember(<<~RUBY, tags: ["code:ruby", "messaging:rabbitmq"])
  require 'bunny'

  connection = Bunny.new(ENV['RABBITMQ_URL'])
  connection.start

  channel = connection.create_channel
  queue = channel.queue('jobs', durable: true)
RUBY

puts "Added memories with relationships and rich metadata"
puts "Stats: #{HTM::Models::Node.count} total nodes"
```
