# Recalling Memories from HTM

This guide covers HTM's powerful RAG-based retrieval system for finding relevant memories from your knowledge base.

## Basic Recall

The `recall` method searches long-term memory using timeframe and topic:

```ruby
memories = htm.recall(
  timeframe: "last week",     # Time range to search
  topic: "database design",   # What to search for
  limit: 20,                  # Max results (default: 20)
  strategy: :vector          # Search strategy (default: :vector)
)

memories.each do |memory|
  puts memory['value']
  puts "Similarity: #{memory['similarity']}"
  puts "Importance: #{memory['importance']}"
  puts "Created: #{memory['created_at']}"
  puts
end
```

## Understanding Timeframes

HTM supports both natural language timeframes and explicit ranges.

### Natural Language Timeframes

```ruby
# Last 24 hours (default if unparseable)
htm.recall(timeframe: "today", topic: "...")

# Yesterday
htm.recall(timeframe: "yesterday", topic: "...")

# Last week
htm.recall(timeframe: "last week", topic: "...")

# Last N days
htm.recall(timeframe: "last 7 days", topic: "...")
htm.recall(timeframe: "last 30 days", topic: "...")

# This month
htm.recall(timeframe: "this month", topic: "...")

# Last month
htm.recall(timeframe: "last month", topic: "...")
```

### Explicit Time Ranges

For precise control, use Ruby time ranges:

```ruby
# Specific date range
start_date = Time.new(2024, 1, 1)
end_date = Time.new(2024, 12, 31)
htm.recall(
  timeframe: start_date..end_date,
  topic: "annual report"
)

# Last 24 hours precisely
htm.recall(
  timeframe: (Time.now - 24*3600)..Time.now,
  topic: "errors"
)

# All time
htm.recall(
  timeframe: Time.at(0)..Time.now,
  topic: "architecture decisions"
)

# Relative to current time
three_days_ago = Time.now - (3 * 24 * 3600)
htm.recall(
  timeframe: three_days_ago..Time.now,
  topic: "bug fixes"
)
```

!!! tip "Choosing Timeframes"
    - Use **narrow timeframes** (days/weeks) for recent context
    - Use **wide timeframes** (months/years) for historical facts
    - Use **"all time"** for searching unchanging facts or decisions

## Search Strategies

HTM provides three search strategies, each with different strengths.

### Vector Search (Semantic)

Vector search uses embeddings to find semantically similar memories.

```ruby
memories = htm.recall(
  timeframe: "last month",
  topic: "improving application performance",
  strategy: :vector,
  limit: 10
)
```

**How it works**:

1. Converts your topic to a vector embedding via Ollama
2. Finds memories with similar embeddings using cosine similarity
3. Returns results ordered by semantic similarity

**Best for**:

- Conceptual searches ("how to optimize queries")
- Related topics ("database" finds "PostgreSQL", "SQL")
- Fuzzy matching ("ML" finds "machine learning")
- Understanding user intent

**Example**:

```ruby
# Will find memories about databases, even without the word "PostgreSQL"
memories = htm.recall(
  timeframe: "last year",
  topic: "data persistence strategies",
  strategy: :vector
)

# Finds: "Use PostgreSQL", "Database indexing", "SQL optimization"
```

!!! note "Similarity Scores"
    Vector search returns a `similarity` score (0-1). Scores > 0.8 indicate high relevance, 0.6-0.8 moderate relevance, < 0.6 low relevance.

### Full-text Search (Keywords)

Full-text search uses PostgreSQL's text search for exact keyword matching.

```ruby
memories = htm.recall(
  timeframe: "last week",
  topic: "PostgreSQL indexing",
  strategy: :fulltext,
  limit: 10
)
```

**How it works**:

1. Tokenizes your query into keywords
2. Uses PostgreSQL's `ts_vector` and `ts_query` for matching
3. Returns results ranked by text relevance

**Best for**:

