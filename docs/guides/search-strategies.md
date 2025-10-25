# Search Strategies Deep Dive

HTM provides three search strategies for retrieving memories: vector search, full-text search, and hybrid search. This guide explores each strategy in depth, when to use them, and how to optimize performance.

## Overview

| Strategy | Method | Strength | Best For |
|----------|--------|----------|----------|
| **Vector** | Semantic similarity via embeddings | Understanding meaning | Conceptual queries, related topics |
| **Full-text** | PostgreSQL text search | Exact keyword matching | Specific terms, proper nouns |
| **Hybrid** | Combines both approaches | Best overall accuracy | General purpose queries |

## Vector Search (Semantic)

Vector search finds memories based on semantic similarity using embeddings.

### How It Works

```
User Query: "database optimization techniques"
      ↓
   Ollama Embedding (gpt-oss)
      ↓
  [0.234, -0.567, 0.123, ...]  ← 1536-dimensional vector
      ↓
   PostgreSQL + pgvector
      ↓
  Find nearest neighbors using cosine similarity
      ↓
  Results ranked by similarity score
```

### Basic Usage

```ruby
memories = htm.recall(
  timeframe: "last month",
  topic: "improving application performance",
  strategy: :vector,
  limit: 10
)

memories.each do |m|
  puts "#{m['value']}"
  puts "Similarity: #{m['similarity']}"  # 0.0 to 1.0
  puts
end
```

### Understanding Similarity Scores

Similarity scores indicate how related the memory is to your query:

```ruby
# High similarity (0.8-1.0): Very relevant
# - Query: "PostgreSQL optimization"
# - Result: "Optimizing PostgreSQL queries with indexes" (0.92)

# Medium similarity (0.6-0.8): Moderately relevant
# - Query: "database performance"
# - Result: "Caching strategies for web applications" (0.72)

# Low similarity (0.4-0.6): Loosely related
# - Query: "user authentication"
# - Result: "Session management best practices" (0.58)

# Very low similarity (<0.4): Probably not relevant
# - Query: "database backup"
# - Result: "Frontend styling with CSS" (0.23)
```

### When Vector Search Excels

**1. Conceptual Queries**

```ruby
# Query about concepts, not specific keywords
memories = htm.recall(
  timeframe: "last year",
  topic: "ways to speed up slow applications",
  strategy: :vector
)

# Finds:
# - "Database query optimization" (0.89)
# - "Caching strategies" (0.87)
# - "Code profiling techniques" (0.85)
# - "Load balancing approaches" (0.82)
```

**2. Related Topics**

```ruby
# Find related concepts even without exact keywords
memories = htm.recall(
  timeframe: "all time",
  topic: "machine learning",
  strategy: :vector
)

# Finds:
# - "Neural network architecture" (no "ML" keyword!)
# - "Training data preparation"
# - "Model evaluation metrics"
# - "Predictive analytics"
```

**3. Understanding Intent**

```ruby
# Different phrasings of same intent
queries = [
  "how to make code faster",
  "performance optimization techniques",
  "speeding up application execution",
  "reducing runtime overhead"
]

queries.each do |q|
  results = htm.recall(timeframe: "all time", topic: q, strategy: :vector)
  # All queries return similar results!
end
```

**4. Multilingual Support**

```ruby
# If embeddings support multiple languages
memories = htm.recall(
  timeframe: "all time",
  topic: "base de données",  # French: database
  strategy: :vector
)

# Can find English memories about databases
# (depends on embedding model's training)
```

### Vector Search Limitations

**1. Specific Terms**

```ruby
# Bad for exact technical terms
memories = htm.recall(
  timeframe: "all time",
  topic: "JWT",  # Specific acronym
  strategy: :vector
)

# May miss exact "JWT" mentions
# Better to use full-text for acronyms
```

**2. Proper Nouns**

```ruby
# Not ideal for names
memories = htm.recall(
  timeframe: "all time",
  topic: "Alice Thompson",
  strategy: :vector
)

# May not prioritize exact name matches
# Use full-text or hybrid instead
```

