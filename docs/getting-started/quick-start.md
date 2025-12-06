# Quick Start Guide

Get started with HTM in just 5 minutes! This guide will walk you through building your first HTM-powered application.

!!! info "Prerequisites"
    Make sure you've completed the [Installation Guide](installation.md) before starting this tutorial.

<svg viewBox="0 0 900 600" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <!-- Title -->
  <text x="450" y="30" text-anchor="middle" fill="#E0E0E0" font-size="18" font-weight="bold">HTM Quick Start Workflow</text>

  <!-- Step 1: Initialize -->
  <rect x="50" y="70" width="180" height="100" fill="rgba(76, 175, 80, 0.2)" stroke="#4CAF50" stroke-width="3" rx="5"/>
  <text x="140" y="95" text-anchor="middle" fill="#4CAF50" font-size="16" font-weight="bold">Step 1</text>
  <text x="140" y="115" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Initialize HTM</text>
  <text x="140" y="140" text-anchor="middle" fill="#B0B0B0" font-size="11">HTM.new()</text>
  <text x="140" y="160" text-anchor="middle" fill="#B0B0B0" font-size="10">Set robot name</text>

  <!-- Arrow 1 to 2 -->
  <line x1="230" y1="120" x2="270" y2="120" stroke="#4CAF50" stroke-width="3" marker-end="url(#arrow-green)"/>

  <!-- Step 2: Add Memories -->
  <rect x="270" y="70" width="180" height="100" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="3" rx="5"/>
  <text x="360" y="95" text-anchor="middle" fill="#2196F3" font-size="16" font-weight="bold">Step 2</text>
  <text x="360" y="115" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Add Memories</text>
  <text x="360" y="140" text-anchor="middle" fill="#B0B0B0" font-size="11">remember()</text>
  <text x="360" y="160" text-anchor="middle" fill="#B0B0B0" font-size="10">Store knowledge</text>

  <!-- Arrow 2 to 3 -->
  <line x1="450" y1="120" x2="490" y2="120" stroke="#2196F3" stroke-width="3" marker-end="url(#arrow-blue)"/>

  <!-- Step 3: Recall -->
  <rect x="490" y="70" width="180" height="100" fill="rgba(156, 39, 176, 0.2)" stroke="#9C27B0" stroke-width="3" rx="5"/>
  <text x="580" y="95" text-anchor="middle" fill="#9C27B0" font-size="16" font-weight="bold">Step 3</text>
  <text x="580" y="115" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Recall Memories</text>
  <text x="580" y="140" text-anchor="middle" fill="#B0B0B0" font-size="11">recall()</text>
  <text x="580" y="160" text-anchor="middle" fill="#B0B0B0" font-size="10">Search & retrieve</text>

  <!-- Arrow 3 to 4 -->
  <line x1="670" y1="120" x2="710" y2="120" stroke="#9C27B0" stroke-width="3" marker-end="url(#arrow-purple)"/>

  <!-- Step 4: Use Context -->
  <rect x="710" y="70" width="180" height="100" fill="rgba(255, 152, 0, 0.2)" stroke="#FF9800" stroke-width="3" rx="5"/>
  <text x="800" y="95" text-anchor="middle" fill="#FF9800" font-size="16" font-weight="bold">Step 4</text>
  <text x="800" y="115" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Use Context</text>
  <text x="800" y="140" text-anchor="middle" fill="#B0B0B0" font-size="11">assemble_context()</text>
  <text x="800" y="160" text-anchor="middle" fill="#B0B0B0" font-size="10">For LLM prompts</text>

  <!-- Memory Layers Visualization -->
  <text x="450" y="220" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">HTM Memory System</text>

  <!-- Working Memory -->
  <rect x="100" y="250" width="300" height="120" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="2" rx="5"/>
  <text x="250" y="275" text-anchor="middle" fill="#E0E0E0" font-size="13" font-weight="bold">Working Memory (Fast)</text>
  <text x="120" y="300" fill="#B0B0B0" font-size="11">• Token-limited (128K)</text>
  <text x="120" y="320" fill="#B0B0B0" font-size="11">• In-memory storage</text>
  <text x="120" y="340" fill="#B0B0B0" font-size="11">• Immediate LLM access</text>
  <text x="120" y="360" fill="#4CAF50" font-size="10" font-weight="bold">O(1) lookups</text>

  <!-- Long-Term Memory -->
  <rect x="500" y="250" width="300" height="120" fill="rgba(156, 39, 176, 0.2)" stroke="#9C27B0" stroke-width="2" rx="5"/>
  <text x="650" y="275" text-anchor="middle" fill="#E0E0E0" font-size="13" font-weight="bold">Long-Term Memory (Durable)</text>
  <text x="520" y="300" fill="#B0B0B0" font-size="11">• Unlimited storage</text>
  <text x="520" y="320" fill="#B0B0B0" font-size="11">• PostgreSQL</text>
  <text x="520" y="340" fill="#B0B0B0" font-size="11">• RAG search (vector + text)</text>
  <text x="520" y="360" fill="#4CAF50" font-size="10" font-weight="bold">Permanent storage</text>

  <!-- Data Flow -->
  <path d="M 250 390 L 250 420 L 450 420 L 450 390" stroke="#4CAF50" stroke-width="2" fill="none"/>
  <text x="350" y="410" text-anchor="middle" fill="#4CAF50" font-size="10">Stored in both</text>

  <path d="M 400 440 L 650 440" stroke="#FF9800" stroke-width="2" marker-end="url(#arrow-orange)"/>
  <text x="525" y="430" text-anchor="middle" fill="#FF9800" font-size="10">Evicted when full</text>

  <path d="M 650 460 L 250 460" stroke="#9C27B0" stroke-width="2" marker-end="url(#arrow-purple2)"/>
  <text x="450" y="450" text-anchor="middle" fill="#9C27B0" font-size="10">Recalled when needed</text>

  <!-- Code Example -->
  <rect x="50" y="490" width="800" height="90" fill="rgba(76, 175, 80, 0.1)" stroke="#4CAF50" stroke-width="2" rx="5"/>
  <text x="450" y="515" text-anchor="middle" fill="#4CAF50" font-size="13" font-weight="bold">Quick Example Code:</text>
  <text x="70" y="540" fill="#B0B0B0" font-family="monospace" font-size="10">htm = HTM.new(robot_name: "My Assistant")</text>
  <text x="70" y="555" fill="#B0B0B0" font-family="monospace" font-size="10">htm.remember("Remember this fact", tags: ["fact"])</text>
  <text x="70" y="570" fill="#B0B0B0" font-family="monospace" font-size="10">memories = htm.recall("fact", timeframe: "today")</text>

  <!-- Arrow markers -->
  <defs>
    <marker id="arrow-green" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#4CAF50"/>
    </marker>
    <marker id="arrow-blue" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#2196F3"/>
    </marker>
    <marker id="arrow-purple" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#9C27B0"/>
    </marker>
    <marker id="arrow-purple2" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#9C27B0"/>
    </marker>
    <marker id="arrow-orange" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#FF9800"/>
    </marker>
  </defs>
