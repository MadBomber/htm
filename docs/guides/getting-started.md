# Getting Started with HTM

Welcome to HTM! This guide will help you build your first intelligent memory system for LLM-based applications.

## Prerequisites

Before starting, ensure you have:

1. **Ruby 3.0+** installed
2. **PostgreSQL with TimescaleDB** (or access to a TimescaleDB cloud instance)
3. **Ollama** installed and running (for embeddings)
4. Basic understanding of Ruby and LLMs

### Installing Ollama

HTM uses Ollama for generating vector embeddings by default:

```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull the gpt-oss model (default for HTM)
ollama pull gpt-oss

# Verify Ollama is running
curl http://localhost:11434/api/version
```

!!! tip
    The gpt-oss model provides high-quality embeddings optimized for semantic search. HTM uses these embeddings to understand the meaning of your memories, not just keyword matches.

## Installation

Add HTM to your Gemfile:

```ruby
gem 'htm'
```

Then install:

```bash
bundle install
```

Or install directly:

```bash
gem install htm
```

## Database Setup

HTM requires a TimescaleDB database. Set your database connection:

```bash
# Add to your .bashrc or .zshrc
export HTM_DBURL="postgresql://user:password@host:port/database"

# Or create a config file
echo "export HTM_DBURL='your-connection-string'" > ~/.bashrc__tiger
source ~/.bashrc__tiger
```

!!! warning
    Keep your database credentials secure. Never commit them to version control.

Initialize the database schema:

```ruby
require 'htm'

# Run once to create tables and indexes
HTM::Database.setup
```

Or from the command line:

```bash
ruby -r ./lib/htm -e "HTM::Database.setup"
```

## Your First HTM Application

Let's build a simple application that demonstrates HTM's core features.

### Basic Initialization

```ruby
require 'htm'

# Create an HTM instance for your robot
htm = HTM.new(
  robot_name: "My Assistant",
  working_memory_size: 128_000  # 128K tokens
)

puts "Robot initialized: #{htm.robot_name}"
puts "Robot ID: #{htm.robot_id}"
```

!!! note
    Each HTM instance represents a "robot" - an agent with its own identity. All robots share the same long-term memory database (hive mind), but each has its own working memory.

### Adding Your First Memory

```ruby
# Add a fact about the user
node_id = htm.remember(
  "The user's name is Alice",             # Content
  tags: ["user", "identity"],             # Tags for categorization
  metadata: { category: "fact" }          # Metadata for priority/categorization
)

puts "Memory added with ID: #{node_id}"
```

### Using Tags and Metadata

HTM uses hierarchical tags and flexible metadata to categorize memories:

```ruby
# Facts: Immutable truths
htm.remember(
  "The user lives in San Francisco",
  tags: ["user:location"],
  metadata: { category: "fact", priority: "high" }
)

# Context: Conversation state
htm.remember(
  "Currently discussing database architecture for a new project",
  tags: ["conversation:topic"],
  metadata: { category: "context" }
)

# Preferences: User preferences
htm.remember(
  "User prefers Ruby over Python for scripting",
  tags: ["user:preference", "language:ruby"],
  metadata: { category: "preference" }
)

# Decisions: Design decisions
htm.remember(
  "Decided to use PostgreSQL instead of MongoDB for better consistency",
  tags: ["architecture", "database:postgresql"],
  metadata: { category: "decision", priority: "critical" }
)

# Code: Code snippets
htm.remember(
  "def greet(name)\n  puts \"Hello, \#{name}!\"\nend",
  tags: ["code:ruby", "pattern:function"],
  metadata: { category: "code", language: "ruby" }
)

# Questions: Unresolved questions
htm.remember(
  "Should we add Redis caching to improve performance?",
  tags: ["performance", "caching"],
  metadata: { category: "question", resolved: false }
)
```

!!! tip "Organizing Memories"
    - Use hierarchical tags (e.g., `user:preference`, `database:postgresql`)
    - Use metadata for structured data (priority, category, resolved status)
    - Combine tags and metadata for powerful filtering

### Retrieving Memories

Retrieve a specific memory by its ID:

```ruby
# Retrieve by ID (returned from remember())
memory = htm.long_term_memory.retrieve(node_id)

if memory
  puts "Found: #{memory.content}"
  puts "Created: #{memory.created_at}"
end
```

### Recalling from the Past

Use HTM's RAG capabilities to recall relevant memories:

```ruby
# Recall memories about databases from the last week
memories = htm.recall(
  "database architecture",  # Topic is first positional argument
  timeframe: "last week",
  limit: 10,
  raw: true  # Get full hash with similarity scores
)

memories.each do |memory|
  puts "- #{memory['content']}"
  puts "  Similarity: #{memory['similarity']}"
  puts
end
```