### Optimizing Vector Search

**1. Adjust Similarity Threshold**

```ruby
def vector_search_with_threshold(topic, threshold: 0.7)
  results = htm.recall(
    timeframe: "all time",
    topic: topic,
    strategy: :vector,
    limit: 50
  )

  # Filter by threshold
  results.select { |m| m['similarity'].to_f >= threshold }
end

high_quality = vector_search_with_threshold("database", threshold: 0.8)
```

**2. Use Descriptive Queries**

```ruby
# Vague: Returns less relevant results
htm.recall(topic: "API", strategy: :vector)

# Descriptive: Returns more relevant results
htm.recall(topic: "RESTful API design patterns and best practices", strategy: :vector)
```

**3. Query Expansion**

```ruby
def expanded_vector_search(base_query, related_terms)
  # Combine base query with related terms
  expanded = "#{base_query} #{related_terms.join(' ')}"

  htm.recall(
    timeframe: "all time",
    topic: expanded,
    strategy: :vector,
    limit: 20
  )
end

results = expanded_vector_search(
  "database",
  ["PostgreSQL", "SQL", "relational", "ACID"]
)
```

## Full-text Search (Keywords)

Full-text search uses PostgreSQL's powerful text search capabilities for exact keyword matching.

### How It Works

```
User Query: "PostgreSQL indexing"
      ↓
   PostgreSQL ts_query
      ↓
  Tokenize: ["postgresql", "index"]
      ↓
   Match against ts_vector in database
      ↓
  Rank by relevance (tf-idf)
      ↓
  Results ranked by text rank
```

### Basic Usage

```ruby
memories = htm.recall(
  timeframe: "last month",
  topic: "PostgreSQL indexing",
  strategy: :fulltext,
  limit: 10
)

memories.each do |m|
  puts "#{m['value']}"
  puts "Rank: #{m['rank']}"  # Higher = better match
  puts
end
```

### When Full-text Search Excels

**1. Exact Keywords**

```ruby
# Finding specific technical terms
memories = htm.recall(
  timeframe: "all time",
  topic: "JWT OAuth2 authentication",
  strategy: :fulltext
)

# Finds memories containing these exact terms
```

**2. Proper Nouns**

```ruby
# Finding people, places, products
memories = htm.recall(
  timeframe: "all time",
  topic: "Alice Thompson",
  strategy: :fulltext
)

# Exact name matches prioritized
```

**3. Acronyms**

```ruby
# Technical acronyms
memories = htm.recall(
  timeframe: "all time",
  topic: "REST API CRUD SQL",
  strategy: :fulltext
)

# Finds exact acronym matches
```

**4. Code and Commands**

```ruby
# Finding specific code or commands
memories = htm.recall(
  timeframe: "all time",
  topic: "pg_dump VACUUM",
  strategy: :fulltext
)

# Exact command matches
```

### Full-text Search Features

**1. Boolean Operators**

```ruby
# PostgreSQL supports AND, OR, NOT
memories = htm.recall(
  timeframe: "all time",
  topic: "PostgreSQL AND (indexing OR optimization)",
  strategy: :fulltext
)
```

**2. Phrase Matching**

```ruby
# Find exact phrases
memories = htm.recall(
  timeframe: "all time",
  topic: '"database connection pool"',  # Exact phrase
  strategy: :fulltext
)
```

**3. Stemming**

```ruby
# PostgreSQL automatically stems words
# "running" matches "run", "runs", "runner"

memories = htm.recall(
  timeframe: "all time",
  topic: "optimize",  # Matches "optimizing", "optimized", etc.
  strategy: :fulltext
)
```

### Full-text Search Limitations

**1. No Semantic Understanding**

```ruby
# Doesn't understand meaning
memories = htm.recall(
  timeframe: "all time",
  topic: "database",
  strategy: :fulltext
)

# Won't find "PostgreSQL" unless query includes it
# (PostgreSQL doesn't match "database" keyword)
```

**2. Keyword Dependency**

