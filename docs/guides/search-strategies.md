# Search Strategies Deep Dive

HTM provides three search strategies for retrieving memories: vector search, full-text search, and tag-enhanced hybrid search. This guide explores each strategy in depth, when to use them, and how to optimize performance.

## Overview

| Strategy | Method | Strength | Best For |
|----------|--------|----------|----------|
| **Vector** | Semantic similarity via embeddings | Understanding meaning | Conceptual queries, related topics |
| **Full-text** | PostgreSQL text search | Exact keyword matching | Specific terms, proper nouns |
| **Hybrid** | Vector + fulltext + tag matching | Best overall accuracy | General purpose queries |

<svg viewBox="0 0 900 650" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <!-- Title -->
  <text x="450" y="30" text-anchor="middle" fill="#E0E0E0" font-size="18" font-weight="bold">HTM Search Strategy Comparison</text>

  <!-- Vector Search Strategy -->
  <rect x="30" y="70" width="260" height="250" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="3" rx="5"/>
  <text x="160" y="100" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Vector Search</text>
  <text x="160" y="125" text-anchor="middle" fill="#2196F3" font-size="13" font-weight="bold">Semantic Similarity</text>

  <text x="50" y="155" fill="#B0B0B0" font-size="12" font-weight="bold">How it works:</text>
  <text x="50" y="175" fill="#B0B0B0" font-size="11">• Generate query embedding</text>
  <text x="50" y="195" fill="#B0B0B0" font-size="11">• Find nearest neighbors</text>
  <text x="50" y="215" fill="#B0B0B0" font-size="11">• Rank by cosine similarity</text>

  <text x="50" y="245" fill="#4CAF50" font-size="12" font-weight="bold">Best for:</text>
  <text x="50" y="265" fill="#4CAF50" font-size="11">✓ Conceptual queries</text>
  <text x="50" y="285" fill="#4CAF50" font-size="11">✓ Related topics</text>
  <text x="50" y="305" fill="#4CAF50" font-size="11">✓ Understanding intent</text>

  <!-- Full-text Search Strategy -->
  <rect x="320" y="70" width="260" height="250" fill="rgba(76, 175, 80, 0.2)" stroke="#4CAF50" stroke-width="3" rx="5"/>
  <text x="450" y="100" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Full-Text Search</text>
  <text x="450" y="125" text-anchor="middle" fill="#4CAF50" font-size="13" font-weight="bold">Keyword Matching</text>

  <text x="340" y="155" fill="#B0B0B0" font-size="12" font-weight="bold">How it works:</text>
  <text x="340" y="175" fill="#B0B0B0" font-size="11">• Tokenize query</text>
  <text x="340" y="195" fill="#B0B0B0" font-size="11">• Match against ts_vector</text>
  <text x="340" y="215" fill="#B0B0B0" font-size="11">• Rank by tf-idf</text>

  <text x="340" y="245" fill="#2196F3" font-size="12" font-weight="bold">Best for:</text>
  <text x="340" y="265" fill="#2196F3" font-size="11">✓ Exact keywords</text>
  <text x="340" y="285" fill="#2196F3" font-size="11">✓ Proper nouns</text>
  <text x="340" y="305" fill="#2196F3" font-size="11">✓ Acronyms & commands</text>

  <!-- Hybrid Search Strategy -->
  <rect x="610" y="70" width="260" height="250" fill="rgba(156, 39, 176, 0.2)" stroke="#9C27B0" stroke-width="3" rx="5"/>
  <text x="740" y="100" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Hybrid Search</text>
  <text x="740" y="125" text-anchor="middle" fill="#9C27B0" font-size="13" font-weight="bold">Best of Both Worlds</text>

  <text x="630" y="155" fill="#B0B0B0" font-size="12" font-weight="bold">How it works:</text>
  <text x="630" y="175" fill="#B0B0B0" font-size="11">• Run both searches</text>
  <text x="630" y="195" fill="#B0B0B0" font-size="11">• Apply RRF scoring</text>
  <text x="630" y="215" fill="#B0B0B0" font-size="11">• Merge & rank results</text>

  <text x="630" y="245" fill="#FFC107" font-size="12" font-weight="bold">Best for:</text>
  <text x="630" y="265" fill="#FFC107" font-size="11">✓ General queries</text>
  <text x="630" y="285" fill="#FFC107" font-size="11">✓ Production default</text>
  <text x="630" y="305" fill="#FFC107" font-size="11">✓ Mixed terminology</text>

  <!-- Example Query -->
  <text x="450" y="365" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Example Query: "improve database performance"</text>

  <!-- Vector Results -->
  <rect x="30" y="390" width="260" height="230" fill="rgba(33, 150, 243, 0.1)" stroke="#2196F3" stroke-width="2" rx="3"/>
  <text x="160" y="415" text-anchor="middle" fill="#2196F3" font-size="13" font-weight="bold">Vector Results</text>
  <text x="50" y="440" fill="#B0B0B0" font-size="10">1. "Query optimization" (0.92)</text>
  <text x="50" y="460" fill="#B0B0B0" font-size="10">2. "Caching strategies" (0.87)</text>
  <text x="50" y="480" fill="#B0B0B0" font-size="10">3. "Index tuning" (0.85)</text>
  <text x="50" y="500" fill="#B0B0B0" font-size="10">4. "Connection pooling" (0.82)</text>
  <text x="160" y="530" text-anchor="middle" fill="#4CAF50" font-size="11" font-weight="bold">Finds conceptually</text>
  <text x="160" y="550" text-anchor="middle" fill="#4CAF50" font-size="11" font-weight="bold">related memories</text>
  <text x="160" y="570" text-anchor="middle" fill="#FF9800" font-size="10">(May miss exact terms)</text>
  <text x="160" y="600" text-anchor="middle" fill="#B0B0B0" font-size="10">Speed: ~80ms</text>

  <!-- Full-text Results -->
  <rect x="320" y="390" width="260" height="230" fill="rgba(76, 175, 80, 0.1)" stroke="#4CAF50" stroke-width="2" rx="3"/>
  <text x="450" y="415" text-anchor="middle" fill="#4CAF50" font-size="13" font-weight="bold">Full-Text Results</text>
  <text x="340" y="440" fill="#B0B0B0" font-size="10">1. "Database performance" (0.95)</text>
  <text x="340" y="460" fill="#B0B0B0" font-size="10">2. "Improve query speed" (0.88)</text>
  <text x="340" y="480" fill="#B0B0B0" font-size="10">3. "Performance testing" (0.72)</text>
  <text x="340" y="500" fill="#B0B0B0" font-size="10">(May miss related concepts)</text>
  <text x="450" y="530" text-anchor="middle" fill="#2196F3" font-size="11" font-weight="bold">Finds exact keyword</text>
  <text x="450" y="550" text-anchor="middle" fill="#2196F3" font-size="11" font-weight="bold">matches</text>
  <text x="450" y="570" text-anchor="middle" fill="#FF9800" font-size="10">(Needs right words)</text>
  <text x="450" y="600" text-anchor="middle" fill="#B0B0B0" font-size="10">Speed: ~30ms</text>

  <!-- Hybrid Results -->
  <rect x="610" y="390" width="260" height="230" fill="rgba(156, 39, 176, 0.1)" stroke="#9C27B0" stroke-width="2" rx="3"/>
  <text x="740" y="415" text-anchor="middle" fill="#9C27B0" font-size="13" font-weight="bold">Hybrid Results</text>
  <text x="630" y="440" fill="#B0B0B0" font-size="10">1. "Database performance" (0.96)</text>
  <text x="630" y="460" fill="#B0B0B0" font-size="10">2. "Query optimization" (0.93)</text>
  <text x="630" y="480" fill="#B0B0B0" font-size="10">3. "Improve query speed" (0.91)</text>
  <text x="630" y="500" fill="#B0B0B0" font-size="10">4. "Caching strategies" (0.89)</text>
  <text x="740" y="530" text-anchor="middle" fill="#FFC107" font-size="11" font-weight="bold">Balanced precision</text>
  <text x="740" y="550" text-anchor="middle" fill="#FFC107" font-size="11" font-weight="bold">& recall</text>
  <text x="740" y="570" text-anchor="middle" fill="#4CAF50" font-size="10">(Recommended!)</text>
  <text x="740" y="600" text-anchor="middle" fill="#B0B0B0" font-size="10">Speed: ~120ms</text>