- Exact keyword matches ("PostgreSQL", "Redis")
- Technical terms ("JWT", "OAuth")
- Proper nouns ("Alice", "Project Phoenix")
- Acronyms ("API", "SQL", "REST")

**Example**:

```ruby
# Will only find memories containing "JWT"
memories = htm.recall(
  timeframe: "all time",
  topic: "JWT authentication",
  strategy: :fulltext
)

# Finds: "JWT token validation", "Implemented JWT auth"
# Misses: "Token-based authentication" (no keyword match)
```

!!! note "Ranking Scores"
    Full-text search returns a `rank` score. Higher values indicate better keyword matches.

### Hybrid Search (Best of Both)

Hybrid search combines full-text and vector search for optimal results.

```ruby
memories = htm.recall(
  timeframe: "last month",
  topic: "database performance issues",
  strategy: :hybrid,
  limit: 10
)
```

**How it works**:

1. First, runs full-text search to find keyword matches (prefilter)
2. Then, ranks those results by vector similarity
3. Combines precision of keywords with understanding of semantics

**Best for**:

- General-purpose searches (default recommendation)
- When you want both keyword matches and related concepts
- Balancing precision and recall
- Production applications

**Example**:

```ruby
# Combines keyword matching with semantic understanding
memories = htm.recall(
  timeframe: "last quarter",
  topic: "scaling our PostgreSQL database",
  strategy: :hybrid
)

# Prefilter: Finds all memories mentioning "PostgreSQL" or "database"
# Ranking: Orders by semantic similarity to "scaling" concepts
```

!!! tip "When to Use Hybrid"
    Hybrid is the recommended default strategy. It provides good results across different query types without needing to choose between vector and full-text.

## Search Strategy Comparison

| Strategy | Speed | Accuracy | Best Use Case |
|----------|-------|----------|---------------|
| Vector | Medium | High for concepts | Understanding intent, related topics |
| Full-text | Fast | High for keywords | Exact terms, proper nouns |
| Hybrid | Medium | Highest overall | General purpose, best default |

## Query Optimization Tips

### 1. Be Specific

```ruby
# Vague: Returns too many irrelevant results
htm.recall(timeframe: "last year", topic: "data")

# Specific: Returns targeted results
htm.recall(timeframe: "last year", topic: "PostgreSQL query optimization")
```

### 2. Use Appropriate Timeframes

```ruby
# Too wide: Includes outdated information
htm.recall(timeframe: "last 5 years", topic: "current project status")

# Right size: Recent context
htm.recall(timeframe: "last week", topic: "current project status")
```

### 3. Adjust Limit Based on Need

```ruby
# Few results: Quick overview
htm.recall(timeframe: "last month", topic: "errors", limit: 5)

# Many results: Comprehensive search
htm.recall(timeframe: "last year", topic: "architecture decisions", limit: 50)
```

### 4. Try Different Strategies

```ruby
# Start with hybrid (best all-around)
results = htm.recall(topic: "authentication", strategy: :hybrid)

# If too many results, try full-text (more precise)
results = htm.recall(topic: "JWT authentication", strategy: :fulltext)

# If no results, try vector (more flexible)
results = htm.recall(topic: "user validation methods", strategy: :vector)
```

## Combining Search with Filters

While `recall` handles timeframes and topics, you can filter results further:

```ruby
# Recall memories
memories = htm.recall(
  timeframe: "last month",
  topic: "database",
  strategy: :hybrid,
  limit: 50
)

# Filter by type
decisions = memories.select { |m| m['type'] == 'decision' }

# Filter by importance
critical = memories.select { |m| m['importance'].to_f >= 8.0 }

# Filter by robot
my_memories = memories.select { |m| m['robot_id'] == htm.robot_id }

# Filter by date
recent = memories.select do |m|
  Time.parse(m['created_at']) > Time.now - 7*24*3600
end
```

## Advanced Query Patterns

### Pattern 1: Multi-Topic Search