```ruby
# Must use exact keywords
memories = htm.recall(
  timeframe: "all time",
  topic: "speed up application",
  strategy: :fulltext
)

# Won't find "performance optimization"
# (different keywords, same concept)
```

### Optimizing Full-text Search

**1. Use Multiple Keywords**

```ruby
# Include variations and synonyms
memories = htm.recall(
  timeframe: "all time",
  topic: "database PostgreSQL SQL relational",
  strategy: :fulltext
)
```

**2. Wildcard Searches**

```ruby
# Use prefix matching (requires direct SQL)
config = HTM::Database.default_config
conn = PG.connect(config)

result = conn.exec_params(
  <<~SQL,
    SELECT key, value
    FROM nodes
    WHERE to_tsvector('english', value) @@ to_tsquery('english', $1)
  SQL
  ['postgres:*']  # Matches postgresql, postgres, etc.
)

conn.close
```

## Hybrid Search (Combined)

Hybrid search combines full-text and vector search for optimal results.

### How It Works

```
User Query: "PostgreSQL performance tuning"
      ↓
  Step 1: Full-text Search (Prefilter)
  - Find all memories with keywords
  - Limit to 100 candidates
      ↓
  Step 2: Vector Ranking
  - Generate query embedding
  - Rank candidates by similarity
      ↓
  Final Results
  - Keyword precision + Semantic understanding
```

### Basic Usage

```ruby
memories = htm.recall(
  timeframe: "last month",
  topic: "PostgreSQL performance optimization",
  strategy: :hybrid,
  limit: 10
)

# Results have both keyword matches AND semantic relevance
memories.each do |m|
  puts "#{m['value']}"
  puts "Similarity: #{m['similarity']}"
  puts
end
```

### When Hybrid Search Excels

**1. General Purpose Queries**

```ruby
# Best for most use cases
memories = htm.recall(
  timeframe: "all time",
  topic: "how to improve database query speed",
  strategy: :hybrid
)

# Combines:
# - Keyword matches (database, query, speed)
# - Semantic understanding (optimization, performance)
```

**2. Mixed Terminology**

```ruby
# Query with both specific and general terms
memories = htm.recall(
  timeframe: "all time",
  topic: "JWT token authentication security best practices",
  strategy: :hybrid
)

# Finds:
# - Exact "JWT" mentions (full-text)
# - Related security concepts (vector)
```

**3. Production Applications**

```ruby
# Recommended default for production
class ProductionSearch
  def search(query)
    htm.recall(
      timeframe: "last 90 days",
      topic: query,
      strategy: :hybrid,  # Best all-around
      limit: 20
    )
  end
end
```

### Hybrid Search Parameters

**Prefilter Limit**

The number of candidates from full-text search:

```ruby
# Internal parameter (not exposed in public API)
# Default: 100 candidates

# In LongTermMemory#search_hybrid:
# prefilter_limit: 100
```

For very large databases, you might want to adjust this:

```ruby
# Direct database query with custom prefilter
ltm = HTM::LongTermMemory.new(HTM::Database.default_config)
embedding_service = HTM::EmbeddingService.new

results = ltm.search_hybrid(
  timeframe: Time.at(0)..Time.now,
  query: "database optimization",
  limit: 10,
  embedding_service: embedding_service,
  prefilter_limit: 200  # More candidates
)
```

### Optimizing Hybrid Search

**1. Balance Keywords and Concepts**

```ruby
# Good: Mix of specific keywords and concepts
htm.recall(
  topic: "PostgreSQL query optimization indexing performance",
  strategy: :hybrid
)

# Suboptimal: Only keywords
htm.recall(topic: "PostgreSQL SQL", strategy: :hybrid)

# Suboptimal: Only concepts
htm.recall(topic: "making things faster", strategy: :hybrid)
```

**2. Use Appropriate Timeframes**

```ruby
# Narrow timeframe: Faster, more recent results
htm.recall(
  timeframe: "last week",
  topic: "recent errors",
  strategy: :hybrid
)

# Wide timeframe: Comprehensive, slower
htm.recall(
  timeframe: "last year",
  topic: "architecture decisions",
  strategy: :hybrid
)
```