</svg>

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
# Configure HTM globally (optional - uses Ollama by default)
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text:latest'
  config.tag_provider = :ollama
  config.tag_model = 'gemma3:latest'
end

# Initialize HTM with a robot name
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000    # 128k tokens
)

puts "✓ HTM initialized for '#{htm.robot_name}'"
puts "  Robot ID: #{htm.robot_id}"
puts "  Working Memory: #{htm.working_memory.max_tokens} tokens"
```

**What's happening here?**

- `robot_name`: A human-readable name for your AI robot
- `working_memory_size`: Maximum tokens for active context (128k is typical)
- Configuration is set globally via `HTM.configure` block

!!! tip "Robot Identity"
    Each HTM instance represents one robot. The `robot_id` is an integer database ID used to track which robot created each memory.

### Step 3: Add Your First Memory

Add a project decision to HTM's memory:

```ruby
puts "\n1. Adding a project decision..."

node_id = htm.remember(
  "We decided to use PostgreSQL for the database " \
  "because it provides excellent time-series optimization and " \
  "native vector search with pgvector.",
  tags: ["database:postgresql", "architecture:decisions"],
  metadata: { category: "architecture", priority: "high" }
)

puts "✓ Decision added to memory (node #{node_id})"
```

**Memory Components:**

- **Content**: The actual memory text (first argument)
- **Tags**: Hierarchical tags for categorization (e.g., `"database:postgresql"`)
- **Metadata**: Arbitrary key-value data stored as JSONB

!!! note "Automatic Embeddings"
    HTM automatically generates vector embeddings for the memory content in the background. You don't need to handle embeddings yourself!

### Step 4: Add More Memories

Let's add a few more memories:

```ruby
puts "\n2. Adding user preferences..."

htm.remember(
  "User prefers using the debug_me gem for debugging instead of puts statements.",
  tags: ["debugging:ruby", "preferences:coding-style"],
  metadata: { category: "preference" }
)

puts "✓ Preference added"

puts "\n3. Adding a code pattern..."

