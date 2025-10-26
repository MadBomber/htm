# Quick Start Guide

Get started with HTM in just 5 minutes! This guide will walk you through building your first HTM-powered application.

!!! info "Prerequisites"
    Make sure you've completed the [Installation Guide](installation.md) before starting this tutorial.

## Your First HTM Application

Let's build a simple coding assistant that remembers project decisions and preferences.

### Step 1: Create Your Project

Create a new Ruby file:

```ruby
# my_first_htm_app.rb
require 'htm'

puts "My First HTM Application"
puts "=" * 60
```

### Step 2: Initialize HTM

Create an HTM instance for your robot:

```ruby
# Initialize HTM with a robot name
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000,    # 128k tokens
  embedding_service: :ollama,       # Use Ollama for embeddings
  embedding_model: 'gpt-oss'        # Default embedding model
)

puts "✓ HTM initialized for '#{htm.robot_name}'"
puts "  Robot ID: #{htm.robot_id}"
puts "  Working Memory: #{htm.working_memory.max_tokens} tokens"
```

**What's happening here?**

- `robot_name`: A human-readable name for your AI robot
- `working_memory_size`: Maximum tokens for active context (128k is typical)
- `embedding_service`: Service to generate vector embeddings (`:ollama` is default)
- `embedding_model`: Which model to use for embeddings (`gpt-oss` is default)

!!! tip "Robot Identity"
    Each HTM instance represents one robot. The `robot_id` is automatically generated (UUID) and used to track which robot created each memory.

### Step 3: Add Your First Memory

Add a project decision to HTM's memory:

```ruby
puts "\n1. Adding a project decision..."

htm.add_node(
  "decision_001",                    # Unique key
  "We decided to use PostgreSQL with TimescaleDB for the database " \
  "because it provides excellent time-series optimization and " \
  "native vector search with pgvector.",
  type: :decision,                   # Memory type
  category: "architecture",          # Optional category
  importance: 9.0,                   # Importance score (0-10)
  tags: ["database", "architecture"] # Searchable tags
)

puts "✓ Decision added to memory"
```

**Memory Components:**

- **Key**: Unique identifier (e.g., `"decision_001"`)
- **Value**: The actual content/memory text
- **Type**: Category of memory (`:decision`, `:fact`, `:code`, `:preference`, etc.)
- **Category**: Optional grouping
- **Importance**: Score from 0.0 to 10.0 (affects recall priority)
- **Tags**: Searchable keywords for organization

!!! note "Automatic Embeddings"
    HTM automatically generates vector embeddings for the memory content using Ollama. You don't need to handle embeddings yourself!

### Step 4: Add More Memories

Let's add a few more memories:

```ruby
puts "\n2. Adding user preferences..."

htm.add_node(
  "pref_001",
  "User prefers using the debug_me gem for debugging instead of puts statements.",
  type: :preference,
  category: "coding_style",
  importance: 7.0,
  tags: ["debugging", "ruby", "preferences"]
)

puts "✓ Preference added"

puts "\n3. Adding a code pattern..."

htm.add_node(
  "code_001",
  "For database queries, use connection pooling with the connection_pool gem " \
  "to handle concurrent requests efficiently.",
  type: :code,
  category: "patterns",
  importance: 8.0,
  tags: ["database", "performance", "ruby"],
  related_to: ["decision_001"]  # Link to related memory
)

puts "✓ Code pattern added (linked to decision_001)"
```

**Notice the `related_to` parameter?** This creates a relationship in the knowledge graph, linking related memories together.

### Step 5: Retrieve a Specific Memory

Retrieve a memory by its key:

```ruby
puts "\n4. Retrieving specific memory..."

memory = htm.retrieve("decision_001")

if memory
  puts "✓ Found memory:"
  puts "  Key: #{memory['key']}"
  puts "  Type: #{memory['type']}"
  puts "  Content: #{memory['value'][0..100]}..."
  puts "  Importance: #{memory['importance']}"
  puts "  Created: #{memory['created_at']}"
else
  puts "✗ Memory not found"
end
```

### Step 6: Recall Memories by Topic

Use HTM's powerful recall feature to find relevant memories:

```ruby
puts "\n5. Recalling memories about 'database'..."

memories = htm.recall(
  timeframe: "last week",          # Natural language time filter
  topic: "database",               # What to search for
  limit: 10,                       # Max results
  strategy: :hybrid                # Search strategy (vector + full-text)
)

puts "✓ Found #{memories.length} relevant memories:"
memories.each_with_index do |mem, idx|
  puts "  #{idx + 1}. [#{mem['type']}] #{mem['value'][0..60]}..."
end
```

**Search Strategies:**

- **`:vector`**: Semantic similarity search using embeddings
- **`:fulltext`**: Keyword-based PostgreSQL full-text search
- **`:hybrid`**: Combines both for best results (recommended)