!!! note "How Recall Works"
    HTM uses vector embeddings to understand the semantic meaning of your query. It finds memories that are conceptually related, not just keyword matches.

### Creating Context for LLMs

Assemble working memory into context for your LLM:

```ruby
# Get a balanced mix of important and recent memories
context = htm.working_memory.assemble_context(
  strategy: :balanced,
  max_tokens: 50_000
)

# Use this context in your LLM prompt
prompt = <<~PROMPT
  Context from memory:
  #{context}

  User: What database did we decide to use?

  Assistant:
PROMPT

# Send to your LLM...
```

## Common Patterns

### Pattern 1: Session Memory

Store conversation turns as memories:

```ruby
class ConversationTracker
  def initialize(session_id)
    @htm = HTM.new(robot_name: "Chat-#{session_id}")
    @turn = 0
  end

  def add_turn(user_message, assistant_response)
    @turn += 1

    # Store user message
    @htm.remember(
      user_message,
      tags: ["conversation", "user", "turn:#{@turn}"],
      metadata: { category: "context", turn: @turn, role: "user" }
    )

    # Store assistant response
    @htm.remember(
      assistant_response,
      tags: ["conversation", "assistant", "turn:#{@turn}"],
      metadata: { category: "context", turn: @turn, role: "assistant" }
    )
  end

  def recall_context
    @htm.working_memory.assemble_context(strategy: :recent, max_tokens: 10_000)
  end
end
```

### Pattern 2: Knowledge Base

Build a queryable knowledge base:

```ruby
class KnowledgeBase
  def initialize
    @htm = HTM.new(robot_name: "Knowledge Bot")
  end

  def add_fact(fact, category:, tags: [])
    @htm.remember(
      fact,
      tags: tags,
      metadata: { category: category, priority: "high" }
    )
  end

  def query(question)
    # Search all time for relevant facts
    @htm.recall(
      question,
      timeframe: "last 10 years",  # Effectively all memories
      limit: 5
    )
  end
end

# Usage
kb = KnowledgeBase.new
kb.add_fact(
  "Ruby 3.0 introduced Ractors for parallel execution",
  category: "programming",
  tags: ["ruby", "concurrency"]
)

results = kb.query("How does Ruby handle parallelism?")
```

### Pattern 3: Decision Journal

Track architectural decisions over time:

```ruby
class DecisionJournal
  def initialize(project_name)
    @htm = HTM.new(robot_name: "Architect-#{project_name}")
  end

  def record_decision(title, rationale, alternatives: [], tags: [])
    decision = <<~DECISION
      Decision: #{title}

      Rationale: #{rationale}

      #{alternatives.any? ? "Alternatives considered: #{alternatives.join(', ')}" : ''}
    DECISION

    @htm.remember(
      decision,
      tags: tags + ["decision"],
      metadata: { category: "decision", priority: "critical" }
    )
  end

  def get_decision_history(topic)
    @htm.recall(
      topic,
      timeframe: "last year",
      limit: 20,
      raw: true
    ).sort_by { |d| d['created_at'] }
  end
end
```

## Monitoring Memory Usage

Check working memory utilization:

```ruby
# Get current statistics
wm = htm.working_memory
puts "Nodes in working memory: #{wm.node_count}"
puts "Tokens used: #{wm.token_count} / #{wm.max_tokens}"
puts "Utilization: #{wm.utilization_percentage}%"

# Get comprehensive stats using ActiveRecord
puts "Total nodes in long-term: #{HTM::Models::Node.count}"
puts "Active robots: #{HTM::Models::Robot.count}"
```

!!! tip
    Monitor working memory utilization regularly. If you consistently hit 100%, consider increasing `working_memory_size` or implementing more aggressive eviction strategies.

## Best Practices for Beginners

### 1. Use Descriptive Content

```ruby
# Good: Clear, self-contained content
htm.remember(
  "User prefers dark theme for all interfaces",
  tags: ["user:preference", "ui:theme"],
  metadata: { category: "preference" }
)

# Bad: Vague or context-dependent
htm.remember("prefers dark", tags: ["pref"])
```

### 2. Use Metadata for Priority