## Strategy Comparison

### Performance Benchmarks

Approximate performance on 10,000 nodes:

```ruby
require 'benchmark'

Benchmark.bm(15) do |x|
  x.report("Vector:") do
    htm.recall(timeframe: "last month", topic: "database", strategy: :vector)
  end

  x.report("Full-text:") do
    htm.recall(timeframe: "last month", topic: "database", strategy: :fulltext)
  end

  x.report("Hybrid:") do
    htm.recall(timeframe: "last month", topic: "database", strategy: :hybrid)
  end
end

# Typical results (vary by query and data):
#                       user     system      total        real
# Vector:           0.150000   0.020000   0.170000 (  0.210000)
# Full-text:        0.080000   0.010000   0.090000 (  0.110000)
# Hybrid:           0.180000   0.025000   0.205000 (  0.250000)
```

### Accuracy Comparison

```ruby
# Test query: "improving application speed"

# Vector results (semantic understanding):
# 1. "Performance optimization techniques" (0.91)
# 2. "Code profiling for bottlenecks" (0.88)
# 3. "Caching strategies" (0.85)
# 4. "Database query optimization" (0.82)

# Full-text results (keyword matching):
# 1. "Application deployment speed" (0.95) - Has "application" & "speed"
# 2. "Improving code quality" (0.72) - Has "improving"
# (May miss relevant results without exact keywords)

# Hybrid results (best of both):
# 1. "Performance optimization techniques" (0.93)
# 2. "Application caching strategies" (0.91)
# 3. "Code profiling for bottlenecks" (0.89)
# 4. "Database query optimization" (0.86)
```

## Strategy Selection Guide

### Decision Tree

```
Start
  ↓
Do you need exact keyword matches?
  YES → Do you also need semantic understanding?
          YES → Use HYBRID
          NO  → Use FULL-TEXT
  NO  → Do you need conceptual/semantic search?
          YES → Use VECTOR
          NO  → Use HYBRID (default)
```

### Use Case Matrix

| Use Case | Recommended Strategy | Why |
|----------|---------------------|-----|
| General search | Hybrid | Best overall |
| Finding specific terms | Full-text | Exact matches |
| Conceptual queries | Vector | Understanding |
| Proper nouns/names | Full-text or Hybrid | Exact matching |
| Technical acronyms | Full-text | Keyword precision |
| Related topics | Vector | Semantic similarity |
| Production default | Hybrid | Balanced performance |
| Code/command search | Full-text | Exact syntax |
| Research queries | Vector | Conceptual understanding |

### Code Examples

```ruby
class SmartSearch
  def initialize(htm)
    @htm = htm
  end

  def search(query, timeframe: "last month")
    # Automatically choose strategy based on query
    strategy = detect_strategy(query)

    @htm.recall(
      timeframe: timeframe,
      topic: query,
      strategy: strategy,
      limit: 20
    )
  end

  private

  def detect_strategy(query)
    # Check for proper nouns (capital words)
    has_proper_nouns = query.match?(/\b[A-Z][a-z]+\b/)

    # Check for acronyms (all caps words)
    has_acronyms = query.match?(/\b[A-Z]{2,}\b/)

    # Check for specific technical terms
    has_technical_terms = query.match?(/\b(JWT|OAuth|SQL|API|REST)\b/)

    if has_acronyms || has_technical_terms
      :fulltext  # Use full-text for exact matches
    elsif has_proper_nouns
      :hybrid    # Mix of exact and semantic
    else
      :vector    # Conceptual search
    end
  end
end

# Usage
search = SmartSearch.new(htm)
search.search("JWT authentication")    # → Uses :fulltext
search.search("Alice Thompson said")   # → Uses :hybrid
search.search("performance issues")    # → Uses :vector
```

## Advanced Techniques

### 1. Multi-Strategy Search