htm.remember(
  "For database queries, use connection pooling with the connection_pool gem " \
  "to handle concurrent requests efficiently.",
  tags: ["database:performance", "ruby:patterns"],
  metadata: { category: "code-pattern" }
)

puts "✓ Code pattern added"
```

**Tags create relationships** - use hierarchical tags to build a navigable knowledge graph. Tags like `database:postgresql` and `database:performance` are connected through their shared `database` prefix.

### Step 5: Look Up a Specific Memory

Look up a memory by its node ID:

```ruby
puts "\n4. Looking up specific memory..."

# Use the node_id returned from remember()
node = HTM::Models::Node.find_by(id: node_id)

if node
  puts "✓ Found memory:"
  puts "  ID: #{node.id}"
  puts "  Content: #{node.content[0..100]}..."
  puts "  Tags: #{node.tags.pluck(:name).join(', ')}"
  puts "  Created: #{node.created_at}"
else
  puts "✗ Memory not found"
end
```

### Step 6: Recall Memories by Topic

Use HTM's powerful recall feature to find relevant memories:

```ruby
puts "\n5. Recalling memories about 'database'..."

memories = htm.recall(
  "database",                      # Topic (first positional argument)
  timeframe: "last week",          # Natural language time filter
  limit: 10,                       # Max results
  strategy: :hybrid,               # Search strategy (vector + full-text)
  raw: true                        # Return full node data
)

puts "✓ Found #{memories.length} relevant memories:"
memories.each_with_index do |mem, idx|
  puts "  #{idx + 1}. #{mem['content'][0..60]}..."
end
```

**Search Strategies:**

- **`:vector`**: Semantic similarity search using embeddings
- **`:fulltext`**: Keyword-based PostgreSQL full-text search (default)
- **`:hybrid`**: Combines both for best results (recommended)

**Timeframe Options:**

- `"last week"` - Last 7 days
- `"yesterday"` - Previous day
- `"last 30 days"` - Last month
- `"this month"` - Current calendar month
- Date ranges: `7.days.ago..Time.now`

### Step 7: Create Context for Your LLM

Generate a context string optimized for LLM consumption:

```ruby
puts "\n6. Creating context for LLM..."

context = htm.working_memory.assemble_context(
  strategy: :balanced,             # Balance frequency and recency
  max_tokens: 50_000               # Optional token limit
)

puts "✓ Context created: #{context.length} characters"
puts "\nContext preview:"
puts context[0..300]
puts "..."
```

**Context Strategies:**

- **`:recent`**: Most recently accessed memories first (LRU)
- **`:frequent`**: Most frequently accessed memories first (LFU)
- **`:balanced`**: Combines frequency × recency (recommended)

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

# Working memory stats
wm = htm.working_memory
puts "  Working memory:"
puts "    Nodes: #{wm.node_count}"
puts "    Tokens: #{wm.token_count} / #{wm.max_tokens}"
puts "    Utilization: #{wm.utilization_percentage}%"

# Long-term memory stats via models
puts "  Long-term memory:"
puts "    Total nodes: #{HTM::Models::Node.count}"
puts "    Total tags: #{HTM::Models::Tag.count}"
puts "    Active robots: #{HTM::Models::Robot.count}"
```

### Complete Example

Here's the complete script:

```ruby
#!/usr/bin/env ruby
# my_first_htm_app.rb
require 'htm'

puts "My First HTM Application"
puts "=" * 60

# Step 1: Configure and initialize HTM
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text:latest'
  config.tag_provider = :ollama
  config.tag_model = 'gemma3:latest'
end

htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000
)

puts "✓ HTM initialized for '#{htm.robot_name}'"

# Step 2: Add memories
htm.remember(
  "We decided to use PostgreSQL for the database.",
  tags: ["database:postgresql", "architecture:decisions"],
  metadata: { priority: "high" }
)

htm.remember(
  "User prefers using the debug_me gem for debugging.",
  tags: ["debugging:ruby", "preferences"],
  metadata: { category: "preference" }
)

puts "✓ Memories added"

# Step 3: Recall memories
memories = htm.recall(
  "database",
  timeframe: "last week",
  strategy: :hybrid
)

puts "✓ Found #{memories.length} memories about 'database'"

# Step 4: Create context
context = htm.working_memory.assemble_context(strategy: :balanced)
puts "✓ Context created: #{context.length} characters"

# Step 5: View statistics
puts "✓ Total nodes: #{HTM::Models::Node.count}"

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
robot_a.remember(
  "The API documentation is stored in the docs/ directory.",
  tags: ["docs:api", "project:structure"]
)

puts "Robot A added memory"

# Robot B can access the same memory!
memories = robot_b.recall(
  "documentation",
  timeframe: "last week",
  strategy: :hybrid
)

puts "Robot B found #{memories.length} memories"
# Robot B sees Robot A's memory!

# Query which robots have accessed which nodes
HTM::Models::RobotNode.includes(:robot, :node)
  .where(nodes: { content: 'documentation' })
  .group(:robot_id)
  .count
  .each do |robot_id, count|
    robot = HTM::Models::Robot.find(robot_id)
    puts "  #{robot.name}: #{count} memories"
  end
```

