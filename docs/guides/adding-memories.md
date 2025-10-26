# Adding Memories to HTM

This guide covers everything you need to know about storing information in HTM effectively.

## Basic Usage

The primary method for adding memories is `add_node`:

```ruby
node_id = htm.add_node(
  key,                    # Unique identifier
  value,                  # Content (string)
  type: :fact,           # Memory type
  category: nil,         # Optional category
  importance: 1.0,       # Importance score (0.0-10.0)
  related_to: [],        # Array of related node keys
  tags: []              # Array of tags
)
```

The method returns the database ID of the created node.

## Memory Types Deep Dive

HTM supports six memory types, each optimized for specific use cases.

### :fact - Immutable Facts

Facts are unchanging truths about the world, users, or systems.

```ruby
# User information
htm.add_node(
  "user_name",
  "The user's name is Alice Thompson",
  type: :fact,
  importance: 9.0,
  tags: ["user", "identity"]
)

# System configuration
htm.add_node(
  "system_timezone",
  "System timezone is UTC",
  type: :fact,
  importance: 6.0,
  tags: ["system", "config"]
)

# Domain knowledge
htm.add_node(
  "fact_photosynthesis",
  "Photosynthesis converts light energy into chemical energy in plants",
  type: :fact,
  importance: 7.0,
  tags: ["biology", "science"]
)
```

!!! tip "When to Use :fact"
    - User profile information (name, email, preferences)
    - System configuration that rarely changes
    - Scientific facts or domain knowledge
    - Historical events
    - API endpoints and credentials

### :context - Conversation State

Context captures the current state of conversations or sessions.

```ruby
# Current conversation topic
htm.add_node(
  "context_#{session_id}_001",
  "User is asking about database performance optimization",
  type: :context,
  importance: 6.0,
  tags: ["conversation", "current"]
)

# Conversation mood
htm.add_node(
  "context_mood",
  "User seems frustrated with slow query times",
  type: :context,
  importance: 7.0,
  tags: ["conversation", "sentiment"]
)

# Current task
htm.add_node(
  "context_task",
  "Helping user optimize their PostgreSQL queries",
  type: :context,
  importance: 8.0,
  tags: ["task", "active"]
)
```

!!! tip "When to Use :context"
    - Current conversation topics
    - Session state
    - Temporary workflow status
    - User's current goals or questions
    - Conversation sentiment or mood

!!! note
    Context memories are typically lower importance (4-6) since they become outdated quickly. They'll naturally get evicted from working memory as new context arrives.

### :code - Code Snippets and Patterns

Store code examples, patterns, and technical solutions.

```ruby
# Function example
htm.add_node(
  "code_date_parser",
  <<~CODE,
    def parse_date(date_string)
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  CODE
  type: :code,
  importance: 6.0,
  tags: ["ruby", "date", "parsing"]
)

# SQL query pattern
htm.add_node(
  "code_user_query",
  <<~SQL,
    SELECT u.id, u.name, COUNT(o.id) as order_count
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
    GROUP BY u.id, u.name
    HAVING COUNT(o.id) > 10
  SQL
  type: :code,
  category: "sql",
  importance: 7.0,
  tags: ["sql", "aggregation", "joins"]
)

# Configuration example
htm.add_node(
  "code_redis_config",
  <<~YAML,
    redis:
      host: localhost
      port: 6379
      pool_size: 5
      timeout: 2
  YAML
  type: :code,
  category: "config",
  importance: 5.0,
  tags: ["redis", "configuration", "yaml"]
)
```

!!! tip "When to Use :code"
    - Reusable code snippets
    - Configuration examples
    - SQL queries and patterns
    - API request/response examples
    - Algorithm implementations
    - Regular expressions

### :preference - User Preferences

Store user preferences and settings.