**Timeframe Options:**

- `"last week"` - Last 7 days
- `"yesterday"` - Previous day
- `"last 30 days"` - Last month
- `"this month"` - Current calendar month
- Date ranges: `(Time.now - 7.days)..Time.now`

### Step 7: Create Context for Your LLM

Generate a context string optimized for LLM consumption:

```ruby
puts "\n6. Creating context for LLM..."

context = htm.create_context(
  strategy: :balanced,             # Balance importance and recency
  max_tokens: 50_000               # Optional token limit
)

puts "✓ Context created: #{context.length} characters"
puts "\nContext preview:"
puts context[0..300]
puts "..."
```

**Context Strategies:**

- **`:recent`**: Most recent memories first
- **`:important`**: Highest importance scores first
- **`:balanced`**: Combines importance × recency (recommended)

This context can be directly injected into your LLM prompt:

```ruby
# Example: Using context with your LLM
prompt = <<~PROMPT
  You are a helpful coding assistant.

  Here's what you remember from past conversations:
  #{context}

  User: What database did we decide to use for the project?
PROMPT

# response = your_llm.chat(prompt)
```

### Step 8: Check Memory Statistics

View statistics about your memory usage:

```ruby
puts "\n7. Memory Statistics:"

stats = htm.memory_stats

puts "  Total nodes in long-term memory: #{stats[:total_nodes]}"
puts "  Active robots: #{stats[:active_robots]}"
puts "  Working memory usage: #{stats[:working_memory][:current_tokens]} / " \
     "#{stats[:working_memory][:max_tokens]} tokens " \
     "(#{stats[:working_memory][:utilization].round(2)}%)"
puts "  Database size: #{(stats[:database_size] / (1024.0 ** 2)).round(2)} MB"
```

### Complete Example

Here's the complete script:

```ruby
#!/usr/bin/env ruby
# my_first_htm_app.rb
require 'htm'

puts "My First HTM Application"
puts "=" * 60

# Step 1: Initialize HTM
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000,
  embedding_service: :ollama,
  embedding_model: 'gpt-oss'
)

puts "✓ HTM initialized for '#{htm.robot_name}'"

# Step 2: Add memories
htm.add_node(
  "decision_001",
  "We decided to use PostgreSQL with TimescaleDB for the database.",
  type: :decision,
  category: "architecture",
  importance: 9.0,
  tags: ["database", "architecture"]
)

htm.add_node(
  "pref_001",
  "User prefers using the debug_me gem for debugging.",
  type: :preference,
  importance: 7.0,
  tags: ["debugging", "ruby"]
)

puts "✓ Memories added"

# Step 3: Recall memories
memories = htm.recall(
  timeframe: "last week",
  topic: "database",
  strategy: :hybrid
)

puts "✓ Found #{memories.length} memories about 'database'"

# Step 4: Create context
context = htm.create_context(strategy: :balanced)
puts "✓ Context created: #{context.length} characters"

# Step 5: View statistics
stats = htm.memory_stats
puts "✓ Total nodes: #{stats[:total_nodes]}"

puts "\n" + "=" * 60
puts "Success! Your first HTM application is working."
```

Run it:

```bash
ruby my_first_htm_app.rb
```

## Multi-Robot Example

HTM's "hive mind" feature allows multiple robots to share memory. Here's how:

```ruby
require 'htm'

# Create two different robots
robot_a = HTM.new(robot_name: "Code Assistant")
robot_b = HTM.new(robot_name: "Documentation Writer")

# Robot A adds a memory
robot_a.add_node(
  "shared_001",
  "The API documentation is stored in the docs/ directory.",
  type: :fact,
  importance: 8.0
)

puts "Robot A added memory"

# Robot B can access the same memory!
memories = robot_b.recall(
  timeframe: "last week",
  topic: "documentation",
  strategy: :hybrid
)

puts "Robot B found #{memories.length} memories"
# Robot B sees Robot A's memory!

# Track which robot said what
breakdown = robot_b.which_robot_said("documentation")
puts "Who mentioned 'documentation':"
breakdown.each do |robot_id, count|
  puts "  #{robot_id}: #{count} times"
end
```

**Use cases for multi-robot:**

- Collaborative coding teams of AI agents
- Customer service handoffs between agents
- Research assistants building shared knowledge
- Teaching AI learning from multiple instructors

## Working with Relationships

Build a knowledge graph by linking related memories:

```ruby
# Add parent concept
htm.add_node(
  "concept_databases",
  "Databases store and organize data persistently.",
  type: :fact,
  importance: 5.0
)

# Add child concept with relationship
htm.add_node(
  "concept_postgresql",
  "PostgreSQL is a powerful open-source relational database.",
  type: :fact,
  importance: 7.0,
  related_to: ["concept_databases"]  # Links to parent
)

# Add another related concept
htm.add_node(
  "concept_timescaledb",
  "TimescaleDB extends PostgreSQL with time-series optimization.",
  type: :fact,
  importance: 8.0,
  related_to: ["concept_postgresql", "concept_databases"]
)

# Now you have a knowledge graph:
# concept_databases
#   ├── concept_postgresql
#   │    └── concept_timescaledb
```

