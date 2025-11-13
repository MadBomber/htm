# API Reference

Complete API documentation for HTM (Hierarchical Temporary Memory).

## Overview

HTM is a two-tier intelligent memory management system for LLM-based robots:

- **Working Memory**: Token-limited active context for immediate LLM use
- **Long-term Memory**: Durable PostgreSQL storage with RAG-based retrieval

## Class Hierarchy

```
HTM (main class)
├── HTM::WorkingMemory (token-limited active context)
├── HTM::LongTermMemory (PostgreSQL backend)
├── HTM::EmbeddingService (vector embeddings)
└── HTM::Database (schema setup and configuration)
```

## Class Diagram

<svg viewBox="0 0 800 600" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <defs>
    <style>
      .class-box { fill: #1e1e1e; stroke: #4a9eff; stroke-width: 2; }
      .class-title { fill: #4a9eff; font-family: monospace; font-size: 14px; font-weight: bold; }
      .class-method { fill: #cccccc; font-family: monospace; font-size: 11px; }
      .arrow { stroke: #4a9eff; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
      .label { fill: #888888; font-family: sans-serif; font-size: 10px; }
    </style>
    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#4a9eff" />
    </marker>
  </defs>

  <!-- HTM main class -->
  <rect x="300" y="20" width="200" height="180" class="class-box" rx="5"/>
  <text x="400" y="45" text-anchor="middle" class="class-title">HTM</text>
  <line x1="310" y1="55" x2="490" y2="55" stroke="#4a9eff" stroke-width="1"/>
  <text x="310" y="75" class="class-method">+ add_node()</text>
  <text x="310" y="90" class="class-method">+ recall()</text>
  <text x="310" y="105" class="class-method">+ retrieve()</text>
  <text x="310" y="120" class="class-method">+ forget()</text>
  <text x="310" y="135" class="class-method">+ create_context()</text>
  <text x="310" y="150" class="class-method">+ memory_stats()</text>
  <text x="310" y="165" class="class-method">+ which_robot_said()</text>
  <text x="310" y="180" class="class-method">+ conversation_timeline()</text>

  <!-- WorkingMemory -->
  <rect x="50" y="250" width="180" height="150" class="class-box" rx="5"/>
  <text x="140" y="275" text-anchor="middle" class="class-title">WorkingMemory</text>
  <line x1="60" y1="285" x2="220" y2="285" stroke="#4a9eff" stroke-width="1"/>
  <text x="60" y="305" class="class-method">+ add()</text>
  <text x="60" y="320" class="class-method">+ remove()</text>
  <text x="60" y="335" class="class-method">+ has_space?()</text>
  <text x="60" y="350" class="class-method">+ evict_to_make_space()</text>
  <text x="60" y="365" class="class-method">+ assemble_context()</text>
  <text x="60" y="380" class="class-method">+ token_count()</text>

  <!-- LongTermMemory -->
  <rect x="260" y="250" width="180" height="180" class="class-box" rx="5"/>
  <text x="350" y="275" text-anchor="middle" class="class-title">LongTermMemory</text>
  <line x1="270" y1="285" x2="430" y2="285" stroke="#4a9eff" stroke-width="1"/>
  <text x="270" y="305" class="class-method">+ add()</text>
  <text x="270" y="320" class="class-method">+ retrieve()</text>
  <text x="270" y="335" class="class-method">+ search()</text>
  <text x="270" y="350" class="class-method">+ search_fulltext()</text>
  <text x="270" y="365" class="class-method">+ search_hybrid()</text>
  <text x="270" y="380" class="class-method">+ add_relationship()</text>
  <text x="270" y="395" class="class-method">+ add_tag()</text>
  <text x="270" y="410" class="class-method">+ stats()</text>

  <!-- EmbeddingService -->
  <rect x="470" y="250" width="180" height="120" class="class-box" rx="5"/>
  <text x="560" y="275" text-anchor="middle" class="class-title">EmbeddingService</text>
  <line x1="480" y1="285" x2="640" y2="285" stroke="#4a9eff" stroke-width="1"/>
  <text x="480" y="305" class="class-method">+ embed()</text>
  <text x="480" y="320" class="class-method">+ count_tokens()</text>
  <text x="480" y="335" class="class-method">- embed_ollama()</text>
  <text x="480" y="350" class="class-method">- embed_openai()</text>

  <!-- Database -->
  <rect x="300" y="470" width="200" height="90" class="class-box" rx="5"/>
  <text x="400" y="495" text-anchor="middle" class="class-title">Database</text>
  <line x1="310" y1="505" x2="490" y2="505" stroke="#4a9eff" stroke-width="1"/>
  <text x="310" y="525" class="class-method">+ setup()</text>
  <text x="310" y="540" class="class-method">+ default_config()</text>

  <!-- Arrows -->
  <path d="M 400 200 L 140 250" class="arrow"/>
  <text x="250" y="220" class="label">uses</text>

  <path d="M 400 200 L 350 250" class="arrow"/>
  <text x="370" y="220" class="label">uses</text>

  <path d="M 400 200 L 560 250" class="arrow"/>
  <text x="480" y="220" class="label">uses</text>

  <path d="M 400 200 L 400 470" class="arrow"/>
  <text x="410" y="340" class="label">config</text>
</svg>

## Quick Reference

### Core Classes

| Class | Purpose | Key Methods |
|-------|---------|-------------|
| [HTM](htm.md) | Main interface for memory management | `add_node`, `recall`, `retrieve`, `forget`, `create_context` |
| [WorkingMemory](working-memory.md) | Token-limited active context | `add`, `evict_to_make_space`, `assemble_context` |
| [LongTermMemory](long-term-memory.md) | Persistent PostgreSQL storage | `add`, `search`, `search_fulltext`, `search_hybrid` |
| [EmbeddingService](embedding-service.md) | Vector embedding generation | `embed`, `count_tokens` |
| [Database](database.md) | Schema setup and configuration | `setup`, `default_config` |

### Common Usage Patterns

#### Basic Memory Operations

```ruby
# Initialize HTM
htm = HTM.new(robot_name: "Assistant")

# Add memories
htm.add_node("fact_001", "PostgreSQL is our database",
  type: :fact, importance: 7.0, tags: ["database"])

# Recall memories
memories = htm.recall(timeframe: "last week", topic: "PostgreSQL")

# Create LLM context
context = htm.create_context(strategy: :balanced)
```

#### Multi-Robot Collaboration

```ruby
# Find who discussed a topic
robots = htm.which_robot_said("deployment")
# => {"robot-123" => 5, "robot-456" => 3}

# Get conversation timeline
timeline = htm.conversation_timeline("deployment", limit: 20)
```

#### Advanced Retrieval

```ruby
# Vector similarity search
memories = htm.recall(
  timeframe: "last 30 days",
  topic: "API design decisions",
  strategy: :vector,
  limit: 10
)

# Hybrid search (fulltext + vector)
memories = htm.recall(
  timeframe: "this month",
  topic: "security vulnerabilities",
  strategy: :hybrid,
  limit: 20
)
```

#### Memory Management

```ruby
# Get statistics
stats = htm.memory_stats
# => { total_nodes: 1234, working_memory: { current_tokens: 45000, ... }, ... }

# Explicitly forget
htm.forget("temp_note", confirm: :confirmed)
```

## Search Strategies

HTM supports three search strategies for `recall`:

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `:vector` | Semantic similarity using embeddings | Find conceptually related content |
| `:fulltext` | PostgreSQL full-text search | Find exact terms and phrases |
| `:hybrid` | Combines fulltext + vector | Best of both worlds - accurate and semantic |

## Memory Types

When adding nodes, you can specify a type:

| Type | Purpose |
|------|---------|
| `:fact` | Factual information |
| `:context` | Contextual background |
| `:code` | Code snippets |
| `:preference` | User preferences |
| `:decision` | Architectural decisions |
| `:question` | Questions and answers |

## Context Assembly Strategies

When creating context with `create_context`:

| Strategy | Behavior |
|----------|----------|
| `:recent` | Most recently accessed first |
| `:important` | Highest importance scores first |
| `:balanced` | Weighted by importance and recency |

## API Documentation

- [HTM](htm.md) - Main class reference
- [WorkingMemory](working-memory.md) - Active context management
- [LongTermMemory](long-term-memory.md) - Persistent storage
- [EmbeddingService](embedding-service.md) - Vector embeddings
- [Database](database.md) - Schema and configuration

## Error Handling

HTM raises standard Ruby exceptions:

```ruby
# ArgumentError for invalid parameters
htm.forget("key")  # Raises: Must pass confirm: :confirmed

# PG::Error for database issues
htm.add_node("key", "value")  # May raise PG connection errors

# Invalid timeframe
htm.recall(timeframe: "invalid")  # Raises ArgumentError
```

## Thread Safety

HTM is **not thread-safe** by default. Each instance maintains its own working memory state. For multi-threaded applications:

- Use separate HTM instances per thread
- Or implement external synchronization
- Database connections are created per operation (safe)

## Performance Considerations

- **Working Memory**: O(n) for eviction, O(1) for add/remove
- **Vector Search**: O(log n) with proper indexing
- **Fulltext Search**: O(log n) with GIN indexes
- **Hybrid Search**: Combines both overhead

For large memory stores (>100K nodes):

- Use hybrid search with appropriate `prefilter_limit`
- Consider time-based partitioning (automatic with TimescaleDB)
- Enable compression for old data (configured in schema)

## Next Steps

- See [HTM class reference](htm.md) for detailed API
- Review [examples](https://github.com/madbomber/htm/tree/main/examples) for common patterns
- Check [database schema](../development/schema.md) for advanced queries