**Use cases for multi-robot:**

- Collaborative coding teams of AI agents
- Customer service handoffs between agents
- Research assistants building shared knowledge
- Teaching AI learning from multiple instructors

## Working with Relationships

Build a knowledge graph using hierarchical tags:

```ruby
# Add parent concept
htm.remember(
  "Databases store and organize data persistently.",
  tags: ["knowledge:databases"]
)

# Add child concept with shared tag hierarchy
htm.remember(
  "PostgreSQL is a powerful open-source relational database.",
  tags: ["knowledge:databases:postgresql", "tech:database"]
)

# Add another related concept
htm.remember(
  "PostgreSQL provides robust relational database capabilities.",
  tags: ["knowledge:databases:postgresql:features", "tech:database"]
)

# View tag hierarchy
puts HTM::Models::Tag.tree_string
# knowledge
#   └── databases
#       └── postgresql
#           └── features

# Find all memories under a tag prefix
nodes = HTM::Models::Tag.find_by(name: 'knowledge:databases')&.nodes
```

## Forget (Explicit Deletion)

HTM follows a "never forget" philosophy with soft delete by default:

```ruby
# Soft delete (recoverable) - default behavior
node_id = htm.remember("Temporary note")
htm.forget(node_id)                    # Soft delete
htm.restore(node_id)                   # Restore it!

# Permanent delete requires confirmation
htm.forget(node_id, soft: false, confirm: :confirmed)

puts "✓ Memory permanently deleted"
```

!!! info "Soft Delete by Default"
    The `forget()` method performs a soft delete by default (sets `deleted_at` timestamp). The memory can be restored with `restore()`. Permanent deletion requires `soft: false, confirm: :confirmed`. Working memory evictions move data to long-term storage, they don't delete it.

## Next Steps

Congratulations! You've learned the basics of HTM. Here's what to explore next:

### Explore Advanced Features

- **[User Guide](../guides/getting-started.md)**: Deep dive into all HTM features
- **[API Reference](../api/htm.md)**: Complete API documentation
- **[Architecture Guide](../architecture/overview.md)**: Understand HTM's internals

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

# Try different embedding models via configure
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'llama3:latest'  # Use Llama3
end

# Try different recall strategies
memories = htm.recall(
  "important decisions",
  timeframe: "last month",
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
htm.remember(
  "User: How do I optimize database queries?",
  tags: ["conversation:question"],
  metadata: { role: "user", timestamp: Time.now.to_i }
)

# Store assistant responses
htm.remember(
  "Assistant: Use indexes and connection pooling.",
  tags: ["conversation:answer"],
  metadata: { role: "assistant", timestamp: Time.now.to_i }
)
```

### Pattern 2: Learning from Code

```ruby
# Extract patterns from code reviews
htm.remember(
  "Always validate user input before database queries.",
  tags: ["security:validation", "patterns:best-practice"],
  metadata: { source: "code-review" }
)
```

### Pattern 3: Decision Tracking

```ruby
# Document architectural decisions
htm.remember(
  "Decision: Use microservices architecture. " \
  "Reasoning: Better scalability and independent deployment.",
  tags: ["adr", "architecture:microservices"],
  metadata: { category: "architecture", priority: "critical" }
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
ollama list | grep nomic-embed-text
# Should show nomic-embed-text model
```

### Issue: Memory not found during recall

**Solution**: Check your timeframe. If you just added a memory, use a recent timeframe:

```ruby
# Instead of "last week", use:
memories = htm.recall(
  "your topic",
  timeframe: (Time.now - 3600)..Time.now  # Last hour
)
```

## Additional Resources

- **[Installation Guide](installation.md)**: Complete setup instructions
- **[User Guide](../guides/getting-started.md)**: Comprehensive feature documentation
- **[API Reference](../api/htm.md)**: Detailed API documentation
- **[Examples](https://github.com/madbomber/htm/tree/main/examples)**: Real-world code examples

Happy coding with HTM! 🚀