Search for multiple related topics:

```ruby
def search_multiple_topics(timeframe, topics, strategy: :hybrid, limit: 10)
  results = []

  topics.each do |topic|
    results.concat(
      htm.recall(
        timeframe: timeframe,
        topic: topic,
        strategy: strategy,
        limit: limit
      )
    )
  end

  # Remove duplicates by key
  results.uniq { |m| m['key'] }
end

# Usage
memories = search_multiple_topics(
  "last month",
  ["database optimization", "query performance", "indexing strategies"]
)
```

### Pattern 2: Iterative Refinement

Start broad, then narrow:

```ruby
# First pass: Broad search
broad_results = htm.recall(
  timeframe: "last year",
  topic: "architecture",
  strategy: :vector,
  limit: 100
)

# Analyze results, refine query
relevant_terms = broad_results
  .select { |m| m['similarity'].to_f > 0.7 }
  .flat_map { |m| m['tags'] }
  .uniq

# Second pass: Refined search
refined_results = htm.recall(
  timeframe: "last year",
  topic: "architecture #{relevant_terms.join(' ')}",
  strategy: :hybrid,
  limit: 20
)
```

### Pattern 3: Threshold Filtering

Only keep high-quality matches:

```ruby
def recall_with_threshold(timeframe:, topic:, threshold: 0.7, strategy: :vector)
  results = htm.recall(
    timeframe: timeframe,
    topic: topic,
    strategy: strategy,
    limit: 50  # Get more candidates
  )

  # Filter by similarity threshold
  case strategy
  when :vector, :hybrid
    results.select { |m| m['similarity'].to_f >= threshold }
  when :fulltext
    # For fulltext, use rank threshold (adjust as needed)
    results.select { |m| m['rank'].to_f >= threshold }
  end
end

# Usage
high_quality = recall_with_threshold(
  timeframe: "last month",
  topic: "performance optimization",
  threshold: 0.8
)
```

### Pattern 4: Time-Weighted Search

Weight results by recency:

```ruby
def recall_time_weighted(timeframe:, topic:, recency_weight: 0.3)
  memories = htm.recall(
    timeframe: timeframe,
    topic: topic,
    strategy: :hybrid,
    limit: 50
  )

  # Calculate time-weighted score
  now = Time.now
  memories.each do |m|
    created = Time.parse(m['created_at'])
    age_days = (now - created) / (24 * 3600)

    # Decay factor: newer is better
    recency_score = Math.exp(-age_days / 30.0)  # 30-day half-life

    # Combine similarity and recency
    similarity = m['similarity'].to_f
    m['weighted_score'] = (
      similarity * (1 - recency_weight) +
      recency_score * recency_weight
    )
  end

  # Sort by weighted score
  memories.sort_by { |m| -m['weighted_score'] }
end
```

### Pattern 5: Context-Aware Search

Include current context in search:

```ruby
class ContextualRecall
  def initialize(htm)
    @htm = htm
    @current_context = []
  end

  def add_context(key, value)
    @current_context << { key: key, value: value }
  end

  def recall(timeframe:, topic:, strategy: :hybrid)
    # Enhance topic with current context
    context_terms = @current_context.map { |c| c[:value] }.join(" ")
    enhanced_topic = "#{topic} #{context_terms}"

    @htm.recall(
      timeframe: timeframe,
      topic: enhanced_topic,
      strategy: strategy,
      limit: 20
    )
  end
end

# Usage
recall = ContextualRecall.new(htm)
recall.add_context("project", "e-commerce platform")
recall.add_context("focus", "checkout flow")

# Search includes context automatically
results = recall.recall(
  timeframe: "last month",
  topic: "payment processing"
)
```

## Retrieving Specific Memories

For known keys, use `retrieve` instead of `recall`:

```ruby
# Retrieve by exact key
memory = htm.retrieve("decision_database")

if memory
  puts memory['value']
  puts "Type: #{memory['type']}"
  puts "Created: #{memory['created_at']}"
else
  puts "Memory not found"
end
```