</svg>

## Vector Search (Semantic)

Vector search finds memories based on semantic similarity using embeddings.

### How It Works

```
User Query: "database optimization techniques"
      ↓
   Embedding via RubyLLM (Ollama, OpenAI, etc.)
      ↓
  [0.234, -0.567, 0.123, ...]  ← Vector representation
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
  "improving application performance",
  timeframe: "last month",
  strategy: :vector,
  limit: 10,
  raw: true  # Get full node data with scores
)

memories.each do |m|
  puts "#{m['content']}"
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
  "ways to speed up slow applications",
  timeframe: "last year",
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
  "machine learning",
  timeframe: "all time",
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
  results = htm.recall(q, timeframe: "all time", strategy: :vector)
  # All queries return similar results!
end
```

**4. Multilingual Support**

```ruby
# If embeddings support multiple languages
memories = htm.recall(
  "base de données",  # French: database
  timeframe: "all time",
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
  "JWT",  # Specific acronym
  timeframe: "all time",
  strategy: :vector
)

# May miss exact "JWT" mentions
# Better to use full-text for acronyms
```

**2. Proper Nouns**

```ruby
# Not ideal for names
memories = htm.recall(
  "Alice Thompson",
  timeframe: "all time",
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
    topic,
    timeframe: "all time",
    strategy: :vector,
    limit: 50,
    raw: true  # Get hash with similarity scores
  )

  # Filter by threshold
  results.select { |m| m['similarity'].to_f >= threshold }
end

high_quality = vector_search_with_threshold("database", threshold: 0.8)
```