## Forget (Explicit Deletion)

HTM follows a "never forget" philosophy, but you can explicitly delete memories:

```ruby
# Deletion requires confirmation
htm.forget("old_decision", confirm: :confirmed)

puts "✓ Memory deleted"
```

!!! warning "Deletion is Permanent"
    The `forget()` method permanently deletes data. This is the **only** way to delete memories in HTM. Working memory evictions move data to long-term storage, they don't delete it.

## Next Steps

Congratulations! You've learned the basics of HTM. Here's what to explore next:

### Explore Advanced Features

- **[User Guide](guides/getting-started.md)**: Deep dive into all HTM features
- **[API Reference](api/htm.md)**: Complete API documentation
- **[Architecture Guide](architecture/overview.md)**: Understand HTM's internals

### Build Real Applications

Try building:

1. **Personal AI Assistant**: Remember user preferences and habits
2. **Code Review Bot**: Track coding patterns and past decisions
3. **Research Assistant**: Build a knowledge graph from documents
4. **Customer Service Bot**: Maintain conversation history

### Experiment with Different Configurations

```ruby
# Try different memory sizes
htm = HTM.new(
  robot_name: "Large Memory Bot",
  working_memory_size: 256_000  # 256k tokens
)

# Try different embedding models
htm = HTM.new(
  robot_name: "Custom Embeddings",
  embedding_service: :ollama,
  embedding_model: 'llama2'  # Use Llama2 instead of gpt-oss
)

# Try different recall strategies
memories = htm.recall(
  timeframe: "last month",
  topic: "important decisions",
  strategy: :vector  # Pure semantic search
)
```

### Performance Optimization

For production applications:

- Use connection pooling (built-in)
- Tune working memory size based on your LLM's context window
- Adjust importance scores to prioritize critical memories
- Use appropriate timeframes to limit search scope
- Monitor memory statistics regularly

### Join the Community

- **GitHub**: [https://github.com/madbomber/htm](https://github.com/madbomber/htm)
- **Issues**: Report bugs or request features
- **Discussions**: Share your HTM projects

## Common Patterns

### Pattern 1: Conversation Memory

```ruby
# Store user messages
htm.add_node(
  "msg_#{Time.now.to_i}",
  "User: How do I optimize database queries?",
  type: :context,
  importance: 6.0,
  tags: ["conversation", "question"]
)

# Store assistant responses
htm.add_node(
  "response_#{Time.now.to_i}",
  "Assistant: Use indexes and connection pooling.",
  type: :context,
  importance: 6.0,
  tags: ["conversation", "answer"]
)
```

### Pattern 2: Learning from Code

```ruby
# Extract patterns from code reviews
htm.add_node(
  "pattern_#{SecureRandom.hex(4)}",
  "Always validate user input before database queries.",
  type: :code,
  importance: 9.0,
  tags: ["security", "validation", "best-practice"]
)
```

### Pattern 3: Decision Tracking

```ruby
# Document architectural decisions
htm.add_node(
  "adr_001",
  "Decision: Use microservices architecture. " \
  "Reasoning: Better scalability and independent deployment.",
  type: :decision,
  category: "architecture",
  importance: 10.0,
  tags: ["adr", "architecture", "microservices"]
)
```

## Troubleshooting Quick Start

### Issue: "Connection refused" error

**Solution**: Make sure Ollama is running:

```bash
curl http://localhost:11434/api/version
# If this fails, start Ollama
```

### Issue: "Database connection failed"

**Solution**: Verify your `HTM_DBURL` is set:

```bash
echo $HTM_DBURL
# Should show your connection string
```

### Issue: Embeddings taking too long

**Solution**: Check Ollama's status and ensure the model is downloaded:

```bash
ollama list | grep gpt-oss
# Should show gpt-oss model
```

### Issue: Memory not found during recall

**Solution**: Check your timeframe. If you just added a memory, use a recent timeframe:

```ruby
# Instead of "last week", use:
memories = htm.recall(
  timeframe: (Time.now - 3600)..Time.now,  # Last hour
  topic: "your topic"
)
```

## Additional Resources

- **[Installation Guide](installation.md)**: Complete setup instructions
- **[User Guide](guides/getting-started.md)**: Comprehensive feature documentation
- **[API Reference](api/htm.md)**: Detailed API documentation
- **[Examples](https://github.com/madbomber/htm/tree/main/examples)**: Real-world code examples

Happy coding with HTM! 🚀