!!! note
    `retrieve` is faster than `recall` because it doesn't require embedding generation or similarity calculation.

## Working with Search Results

### Result Structure

Each memory returned by `recall` has these fields:

```ruby
memory = {
  'id' => 123,                           # Database ID
  'key' => "decision_001",               # Unique key
  'value' => "Decision text...",         # Content
  'type' => "decision",                  # Memory type
  'category' => "architecture",          # Category (if set)
  'importance' => 9.0,                   # Importance score
  'created_at' => "2024-01-15 10:30:00", # Timestamp
  'robot_id' => "uuid...",               # Which robot added it
  'token_count' => 150,                  # Token count
  'similarity' => 0.85                   # Similarity score (vector/hybrid)
  # or 'rank' for fulltext
}
```

### Processing Results

```ruby
memories = htm.recall(timeframe: "last month", topic: "errors")

# Sort by importance
by_importance = memories.sort_by { |m| -m['importance'].to_f }

# Group by type
by_type = memories.group_by { |m| m['type'] }

# Extract just the content
content = memories.map { |m| m['value'] }

# Create summary
summary = memories.map do |m|
  "[#{m['type']}] #{m['value'][0..100]}... (#{m['importance']})"
end.join("\n\n")
```

## Common Use Cases

### Use Case 1: Error Analysis

Find recent errors and their solutions:

```ruby
# Find recent errors
errors = htm.recall(
  timeframe: "last 7 days",
  topic: "error exception failure",
  strategy: :fulltext,
  limit: 20
)

# Group by error type
error_types = errors
  .map { |e| e['value'][/Error: (.+?)\\n/, 1] }
  .compact
  .tally

puts "Error frequency:"
error_types.sort_by { |_, count| -count }.each do |type, count|
  puts "  #{type}: #{count} occurrences"
end
```

### Use Case 2: Decision History

Track decision evolution:

```ruby
# Get all decisions about a topic
decisions = htm.recall(
  timeframe: Time.at(0)..Time.now,  # All time
  topic: "authentication",
  strategy: :hybrid,
  limit: 50
).select { |m| m['type'] == 'decision' }

# Sort chronologically
timeline = decisions.sort_by { |d| d['created_at'] }

puts "Decision timeline:"
timeline.each do |decision|
  puts "#{decision['created_at']}: #{decision['value'][0..100]}..."
end
```

### Use Case 3: Knowledge Aggregation

Gather all knowledge about a topic:

```ruby
def gather_knowledge(topic)
  # Gather different types of memories
  facts = htm.recall(
    timeframe: "all time",
    topic: topic,
    strategy: :hybrid
  ).select { |m| m['type'] == 'fact' }

  decisions = htm.recall(
    timeframe: "all time",
    topic: topic,
    strategy: :hybrid
  ).select { |m| m['type'] == 'decision' }

  code = htm.recall(
    timeframe: "all time",
    topic: topic,
    strategy: :hybrid
  ).select { |m| m['type'] == 'code' }

  {
    facts: facts,
    decisions: decisions,
    code_examples: code
  }
end

knowledge = gather_knowledge("PostgreSQL")
```

### Use Case 4: Conversation Context

Recall recent conversation:

```ruby
def get_conversation_context(session_id, turns: 5)
  # Get recent conversation turns
  htm.recall(
    timeframe: "last 24 hours",
    topic: "session_#{session_id}",
    strategy: :fulltext,
    limit: turns * 2  # user + assistant messages
  ).select { |m| m['type'] == 'context' }
    .sort_by { |m| m['created_at'] }
    .last(turns * 2)
end
```

## Performance Considerations

### Search Speed

- **Full-text**: Fastest (~50-100ms)
- **Vector**: Medium (~100-300ms)
- **Hybrid**: Medium (~150-350ms)

Times vary based on database size and query complexity.