**2. Use Descriptive Queries**

```ruby
# Vague: Returns less relevant results
htm.recall("API", strategy: :vector)

# Descriptive: Returns more relevant results
htm.recall("RESTful API design patterns and best practices", strategy: :vector)
```

**3. Query Expansion**

```ruby
def expanded_vector_search(base_query, related_terms)
  # Combine base query with related terms
  expanded = "#{base_query} #{related_terms.join(' ')}"

  htm.recall(
    expanded,
    timeframe: "all time",
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
  "PostgreSQL indexing",
  timeframe: "last month",
  strategy: :fulltext,
  limit: 10,
  raw: true  # Get hash with rank scores
)

memories.each do |m|
  puts "#{m['content']}"
  puts "Rank: #{m['rank']}"  # Higher = better match
  puts
end
```

### When Full-text Search Excels

**1. Exact Keywords**

```ruby
# Finding specific technical terms
memories = htm.recall(
  "JWT OAuth2 authentication",
  timeframe: "all time",
  strategy: :fulltext
)

# Finds memories containing these exact terms
```

**2. Proper Nouns**

```ruby
# Finding people, places, products
memories = htm.recall(
  "Alice Thompson",
  timeframe: "all time",
  strategy: :fulltext
)

# Exact name matches prioritized
```

**3. Acronyms**

```ruby
# Technical acronyms
memories = htm.recall(
  "REST API CRUD SQL",
  timeframe: "all time",
  strategy: :fulltext
)

# Finds exact acronym matches
```

**4. Code and Commands**

```ruby
# Finding specific code or commands
memories = htm.recall(
  "pg_dump VACUUM",
  timeframe: "all time",
  strategy: :fulltext
)

# Exact command matches
```

### Full-text Search Features

**1. Boolean Operators**

```ruby
# PostgreSQL supports AND, OR, NOT
memories = htm.recall(
  "PostgreSQL AND (indexing OR optimization)",
  timeframe: "all time",
  strategy: :fulltext
)
```

**2. Phrase Matching**

```ruby
# Find exact phrases
memories = htm.recall(
  '"database connection pool"',  # Exact phrase
  timeframe: "all time",
  strategy: :fulltext
)
```

**3. Stemming**

```ruby
# PostgreSQL automatically stems words
# "running" matches "run", "runs", "runner"

memories = htm.recall(
  "optimize",  # Matches "optimizing", "optimized", etc.
  timeframe: "all time",
  strategy: :fulltext
)
```

### Full-text Search Limitations

**1. No Semantic Understanding**

```ruby
# Doesn't understand meaning
memories = htm.recall(
  "database",
  timeframe: "all time",
  strategy: :fulltext
)

# Won't find "PostgreSQL" unless query includes it
# (PostgreSQL doesn't match "database" keyword)
```

**2. Keyword Dependency**