```ruby
# Communication style
htm.add_node(
  "pref_communication",
  "User prefers concise answers with bullet points",
  type: :preference,
  importance: 8.0,
  tags: ["user", "communication", "style"]
)

# Technical preferences
htm.add_node(
  "pref_language",
  "User prefers Ruby over Python for scripting tasks",
  type: :preference,
  importance: 7.0,
  tags: ["user", "programming", "language"]
)

# UI preferences
htm.add_node(
  "pref_theme",
  "User uses dark theme in their IDE",
  type: :preference,
  importance: 4.0,
  tags: ["user", "ui", "theme"]
)

# Work preferences
htm.add_node(
  "pref_working_hours",
  "User typically codes in the morning, prefers design work in afternoon",
  type: :preference,
  importance: 5.0,
  tags: ["user", "schedule", "productivity"]
)
```

!!! tip "When to Use :preference"
    - Communication style preferences
    - Technical tool preferences
    - UI/UX preferences
    - Work habits and patterns
    - Learning style preferences

### :decision - Architectural Decisions

Track important decisions with rationale.

```ruby
# Technology choice
htm.add_node(
  "decision_database",
  <<~DECISION,
    Decision: Use PostgreSQL with TimescaleDB for HTM storage

    Rationale:
    - Excellent time-series optimization
    - Native vector search with pgvector
    - Strong consistency guarantees
    - Mature ecosystem

    Alternatives considered:
    - MongoDB (rejected: eventual consistency issues)
    - Redis (rejected: limited persistence)
  DECISION
  type: :decision,
  category: "architecture",
  importance: 9.5,
  tags: ["architecture", "database", "timescaledb"]
)

# Design pattern choice
htm.add_node(
  "decision_memory_architecture",
  <<~DECISION,
    Decision: Implement two-tier memory (working + long-term)

    Rationale:
    - Working memory provides fast access
    - Long-term memory ensures durability
    - Mirrors human memory architecture
    - Allows token-limited LLM context

    Trade-offs:
    - Added complexity in synchronization
    - Eviction strategy needs tuning
  DECISION
  type: :decision,
  category: "architecture",
  importance: 10.0,
  tags: ["architecture", "memory", "design-pattern"]
)

# Process decision
htm.add_node(
  "decision_testing",
  "Decided to use Minitest over RSpec for simplicity and speed",
  type: :decision,
  category: "process",
  importance: 6.0,
  tags: ["testing", "tools"]
)
```

!!! tip "When to Use :decision"
    - Technology selections
    - Architecture patterns
    - API design choices
    - Process decisions
    - Trade-off analysis results

!!! note "Decision Template"
    Include: what was decided, why, alternatives considered, and trade-offs. This context helps future decision-making.

### :question - Unresolved Questions

Track questions that need answering.

```ruby
# Technical question
htm.add_node(
  "question_caching",
  "Should we implement Redis caching for frequently accessed memories?",
  type: :question,
  importance: 7.0,
  tags: ["performance", "caching", "open"]
)

# Design question
htm.add_node(
  "question_auth",
  "How should we handle authentication for multi-robot scenarios?",
  type: :question,
  importance: 8.0,
  tags: ["security", "architecture", "open"]
)

# Research question
htm.add_node(
  "question_embeddings",
  "Would fine-tuning embeddings on our domain improve recall accuracy?",
  type: :question,
  importance: 6.0,
  tags: ["embeddings", "research", "open"]
)
```

!!! tip "When to Use :question"
    - Open technical questions
    - Design uncertainties
    - Research topics to investigate
    - Feature requests to evaluate
    - Performance questions

!!! tip "Closing Questions"
    When a question is answered, add a related decision node and mark the question as resolved by updating its tags.

## Importance Scoring Guidelines

The importance score (0.0-10.0) determines memory retention and eviction priority.

![Importance Scoring Framework](../assets/images/htm-importance-scoring-framework.svg)

### Scoring Framework