### Optimizing Queries

```ruby
# Slow: Wide timeframe + high limit
htm.recall(timeframe: "last 5 years", topic: "...", limit: 1000)

# Fast: Narrow timeframe + reasonable limit
htm.recall(timeframe: "last week", topic: "...", limit: 20)
```

### Caching Results

For repeated queries:

```ruby
class CachedRecall
  def initialize(htm, cache_ttl: 300)
    @htm = htm
    @cache = {}
    @cache_ttl = cache_ttl
  end

  def recall(**args)
    cache_key = args.hash

    if cached = @cache[cache_key]
      return cached[:results] if Time.now - cached[:time] < @cache_ttl
    end

    results = @htm.recall(**args)
    @cache[cache_key] = { results: results, time: Time.now }
    results
  end
end
```

## Troubleshooting

### No Results

```ruby
results = htm.recall(timeframe: "last week", topic: "xyz")

if results.empty?
  # Try wider timeframe
  results = htm.recall(timeframe: "last month", topic: "xyz")

  # Try different strategy
  results = htm.recall(
    timeframe: "last month",
    topic: "xyz",
    strategy: :vector  # More flexible
  )

  # Try related terms
  results = htm.recall(
    timeframe: "last month",
    topic: "xyz related similar",
    strategy: :vector
  )
end
```

### Low-Quality Results

```ruby
# Filter by similarity threshold
good_results = results.select do |m|
  m['similarity'].to_f > 0.7  # Only high-quality matches
end

# Or boost limit and take top results
htm.recall(timeframe: "...", topic: "...", limit: 100)
  .sort_by { |m| -m['similarity'].to_f }
  .first(10)
```

### Ollama Connection Issues

If vector search fails:

```ruby
begin
  results = htm.recall(topic: "...", strategy: :vector)
rescue => e
  warn "Vector search failed: #{e.message}"
  warn "Falling back to full-text search"
  results = htm.recall(topic: "...", strategy: :fulltext)
end
```

## Next Steps

- [**Context Assembly**](context-assembly.md) - Use recalled memories with your LLM
- [**Search Strategies**](search-strategies.md) - Deep dive into search algorithms
- [**Working Memory**](working-memory.md) - Understand how recall populates working memory

## Complete Example

```ruby
require 'htm'

htm = HTM.new(robot_name: "Search Demo")

# Add test memories
htm.add_node(
  "decision_db",
  "Chose PostgreSQL for its reliability and ACID compliance",
  type: :decision,
  importance: 9.0,
  tags: ["database", "postgresql", "architecture"]
)

htm.add_node(
  "code_connection",
  "conn = PG.connect(dbname: 'mydb')",
  type: :code,
  importance: 6.0,
  tags: ["postgresql", "ruby", "connection"]
)

# Vector search: Semantic understanding
puts "=== Vector Search ==="
vector_results = htm.recall(
  timeframe: "all time",
  topic: "data persistence strategies",
  strategy: :vector,
  limit: 10
)

vector_results.each do |m|
  puts "#{m['value'][0..80]}..."
  puts "  Similarity: #{m['similarity']}"
  puts
end

# Full-text search: Exact keywords
puts "\n=== Full-text Search ==="
fulltext_results = htm.recall(
  timeframe: "all time",
  topic: "PostgreSQL",
  strategy: :fulltext,
  limit: 10
)

fulltext_results.each do |m|
  puts "#{m['value'][0..80]}..."
  puts "  Rank: #{m['rank']}"
  puts
end

# Hybrid search: Best of both
puts "\n=== Hybrid Search ==="
hybrid_results = htm.recall(
  timeframe: "all time",
  topic: "database connection setup",
  strategy: :hybrid,
  limit: 10
)

hybrid_results.each do |m|
  puts "[#{m['type']}] #{m['value'][0..80]}..."
  puts "  Importance: #{m['importance']}, Similarity: #{m['similarity']}"
  puts
end
```