```ruby
# Must use exact keywords
memories = htm.recall(
  "speed up application",
  timeframe: "all time",
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
  "database PostgreSQL SQL relational",
  timeframe: "all time",
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

## Hybrid Search (Tag-Enhanced)

Hybrid search combines full-text, vector, and tag matching for optimal results. This is the recommended strategy for most use cases.

### How It Works

```
User Query: "PostgreSQL performance tuning"
      ↓
  Step 1: Find Matching Tags
  - Search tags for query terms (3+ chars)
  - E.g., finds "database:postgresql", "performance:optimization"
      ↓
  Step 2: Build Candidate Pool
  - Full-text matches (keyword)
  - Nodes with matching tags (categorical)
      ↓
  Step 3: Score and Rank
  - Vector similarity (semantic)
  - Tag boost (categorical match)
  - Combined score: (similarity × 0.7) + (tag_boost × 0.3)
      ↓
  Final Results
  - Keyword precision + Semantic understanding + Tag relevance
```

### Basic Usage

```ruby
memories = htm.recall(
  "PostgreSQL performance optimization",
  timeframe: "last month",
  strategy: :hybrid,
  limit: 10,
  raw: true  # Get full node data with scores
)

# Results have keyword matches, semantic relevance, AND tag boosting
memories.each do |m|
  puts "#{m['content']}"
  puts "Similarity: #{m['similarity']}"     # Vector similarity (0-1)
  puts "Tag Boost: #{m['tag_boost']}"        # Tag match score (0-1)
  puts "Combined: #{m['combined_score']}"   # Weighted combination
  puts
end
```

### Tag-Enhanced Scoring

The hybrid search automatically:

1. **Finds matching tags**: Searches tags for query term matches
2. **Includes tagged nodes**: Adds nodes with matching tags to candidate pool
3. **Calculates combined score**: `(similarity × 0.7) + (tag_boost × 0.3)`

```ruby
# Check which tags match a query
matching_tags = htm.long_term_memory.find_query_matching_tags("PostgreSQL database")
# => ["database:postgresql", "database:postgresql:extensions", "database:sql"]

# These tags boost relevance of associated nodes in hybrid search
```

### When Hybrid Search Excels

**1. General Purpose Queries**

```ruby
# Best for most use cases
memories = htm.recall(
  "how to improve database query speed",
  timeframe: "last year",
  strategy: :hybrid,
  raw: true
)

# Combines:
# - Keyword matches (database, query, speed)
# - Semantic understanding (optimization, performance)
# - Tag boost (nodes tagged with "database:*")
```

**2. Mixed Terminology**

```ruby
# Query with both specific and general terms
memories = htm.recall(
  "JWT token authentication security best practices",
  timeframe: "last year",
  strategy: :hybrid,
  raw: true
)

# Finds:
# - Exact "JWT" mentions (full-text)
# - Related security concepts (vector)
# - Nodes tagged "auth:jwt", "security:*" (tag boost)
```

**3. Production Applications**

```ruby
# Recommended default for production
class ProductionSearch
  def initialize(htm)
    @htm = htm
  end

  def search(query, timeframe: "last 90 days")
    @htm.recall(
      query,
      timeframe: timeframe,
      strategy: :hybrid,  # Best all-around
      limit: 20,
      raw: true
    )
  end
end
```

### Hybrid Search Parameters

**Prefilter Limit**

The number of candidates considered from each source (fulltext and tags):

```ruby
# In LongTermMemory#search_hybrid:
# prefilter_limit: 100 (default)

# Direct access with custom prefilter
results = htm.long_term_memory.search_hybrid(
  timeframe: (Time.now - 365*24*3600)..Time.now,
  query: "database optimization",
  limit: 10,
  embedding_service: HTM::EmbeddingService.new,
  prefilter_limit: 200  # More candidates
)
```

### Optimizing Hybrid Search

**1. Balance Keywords and Concepts**

```ruby
# Good: Mix of specific keywords and concepts
htm.recall(
  "PostgreSQL query optimization indexing performance",
  strategy: :hybrid
)

# Suboptimal: Only keywords
htm.recall("PostgreSQL SQL", strategy: :hybrid)

# Suboptimal: Only concepts
htm.recall("making things faster", strategy: :hybrid)
```

**2. Use Appropriate Timeframes**

```ruby
# Narrow timeframe: Faster, more recent results
htm.recall(
  "recent errors",
  timeframe: "last week",
  strategy: :hybrid
)

# Wide timeframe: Comprehensive, slower
htm.recall(
  "architecture decisions",
  timeframe: "last year",
  strategy: :hybrid
)
```

**3. Check Tag Coverage**

```ruby
# See which tags exist for better query formulation
popular = htm.long_term_memory.popular_tags(limit: 20)
popular.each do |tag|
  puts "#{tag[:name]}: #{tag[:usage_count]} nodes"