```ruby
# Critical (9.0-10.0): Must never lose
htm.add_node("api_key", "Production API key: ...", importance: 10.0)
htm.add_node("decision_architecture", "Core architecture decision", importance: 9.5)

# High (7.0-8.9): Very important, high retention
htm.add_node("user_identity", "User's name and email", importance: 8.0)
htm.add_node("major_decision", "Chose Rails for web framework", importance: 7.5)

# Medium (4.0-6.9): Moderately important
htm.add_node("code_snippet", "Useful utility function", importance: 6.0)
htm.add_node("context_current", "Current conversation topic", importance: 5.0)
htm.add_node("preference_minor", "Prefers tabs over spaces", importance: 4.0)

# Low (1.0-3.9): Nice to have, can evict
htm.add_node("temp_note", "Check logs later", importance: 3.0)
htm.add_node("minor_context", "Mentioned weather briefly", importance: 2.0)
htm.add_node("throwaway", "Temporary calculation result", importance: 1.0)
```

### Importance by Type

Typical importance ranges for each type:

| Type | Typical Range | Example |
|------|---------------|---------|
| `:fact` | 7.0-10.0 | User identity, system facts |
| `:decision` | 7.0-10.0 | Architecture, major choices |
| `:preference` | 4.0-8.0 | User preferences |
| `:code` | 4.0-7.0 | Code snippets, examples |
| `:context` | 3.0-6.0 | Conversation state |
| `:question` | 5.0-8.0 | Open questions |

!!! warning "Importance Affects Eviction"
    When working memory is full, HTM evicts memories with lower importance first. Set importance thoughtfully based on long-term value.

## Adding Relationships

Link related memories to build a knowledge graph:

```ruby
# Add a decision
htm.add_node(
  "decision_database",
  "Use PostgreSQL for data storage",
  type: :decision,
  importance: 9.0
)

# Add related implementation code
htm.add_node(
  "code_db_connection",
  "PG.connect(ENV['DATABASE_URL'])",
  type: :code,
  importance: 6.0,
  related_to: ["decision_database"]
)

# Add related configuration
htm.add_node(
  "fact_db_config",
  "Database uses connection pool of size 5",
  type: :fact,
  importance: 7.0,
  related_to: ["decision_database", "code_db_connection"]
)
```

!!! tip "Relationship Patterns"
    - Link implementation code to decisions
    - Connect questions to related facts
    - Link preferences to user facts
    - Connect related decisions (e.g., database choice → ORM choice)

## Categorization with Tags

Tags enable flexible organization and retrieval:

```ruby
# Use multiple tags for rich categorization
htm.add_node(
  "decision_api_design",
  "RESTful API with JSON responses",
  type: :decision,
  importance: 8.0,
  tags: [
    "api",           # Domain
    "rest",          # Approach
    "architecture",  # Category
    "backend",       # Layer
    "json",          # Format
    "http"           # Protocol
  ]
)
```

### Tag Naming Conventions

```ruby
# Good: Consistent, lowercase, descriptive
tags: ["user", "authentication", "security", "oauth"]

# Avoid: Inconsistent casing, vague terms
tags: ["User", "auth", "stuff", "misc"]
```

### Common Tag Patterns

```ruby
# Domain tags
tags: ["database", "api", "ui", "auth", "billing"]

# Layer tags
tags: ["frontend", "backend", "infrastructure", "data"]

# Status tags
tags: ["active", "deprecated", "experimental", "stable"]

# Priority tags
tags: ["critical", "high-priority", "low-priority"]

# Project tags
tags: ["project-alpha", "project-beta"]
```

## Advanced Patterns

### Timestamped Entries

Create time-series logs:

```ruby
def log_event(event_type, description)
  timestamp = Time.now.to_i

  htm.add_node(
    "event_#{event_type}_#{timestamp}",
    "#{event_type.upcase}: #{description}",
    type: :context,
    importance: 5.0,
    tags: ["event", event_type, "log"]
  )
end

log_event("error", "Database connection timeout")
log_event("performance", "Query took 3.2 seconds")
```