```ruby
# Critical facts
htm.remember(
  "Production API endpoint: https://api.example.com",
  tags: ["api", "production"],
  metadata: { priority: "critical", category: "fact" }
)

# Important decisions
htm.remember(
  "Using microservices architecture for scalability",
  tags: ["architecture", "decision"],
  metadata: { priority: "high", category: "decision" }
)

# Contextual information
htm.remember(
  "Currently discussing weather API integration",
  tags: ["context", "conversation"],
  metadata: { priority: "medium", category: "context" }
)

# Temporary notes
htm.remember(
  "Remember to check server logs after deployment",
  tags: ["todo", "temporary"],
  metadata: { priority: "low", category: "note" }
)
```

### 3. Use Tags Liberally

```ruby
htm.remember(
  "Chose PostgreSQL for data persistence due to ACID compliance",
  tags: [
    "database",
    "architecture",
    "backend",
    "persistence",
    "database:postgresql"
  ],
  metadata: { category: "decision", priority: "high" }
)
```

### 4. Use Hierarchical Tags for Relationships

```ruby
# Add related memories using hierarchical tags
htm.remember(
  "Use PostgreSQL for primary data storage",
  tags: ["decision:database", "database:postgresql"],
  metadata: { category: "decision" }
)

htm.remember(
  "PG.connect(host: 'localhost', dbname: 'app_production')",
  tags: ["code:ruby", "database:postgresql", "decision:database"],
  metadata: { category: "code", language: "ruby" }
)

# Find related by shared tags
htm.recall("database:postgresql", timeframe: "last month", limit: 10)
```

### 5. Clean Up When Needed

```ruby
# Store the node_id when creating memories you may want to remove
node_id = htm.remember("Temporary calculation result", tags: ["scratch"])

# Later, soft delete (recoverable)
htm.forget(node_id)

# Or permanently delete with confirmation
htm.forget(node_id, soft: false, confirm: :confirmed)
```

!!! warning
    Permanent deletion requires explicit confirmation to prevent accidental data loss. Use soft delete (default) when possible - you can always restore with `htm.restore(node_id)`.

## Troubleshooting

### Ollama Connection Issues

If you see embedding errors:

```bash
# Check Ollama is running
curl http://localhost:11434/api/version

# If not running, start it
ollama serve

# Verify the model is available
ollama list
```

### Database Connection Issues

```ruby
# Test your connection
require 'htm'

begin
  HTM::Database.setup
  puts "Connection successful!"
rescue => e
  puts "Connection failed: #{e.message}"
end
```

### Memory Not Found

```ruby
# Retrieve by node_id (returned from remember())
node_id = 123  # Use the ID you saved when creating the memory
memory = htm.long_term_memory.retrieve(node_id)

if memory.nil?
  puts "Memory not found. Check the node ID."
else
  puts "Found: #{memory.content}"
end

# Or search for memories by content
results = htm.recall("what I'm looking for", timeframe: "last month", limit: 5)
if results.empty?
  puts "No matching memories found."
else
  puts "Found #{results.length} matches"
end
```

## Next Steps

Now that you understand the basics, explore these guides:

- [**Adding Memories**](adding-memories.md) - Deep dive into memory types and metadata
- [**Recalling Memories**](recalling-memories.md) - Master search strategies and retrieval
- [**Context Assembly**](context-assembly.md) - Optimize context for your LLM
- [**Working Memory**](working-memory.md) - Understand token limits and eviction

## Complete Example

Here's a complete working example combining everything:

```ruby
require 'htm'

# Initialize
htm = HTM.new(
  robot_name: "Demo Bot",
  working_memory_size: 128_000
)

# Add various memories
htm.remember(
  "User's name is Alice and she's a software engineer",
  tags: ["user", "identity", "profession"],
  metadata: { category: "fact", priority: "high" }
)

htm.remember(
  "Decided to use HTM for managing conversation memory",
  tags: ["architecture", "memory", "decision"],
  metadata: { category: "decision", priority: "critical" }
)

htm.remember(
  "Alice prefers detailed explanations with examples",
  tags: ["user", "communication", "user:preference"],
  metadata: { category: "preference" }
)

# Recall relevant memories
memories = htm.recall(
  "user preferences",  # Topic is positional
  timeframe: "last 7 days",
  limit: 5,
  raw: true  # Get full hash with similarity scores
)

puts "Found #{memories.length} relevant memories:"
memories.each do |m|
  puts "- #{m['content']}"
end

# Create context for LLM
context = htm.working_memory.assemble_context(strategy: :balanced)
puts "\nContext length: #{context.length} characters"

# Check stats
wm = htm.working_memory
puts "\nMemory statistics:"
puts "- Total nodes in database: #{HTM::Models::Node.count}"
puts "- Working memory nodes: #{wm.node_count}"
puts "- Working memory: #{wm.utilization_percentage}% full"
```

Happy coding with HTM!
