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
htm.add_node(
  "user_name",                    # Unique key
  "The user's name is Alice",     # Content
  type: :fact,                    # Memory type
  importance: 8.0,                # Importance score (0-10)
  tags: ["user", "identity"]      # Tags for categorization
)

puts "Memory added successfully!"
```

### Understanding Memory Types

HTM supports six memory types, each optimized for different purposes:

```ruby
# Facts: Immutable truths
htm.add_node(
  "fact_001",
  "The user lives in San Francisco",
  type: :fact,
  importance: 7.0
)

# Context: Conversation state
htm.add_node(
  "context_001",
  "Currently discussing database architecture for a new project",
  type: :context,
  importance: 6.0
)

# Preferences: User preferences
htm.add_node(
  "pref_001",
  "User prefers Ruby over Python for scripting",
  type: :preference,
  importance: 5.0
)

# Decisions: Design decisions
htm.add_node(
  "decision_001",
  "Decided to use PostgreSQL instead of MongoDB for better consistency",
  type: :decision,
  importance: 9.0,
  tags: ["architecture", "database"]
)

# Code: Code snippets
htm.add_node(
  "code_001",
  "def greet(name)\n  puts \"Hello, \#{name}!\"\nend",
  type: :code,
  importance: 4.0,
  tags: ["ruby", "functions"]
)

# Questions: Unresolved questions
htm.add_node(
  "question_001",
  "Should we add Redis caching to improve performance?",
  type: :question,
  importance: 6.0,
  tags: ["performance", "caching"]
)
```

!!! tip "Choosing the Right Type"
    - Use `:fact` for unchanging information
    - Use `:context` for temporary conversation state
    - Use `:preference` for user settings
    - Use `:decision` for important architectural choices
    - Use `:code` for code examples and snippets
    - Use `:question` for tracking open questions

### Retrieving Memories

Retrieve a specific memory by its key:

```ruby
memory = htm.retrieve("user_name")

if memory
  puts "Found: #{memory['value']}"
  puts "Type: #{memory['type']}"
  puts "Created: #{memory['created_at']}"
  puts "Importance: #{memory['importance']}"
end
```

### Recalling from the Past

Use HTM's RAG capabilities to recall relevant memories:

```ruby
# Recall memories about databases from the last week
memories = htm.recall(
  timeframe: "last week",
  topic: "database architecture",
  limit: 10
)

memories.each do |memory|
  puts "- #{memory['value']}"
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
context = htm.create_context(
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
    @htm.add_node(
      "turn_#{@turn}_user",
      user_message,
      type: :context,
      importance: 5.0,
      tags: ["conversation", "user"]
    )

    # Store assistant response
    @htm.add_node(
      "turn_#{@turn}_assistant",
      assistant_response,
      type: :context,
      importance: 5.0,
      tags: ["conversation", "assistant"],
      related_to: ["turn_#{@turn}_user"]
    )
  end

  def recall_context
    @htm.create_context(strategy: :recent, max_tokens: 10_000)
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

  def add_fact(key, fact, category:, tags: [])
    @htm.add_node(
      key,
      fact,
      type: :fact,
      category: category,
      importance: 8.0,
      tags: tags
    )
  end

  def query(question)
    # Search all time for relevant facts
    @htm.recall(
      timeframe: "last 10 years",  # Effectively all memories
      topic: question,
      limit: 5
    )
  end
end

# Usage
kb = KnowledgeBase.new
kb.add_fact(
  "ruby_version",
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
    key = "decision_#{Time.now.to_i}"

    decision = <<~DECISION
      Decision: #{title}

      Rationale: #{rationale}

      #{alternatives.any? ? "Alternatives considered: #{alternatives.join(', ')}" : ''}
    DECISION

    @htm.add_node(
      key,
      decision,
      type: :decision,
      importance: 9.0,
      tags: tags + ["decision"]
    )
  end

  def get_decision_history(topic)
    @htm.recall(
      timeframe: "last year",
      topic: topic,
      limit: 20
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

# Get comprehensive stats
stats = htm.memory_stats
puts "Total nodes in long-term: #{stats[:total_nodes]}"
puts "Active robots: #{stats[:active_robots]}"
puts "Database size: #{stats[:database_size] / (1024.0 * 1024.0)} MB"
```

!!! tip
    Monitor working memory utilization regularly. If you consistently hit 100%, consider increasing `working_memory_size` or implementing more aggressive eviction strategies.

## Best Practices for Beginners

### 1. Use Meaningful Keys

```ruby
# Good: Descriptive, unique keys
htm.add_node("user_pref_theme_dark", "User prefers dark theme", ...)

# Bad: Generic keys that might conflict
htm.add_node("pref", "User prefers dark theme", ...)
```

### 2. Set Appropriate Importance

```ruby
# Critical facts: 9-10
htm.add_node("api_key", "API key is: ...", importance: 10.0)

# Important decisions: 7-9
htm.add_node("arch_001", "Using microservices", importance: 8.0)

# Contextual information: 4-6
htm.add_node("ctx_001", "Discussing weather", importance: 5.0)

# Temporary notes: 1-3
htm.add_node("note_001", "Remember to check logs", importance: 2.0)
```

### 3. Use Tags Liberally

```ruby
htm.add_node(
  "decision_001",
  "Chose PostgreSQL for data persistence",
  type: :decision,
  importance: 9.0,
  tags: [
    "database",
    "architecture",
    "backend",
    "persistence",
    "postgresql"
  ]
)
```

### 4. Leverage Relationships

```ruby
# Add related memories
htm.add_node("decision_db", "Use PostgreSQL", type: :decision)

htm.add_node(
  "code_db_connect",
  "Connection code for PostgreSQL",
  type: :code,
  related_to: ["decision_db"]  # Link to the decision
)
```

### 5. Clean Up When Needed

```ruby
# Explicitly forget outdated information
htm.forget("old_api_key", confirm: :confirmed)
```

!!! warning
    The `forget` method requires explicit confirmation to prevent accidental data loss. HTM never deletes memories automatically.

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
memory = htm.retrieve("my_key")

if memory.nil?
  puts "Memory not found. Check the key spelling."
else
  puts "Found: #{memory['value']}"
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
htm.add_node(
  "user_001",
  "User's name is Alice and she's a software engineer",
  type: :fact,
  importance: 8.0,
  tags: ["user", "identity", "profession"]
)

htm.add_node(
  "decision_001",
  "Decided to use HTM for managing conversation memory",
  type: :decision,
  importance: 9.0,
  tags: ["architecture", "memory"]
)

htm.add_node(
  "pref_001",
  "Alice prefers detailed explanations with examples",
  type: :preference,
  importance: 7.0,
  tags: ["user", "communication"],
  related_to: ["user_001"]
)

# Recall relevant memories
memories = htm.recall(
  timeframe: "last 7 days",
  topic: "user preferences",
  limit: 5
)

puts "Found #{memories.length} relevant memories:"
memories.each do |m|
  puts "- #{m['value']} (importance: #{m['importance']})"
end

# Create context for LLM
context = htm.create_context(strategy: :balanced)
puts "\nContext length: #{context.length} characters"

# Check stats
stats = htm.memory_stats
puts "\nMemory statistics:"
puts "- Total nodes: #{stats[:total_nodes]}"
puts "- Working memory: #{stats[:working_memory][:utilization]}% full"
puts "- Database size: #{(stats[:database_size] / 1024.0 / 1024.0).round(2)} MB"
```

Happy coding with HTM!