### Versioned Information

Track changes over time:

```ruby
def update_fact(base_key, new_value, version)
  # Add versioned node
  htm.add_node(
    "#{base_key}_v#{version}",
    new_value,
    type: :fact,
    importance: 8.0,
    tags: ["versioned", "v#{version}"],
    related_to: version > 1 ? ["#{base_key}_v#{version-1}"] : []
  )
end

update_fact("user_email", "alice@example.com", 1)
update_fact("user_email", "alice@newdomain.com", 2)
```

### Compound Memories

Store structured information:

```ruby
# User profile as compound memory
user_profile = {
  name: "Alice Thompson",
  email: "alice@example.com",
  role: "Senior Engineer",
  joined: "2023-01-15"
}.map { |k, v| "#{k}: #{v}" }.join("\n")

htm.add_node(
  "user_profile_001",
  user_profile,
  type: :fact,
  importance: 9.0,
  tags: ["user", "profile", "complete"]
)
```

### Conditional Importance

Adjust importance based on context:

```ruby
def add_memory_with_context(key, value, type, base_importance, current_project)
  # Boost importance for current project
  importance = base_importance
  importance += 2.0 if tags.include?(current_project)
  importance = [importance, 10.0].min  # Cap at 10.0

  htm.add_node(
    key,
    value,
    type: type,
    importance: importance,
    tags: [current_project, type.to_s]
  )
end
```

## Best Practices

### 1. Use Descriptive Keys

```ruby
# Good: Descriptive and namespaced
"user_profile_alice_001"
"decision_database_selection"
"code_authentication_jwt"

# Bad: Vague or collision-prone
"profile"
"dec1"
"code"
```

### 2. Be Consistent with Categories

```ruby
# Define standard categories
CATEGORIES = {
  architecture: "architecture",
  security: "security",
  performance: "performance",
  ui: "user-interface"
}

htm.add_node(
  key, value,
  category: CATEGORIES[:architecture]
)
```

### 3. Include Context in Values

```ruby
# Good: Self-contained
htm.add_node(
  "decision_001",
  "Decided to use Redis for session storage because it provides fast access and automatic expiration",
  type: :decision
)

# Bad: Requires external context
htm.add_node(
  "decision_001",
  "Use Redis",  # Why? For what?
  type: :decision
)
```

### 4. Tag Generously

```ruby
# Good: Rich tags for multiple retrieval paths
htm.add_node(
  "code_api_auth",
  "...",
  tags: ["api", "authentication", "security", "jwt", "middleware", "ruby"]
)

# Suboptimal: Minimal tags
htm.add_node(
  "code_api_auth",
  "...",
  tags: ["code"]
)
```

### 5. Use Relationships to Build Context

```ruby
# Create a narrative with relationships
decision_id = htm.add_node("decision_api", "Use GraphQL", type: :decision)

htm.add_node(
  "question_api",
  "How to handle file uploads in GraphQL?",
  type: :question,
  related_to: ["decision_api"]
)

htm.add_node(
  "code_upload",
  "GraphQL upload implementation",
  type: :code,
  related_to: ["decision_api", "question_api"]
)
```

## Common Pitfalls

### Pitfall 1: Duplicate Keys

```ruby
# This will fail - keys must be unique
htm.add_node("user_001", "Alice")
htm.add_node("user_001", "Bob")  # Error: key already exists
```

**Solution**: Use unique keys with timestamps or UUIDs:

```ruby
require 'securerandom'

htm.add_node("user_#{SecureRandom.hex(4)}", "Alice")
htm.add_node("user_#{SecureRandom.hex(4)}", "Bob")
```

### Pitfall 2: Too-High Importance

```ruby
# Don't make everything critical
htm.add_node("note", "Random thought", importance: 10.0)  # Too high!
```

**Solution**: Reserve high importance (9-10) for truly critical data.