```ruby
def comprehensive_search(query, timeframe: "last month")
  # Run all three strategies
  vector_results = htm.recall(
    timeframe: timeframe,
    topic: query,
    strategy: :vector,
    limit: 10
  )

  fulltext_results = htm.recall(
    timeframe: timeframe,
    topic: query,
    strategy: :fulltext,
    limit: 10
  )

  hybrid_results = htm.recall(
    timeframe: timeframe,
    topic: query,
    strategy: :hybrid,
    limit: 10
  )

  # Combine and deduplicate
  all_results = (vector_results + fulltext_results + hybrid_results)
    .uniq { |m| m['key'] }

  # Sort by best score
  all_results.sort_by do |m|
    -(m['similarity']&.to_f || m['rank']&.to_f || 0)
  end.first(15)
end
```

### 2. Fallback Strategy

```ruby
def search_with_fallback(query, timeframe: "last month")
  # Try hybrid first
  results = htm.recall(
    timeframe: timeframe,
    topic: query,
    strategy: :hybrid,
    limit: 10
  )

  # If no results, try vector (more flexible)
  if results.empty?
    warn "No hybrid results, trying vector search..."
    results = htm.recall(
      timeframe: timeframe,
      topic: query,
      strategy: :vector,
      limit: 10
    )
  end

  # If still no results, try full-text
  if results.empty?
    warn "No vector results, trying full-text search..."
    results = htm.recall(
      timeframe: timeframe,
      topic: query,
      strategy: :fulltext,
      limit: 10
    )
  end

  results
end
```

### 3. Confidence Scoring

```ruby
def search_with_confidence(query)
  results = htm.recall(
    timeframe: "all time",
    topic: query,
    strategy: :hybrid,
    limit: 20
  )

  # Add confidence scores
  results.map do |m|
    similarity = m['similarity'].to_f
    importance = m['importance'].to_f

    # Calculate confidence (0-100)
    confidence = (
      similarity * 60 +      # 60% weight on similarity
      (importance / 10.0) * 40  # 40% weight on importance
    ).round(2)

    m.merge('confidence' => confidence)
  end.sort_by { |m| -m['confidence'] }
end
```

## Troubleshooting

### No Results with Vector Search

```ruby
# If vector search returns nothing:
# 1. Check Ollama is running
# 2. Try broader query
# 3. Widen timeframe
# 4. Fall back to full-text

if vector_results.empty?
  # Try full-text as fallback
  htm.recall(topic: query, strategy: :fulltext)
end
```

### Poor Quality Results

```ruby
# Filter by quality threshold
def quality_search(query, min_similarity: 0.7)
  results = htm.recall(
    timeframe: "all time",
    topic: query,
    strategy: :hybrid,
    limit: 50
  )

  results.select { |m| m['similarity'].to_f >= min_similarity }
end
```

## Complete Example

```ruby
require 'htm'

htm = HTM.new(robot_name: "Search Demo")

# Add test data
htm.add_node("pg_001", "PostgreSQL indexing tutorial", type: :code, importance: 7.0)
htm.add_node("perf_001", "Performance optimization guide", type: :fact, importance: 8.0)
htm.add_node("cache_001", "Caching strategies for speed", type: :decision, importance: 9.0)

# Compare strategies
query = "how to make database faster"

puts "=== Vector Search (Semantic) ==="
vector = htm.recall(timeframe: "all time", topic: query, strategy: :vector)
vector.each { |m| puts "- #{m['value']} (#{m['similarity']})" }

puts "\n=== Full-text Search (Keywords) ==="
fulltext = htm.recall(timeframe: "all time", topic: query, strategy: :fulltext)
fulltext.each { |m| puts "- #{m['value']} (#{m['rank']})" }

puts "\n=== Hybrid Search (Combined) ==="
hybrid = htm.recall(timeframe: "all time", topic: query, strategy: :hybrid)
hybrid.each { |m| puts "- #{m['value']} (#{m['similarity']})" }
```

## Next Steps

- [**Recalling Memories**](recalling-memories.md) - Learn more about recall API
- [**Context Assembly**](context-assembly.md) - Use search results with LLMs
- [**Long-term Memory**](long-term-memory.md) - Understand the storage layer