end
```

## Strategy Comparison

### Performance Benchmarks

Approximate performance on 10,000 nodes:

```ruby
require 'benchmark'

Benchmark.bm(15) do |x|
  x.report("Vector:") do
    htm.recall("database", timeframe: "last month", strategy: :vector)
  end

  x.report("Full-text:") do
    htm.recall("database", timeframe: "last month", strategy: :fulltext)
  end

  x.report("Hybrid:") do
    htm.recall("database", timeframe: "last month", strategy: :hybrid)
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
      query,
      timeframe: timeframe,
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
  # Run all three strategies with raw: true for hash access
  vector_results = htm.recall(
    query,
    timeframe: timeframe,
    strategy: :vector,
    limit: 10,
    raw: true
  )

  fulltext_results = htm.recall(
    query,
    timeframe: timeframe,
    strategy: :fulltext,
    limit: 10,
    raw: true
  )

  hybrid_results = htm.recall(
    query,
    timeframe: timeframe,
    strategy: :hybrid,
    limit: 10,
    raw: true
  )

  # Combine and deduplicate
  all_results = (vector_results + fulltext_results + hybrid_results)
    .uniq { |m| m['id'] }

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
    query,
    timeframe: timeframe,
    strategy: :hybrid,
    limit: 10
  )

  # If no results, try vector (more flexible)
  if results.empty?
    warn "No hybrid results, trying vector search..."
    results = htm.recall(
      query,
      timeframe: timeframe,
      strategy: :vector,
      limit: 10
    )
  end

  # If still no results, try full-text
  if results.empty?
    warn "No vector results, trying full-text search..."
    results = htm.recall(
      query,
      timeframe: timeframe,
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
    query,
    timeframe: "all time",
    strategy: :hybrid,
    limit: 20,
    raw: true  # Need hash access for scoring
  )

  # Add confidence scores
  results.map do |m|
    similarity = m['similarity'].to_f

    # Calculate confidence (0-100)
    confidence = (similarity * 100).round(2)

    m.merge('confidence' => confidence)
  end.sort_by { |m| -m['confidence'] }
end
```

## Troubleshooting

### No Results with Vector Search

```ruby
# If vector search returns nothing:
# 1. Check your LLM provider is accessible (Ollama running, API key set, etc.)
# 2. Try broader query
# 3. Widen timeframe
# 4. Fall back to full-text

if vector_results.empty?
  # Try full-text as fallback
  htm.recall(query, strategy: :fulltext)
end
```

### Poor Quality Results

```ruby
# Filter by quality threshold
def quality_search(query, min_similarity: 0.7)
  results = htm.recall(
    query,
    timeframe: "all time",
    strategy: :hybrid,
    limit: 50,
    raw: true
  )

  results.select { |m| m['similarity'].to_f >= min_similarity }
end
```

## Complete Example

```ruby
require 'htm'

htm = HTM.new(robot_name: "Search Demo")

# Add test data
htm.remember("PostgreSQL indexing tutorial", tags: ["code:sql"], metadata: { category: "code" })
htm.remember("Performance optimization guide", tags: ["performance"], metadata: { category: "fact" })
htm.remember("Caching strategies for speed", tags: ["caching"], metadata: { category: "decision" })

# Compare strategies
query = "how to make database faster"

puts "=== Vector Search (Semantic) ==="
vector = htm.recall(query, timeframe: "all time", strategy: :vector, raw: true)
vector.each { |m| puts "- #{m['content']} (#{m['similarity']})" }

puts "\n=== Full-text Search (Keywords) ==="
fulltext = htm.recall(query, timeframe: "all time", strategy: :fulltext, raw: true)
fulltext.each { |m| puts "- #{m['content']} (#{m['rank']})" }

puts "\n=== Hybrid Search (Combined) ==="
hybrid = htm.recall(query, timeframe: "all time", strategy: :hybrid, raw: true)
hybrid.each { |m| puts "- #{m['content']} (#{m['similarity']})" }
```

## Next Steps

- [**Recalling Memories**](recalling-memories.md) - Learn more about recall API
- [**Context Assembly**](context-assembly.md) - Use search results with LLMs
- [**Long-term Memory**](long-term-memory.md) - Understand the storage layer