### Pitfall 3: Missing Context

```ruby
# Bad: No context
htm.add_node("decision", "Chose option A", type: :decision)

# Good: Include rationale
htm.add_node(
  "decision_auth",
  "Chose OAuth 2.0 for authentication because it provides better security and is industry standard",
  type: :decision
)
```

### Pitfall 4: No Tags

```ruby
# Harder to find later
htm.add_node("code_001", "def foo...", type: :code)

# Better: Tags enable multiple retrieval paths
htm.add_node(
  "code_001",
  "def foo...",
  type: :code,
  tags: ["ruby", "functions", "utilities"]
)
```

## Performance Considerations

### Batch Operations

When adding many memories, consider transaction efficiency:

```ruby
# Instead of many individual adds
memories = [
  {key: "fact_001", value: "...", type: :fact},
  {key: "fact_002", value: "...", type: :fact},
  # ... many more
]

# Add them efficiently
memories.each do |m|
  htm.add_node(m[:key], m[:value], type: m[:type], importance: m[:importance])
end
```

!!! note
    Each `add_node` call generates embeddings via Ollama. For large batches, this can take time. Consider adding in the background or showing progress.

### Embedding Generation

Embedding generation has a cost:

```ruby
# Short text: Fast (~50ms)
htm.add_node("fact", "User name is Alice", ...)

# Long text: Slower (~500ms)
htm.add_node("code", "..." * 1000, ...)  # 1000 chars
```

!!! tip
    For very long content (>1000 tokens), consider splitting into multiple nodes or summarizing.

## Next Steps

Now that you know how to add memories effectively, learn about:

- [**Recalling Memories**](recalling-memories.md) - Search and retrieve memories
- [**Search Strategies**](search-strategies.md) - Optimize retrieval with different strategies
- [**Context Assembly**](context-assembly.md) - Use memories with your LLM

## Complete Example

```ruby
require 'htm'

htm = HTM.new(robot_name: "Memory Demo")

# Add a fact with rich metadata
htm.add_node(
  "user_profile",
  "Alice Thompson is a senior software engineer specializing in distributed systems",
  type: :fact,
  category: "user",
  importance: 9.0,
  tags: ["user", "profile", "engineering"]
)

# Add a related preference
htm.add_node(
  "user_pref_tools",
  "Alice prefers Vim for editing and tmux for terminal management",
  type: :preference,
  importance: 7.0,
  tags: ["user", "tools", "preferences"],
  related_to: ["user_profile"]
)

# Add a decision with context
htm.add_node(
  "decision_messaging",
  <<~DECISION,
    Decision: Use RabbitMQ for async job processing

    Rationale:
    - Need reliable message delivery
    - Support for multiple consumer patterns
    - Excellent Ruby client library

    Alternatives:
    - Redis (simpler but less reliable)
    - Kafka (overkill for our scale)
  DECISION
  type: :decision,
  category: "architecture",
  importance: 8.5,
  tags: ["architecture", "messaging", "rabbitmq", "async"]
)

# Add implementation code
htm.add_node(
  "code_rabbitmq_setup",
  <<~RUBY,
    require 'bunny'

    connection = Bunny.new(ENV['RABBITMQ_URL'])
    connection.start

    channel = connection.create_channel
    queue = channel.queue('jobs', durable: true)
  RUBY
  type: :code,
  importance: 6.0,
  tags: ["ruby", "rabbitmq", "setup", "code"],
  related_to: ["decision_messaging"]
)

# Add an open question
htm.add_node(
  "question_scaling",
  "Should we implement message partitioning for better scaling?",
  type: :question,
  importance: 7.0,
  tags: ["rabbitmq", "scaling", "performance", "open"],
  related_to: ["decision_messaging"]
)

puts "Added 5 memories with relationships and rich metadata"
puts "Stats: #{htm.memory_stats[:total_nodes]} total nodes"
```
