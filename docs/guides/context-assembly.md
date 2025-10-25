# Context Assembly

Context assembly is the process of converting working memory into a formatted string that can be used with your LLM. This guide covers the three assembly strategies, optimization techniques, and best practices for creating high-quality context.

## What is Context Assembly?

Context assembly transforms working memory into LLM-ready context:

```
Working Memory (Nodes)              Context String
┌──────────────────┐               ┌─────────────────────┐
│ Node 1 (1000 tok)│               │ Node 3 (important)  │
│ Node 2 (500 tok) │  Assembly →   │ Node 1 (recent)     │
│ Node 3 (2000 tok)│   Strategy    │ Node 2 (balanced)   │
│ Node 4 (800 tok) │               │                     │
└──────────────────┘               └─────────────────────┘
                                         ↓
                                    LLM Prompt
```

## Basic Usage

The `create_context` method assembles context from working memory:

```ruby
# Basic context assembly
context = htm.create_context(
  strategy: :balanced,    # Assembly strategy
  max_tokens: nil        # Optional token limit
)

# Use with your LLM
prompt = <<~PROMPT
  Context from memory:
  #{context}

  User question: How do we handle authentication?

  Assistant:
PROMPT

# Send to LLM...
response = llm.complete(prompt)
```

## Assembly Strategies

HTM provides three strategies for assembling context, each optimized for different use cases.

### Recent Strategy

The `:recent` strategy prioritizes newest memories first.

```ruby
context = htm.create_context(strategy: :recent)
```

**How it works:**

1. Sort memories by access time (most recent first)
2. Add memories in order until token limit reached
3. Return assembled context

**Best for:**

- Continuing recent conversations
- Session-based interactions
- Short-term context tracking
- Real-time applications

**Example:**

```ruby
# Chat application
class ChatBot
  def initialize
    @htm = HTM.new(robot_name: "Chat", working_memory_size: 128_000)
    @turn = 0
  end

  def chat(user_message)
    @turn += 1

    # Add user message
    @htm.add_node(
      "turn_#{@turn}_user",
      "User: #{user_message}",
      type: :context,
      importance: 6.0
    )

    # Get recent context
    context = @htm.create_context(
      strategy: :recent,
      max_tokens: 10_000
    )

    # Generate response
    response = llm_generate(context, user_message)

    # Store assistant response
    @htm.add_node(
      "turn_#{@turn}_assistant",
      "Assistant: #{response}",
      type: :context,
      importance: 6.0
    )

    response
  end

  private

  def llm_generate(context, message)
    # Your LLM integration here
    "Generated response based on context"
  end
end
```

### Important Strategy

The `:important` strategy prioritizes high-importance memories.

```ruby
context = htm.create_context(strategy: :important)
```

**How it works:**

1. Sort memories by importance (highest first)
2. Add memories in order until token limit reached
3. Return assembled context

**Best for:**

- Critical information retention
- System constraints and rules
- User preferences
- Core knowledge base
- Decision-making support

**Example:**

```ruby
# Knowledge base with priorities
class KnowledgeBot
  def initialize
    @htm = HTM.new(robot_name: "Knowledge")

    # Add critical system constraints
    @htm.add_node(
      "constraint_001",
      "CRITICAL: Never expose API keys in responses",
      type: :fact,
      importance: 10.0
    )

    # Add important user preferences
    @htm.add_node(
      "pref_001",
      "User prefers concise explanations",
      type: :preference,
      importance: 8.0
    )

    # Add general knowledge
    @htm.add_node(
      "fact_001",
      "Python uses indentation for code blocks",
      type: :fact,
      importance: 5.0
    )
  end

  def answer_question(question)
    # Get most important context first
    context = @htm.create_context(
      strategy: :important,
      max_tokens: 5_000
    )

    # Critical constraints and preferences are included first
    generate_answer(context, question)
  end

  private

  def generate_answer(context, question)
    # LLM integration
    "Answer based on important context"
  end
end
```

### Balanced Strategy (Recommended)

The `:balanced` strategy combines importance and recency using a weighted formula.

```ruby
context = htm.create_context(strategy: :balanced)
```

**How it works:**

1. Calculate score: `importance × (1 / (1 + age_in_hours))`
2. Sort by score (highest first)
3. Add memories until token limit reached
4. Return assembled context

**Scoring examples:**

```ruby
# Recent + Important: High score
# Importance: 9.0, Age: 1 hour
# Score: 9.0 × (1 / (1 + 1)) = 4.5 ✓ Included

# Old + Important: Medium score
# Importance: 9.0, Age: 24 hours
# Score: 9.0 × (1 / (1 + 24)) = 0.36 ≈ Maybe

# Recent + Unimportant: Low score
# Importance: 2.0, Age: 1 hour
# Score: 2.0 × (1 / (1 + 1)) = 1.0 ≈ Maybe

# Old + Unimportant: Very low score
# Importance: 2.0, Age: 24 hours
# Score: 2.0 × (1 / (1 + 24)) = 0.08 ✗ Excluded
```

**Best for:**

- General-purpose applications (recommended default)
- Mixed temporal needs
- Production systems
- Balanced context requirements

**Example:**

```ruby
# General-purpose assistant
class Assistant
  def initialize
    @htm = HTM.new(
      robot_name: "Assistant",
      working_memory_size: 128_000
    )
  end

  def process(user_input)
    # Add user input
    @htm.add_node(
      "input_#{Time.now.to_i}",
      user_input,
      type: :context,
      importance: 7.0
    )

    # Get balanced context (recent + important)
    context = @htm.create_context(
      strategy: :balanced,
      max_tokens: 50_000
    )

    # Use context with LLM
    generate_response(context, user_input)
  end

  private

  def generate_response(context, input)
    prompt = <<~PROMPT
      You are a helpful assistant with access to memory.

      Context from memory:
      #{context}

      User: #{input}

      Assistant:
    PROMPT

    # Send to LLM
    llm_complete(prompt)
  end

  def llm_complete(prompt)
    # Your LLM integration
    "Generated response"
  end
end
```

## Token Limits

Control context size with token limits:

```ruby
# Use default (working memory size)
context = htm.create_context(strategy: :balanced)

# Custom limit
context = htm.create_context(
  strategy: :balanced,
  max_tokens: 50_000
)

# Small context for simple queries
context = htm.create_context(
  strategy: :recent,
  max_tokens: 5_000
)

# Large context for complex tasks
context = htm.create_context(
  strategy: :important,
  max_tokens: 200_000
)
```

**Choosing token limits:**

| Limit | Use Case |
|-------|----------|
| 2K-5K | Simple Q&A, quick lookups |
| 10K-20K | Standard conversations |
| 50K-100K | Complex analysis, code generation |
| 100K+ | Document processing, extensive context |

!!! warning "LLM Context Windows"
    Don't exceed your LLM's context window:
    - GPT-3.5: 4K-16K tokens
    - GPT-4: 8K-128K tokens
    - Claude: 100K-200K tokens
    - Llama 2: 4K tokens

## Strategy Comparison

### Performance

```ruby
require 'benchmark'

# Add 1000 test memories
1000.times do |i|
  htm.add_node(
    "test_#{i}",
    "Memory #{i}",
    importance: rand(1.0..10.0)
  )
end

# Benchmark strategies
Benchmark.bm(15) do |x|
  x.report("Recent:") do
    100.times { htm.create_context(strategy: :recent) }
  end

  x.report("Important:") do
    100.times { htm.create_context(strategy: :important) }
  end

  x.report("Balanced:") do
    100.times { htm.create_context(strategy: :balanced) }
  end
end

# Typical results:
#                       user     system      total        real
# Recent:           0.050000   0.000000   0.050000 (  0.051234)
# Important:        0.045000   0.000000   0.045000 (  0.047891)
# Balanced:         0.080000   0.000000   0.080000 (  0.082456)
```

**Notes:**

- `:recent` is fastest (simple sort)
- `:important` is fast (simple sort)
- `:balanced` is slower (complex calculation)
- All are typically < 100ms for normal working memory sizes

### Quality Comparison

```ruby
# Test scenario: Mix of old important and recent unimportant data

# Setup
htm = HTM.new(robot_name: "Test")

# Add old important data
htm.add_node("old_critical", "Critical system constraint", importance: 10.0)
sleep 1  # Simulate age

# Add recent unimportant data
20.times do |i|
  htm.add_node("recent_#{i}", "Recent note #{i}", importance: 2.0)
end

# Compare strategies
puts "=== Recent Strategy ==="
context = htm.create_context(strategy: :recent, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

puts "\n=== Important Strategy ==="
context = htm.create_context(strategy: :important, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

puts "\n=== Balanced Strategy ==="
context = htm.create_context(strategy: :balanced, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

# Results:
# Recent: ✗ Missing critical (prioritized recent notes)
# Important: ✓ Has critical (prioritized by importance)
# Balanced: ✓ Has critical (balanced approach)
```

## Advanced Techniques

### 1. Multi-Strategy Context

Use multiple strategies for comprehensive context:

```ruby
def multi_strategy_context(max_tokens_per_strategy: 10_000)
  # Get different perspectives
  recent = htm.create_context(
    strategy: :recent,
    max_tokens: max_tokens_per_strategy
  )

  important = htm.create_context(
    strategy: :important,
    max_tokens: max_tokens_per_strategy
  )

  # Combine (you might want to deduplicate)
  combined = <<~CONTEXT
    === Recent Context ===
    #{recent}

    === Important Context ===
    #{important}
  CONTEXT

  combined
end
```

### 2. Dynamic Strategy Selection

Choose strategy based on query type:

```ruby
def smart_context(query)
  strategy = if query.match?(/recent|latest|current/)
    :recent
  elsif query.match?(/important|critical|must/)
    :important
  else
    :balanced
  end

  htm.create_context(strategy: strategy, max_tokens: 20_000)
end

# Usage
context = smart_context("What are the recent changes?")    # Uses :recent
context = smart_context("What are critical constraints?")  # Uses :important
context = smart_context("How do we handle auth?")         # Uses :balanced
```

### 3. Filtered Context

Include only specific types of memories:

```ruby
def filtered_context(type:, strategy: :balanced)
  # This requires custom implementation
  # HTM doesn't expose working memory internals directly

  # Workaround: Recall specific types
  memories = htm.recall(
    timeframe: "last 24 hours",
    topic: "type:#{type}",  # Pseudo-filter
    strategy: :hybrid,
    limit: 50
  ).select { |m| m['type'] == type.to_s }

  # Manually assemble context
  memories.map { |m| m['value'] }.join("\n\n")
end

# Usage
facts_only = filtered_context(type: :fact)
decisions_only = filtered_context(type: :decision)
```

### 4. Sectioned Context

Organize context into sections:

```ruby
def sectioned_context
  # Get different types of context
  facts = htm.recall(timeframe: "all time", topic: "fact")
    .select { |m| m['type'] == 'fact' }
    .first(5)

  decisions = htm.recall(timeframe: "all time", topic: "decision")
    .select { |m| m['type'] == 'decision' }
    .first(5)

  recent = htm.recall(timeframe: "last hour", topic: "", limit: 5)

  # Format as sections
  <<~CONTEXT
    === Core Facts ===
    #{facts.map { |f| "- #{f['value']}" }.join("\n")}

    === Key Decisions ===
    #{decisions.map { |d| "- #{d['value']}" }.join("\n")}

    === Recent Activity ===
    #{recent.map { |r| "- #{r['value']}" }.join("\n")}
  CONTEXT
end
```

### 5. Token-Aware Context

Ensure context fits LLM limits:

```ruby
class TokenAwareContext
  def initialize(htm, embedding_service)
    @htm = htm
    @embedding_service = embedding_service
  end

  def create(strategy:, llm_context_window:, reserve_for_prompt: 1000)
    # Calculate available tokens
    available = llm_context_window - reserve_for_prompt

    # Get context
    context = @htm.create_context(
      strategy: strategy,
      max_tokens: available
    )

    # Verify token count
    actual_tokens = @embedding_service.count_tokens(context)

    if actual_tokens > available
      warn "Context exceeded limit! Truncating..."
      # Retry with smaller limit
      context = @htm.create_context(
        strategy: strategy,
        max_tokens: available * 0.9  # 90% to be safe
      )
    end

    context
  end
end

# Usage
embedding_service = HTM::EmbeddingService.new
context_builder = TokenAwareContext.new(htm, embedding_service)

context = context_builder.create(
  strategy: :balanced,
  llm_context_window: 100_000,  # Claude 100K
  reserve_for_prompt: 2_000
)
```

## Using Context with LLMs

### Pattern 1: System Prompt + Context

```ruby
def generate_with_context(user_query)
  context = htm.create_context(strategy: :balanced, max_tokens: 50_000)

  system_prompt = <<~SYSTEM
    You are a helpful AI assistant with access to memory.
    Use the provided context to answer questions accurately.
  SYSTEM

  user_prompt = <<~USER
    Context from memory:
    #{context}

    ---

    User question: #{user_query}

    Please answer based on the context above.
  USER

  # Send to LLM with system + user prompts
  llm.chat(system: system_prompt, user: user_prompt)
end
```

### Pattern 2: Conversation History

```ruby
class ConversationManager
  def initialize
    @htm = HTM.new(robot_name: "Chat")
    @conversation_id = SecureRandom.uuid
  end

  def add_turn(user_msg, assistant_msg)
    timestamp = Time.now.to_i

    @htm.add_node(
      "#{@conversation_id}_#{timestamp}_user",
      user_msg,
      type: :context,
      importance: 6.0,
      tags: ["conversation", @conversation_id]
    )

    @htm.add_node(
      "#{@conversation_id}_#{timestamp}_assistant",
      assistant_msg,
      type: :context,
      importance: 6.0,
      tags: ["conversation", @conversation_id]
    )
  end

  def get_context_for_llm
    # Get recent conversation
    @htm.create_context(
      strategy: :recent,
      max_tokens: 10_000
    )
  end
end
```

### Pattern 3: RAG with Context

```ruby
def rag_query(question)
  # 1. Retrieve relevant memories
  relevant = htm.recall(
    timeframe: "last month",
    topic: question,
    strategy: :hybrid,
    limit: 10
  )

  # 2. Create context from working memory (includes retrieved + existing)
  context = htm.create_context(
    strategy: :balanced,
    max_tokens: 30_000
  )

  # 3. Generate answer
  prompt = <<~PROMPT
    Context:
    #{context}

    Question: #{question}

    Answer based on the context above:
  PROMPT

  llm.complete(prompt)
end
```

## Optimization Tips

### 1. Cache Context

```ruby
class ContextCache
  def initialize(htm, ttl: 60)
    @htm = htm
    @ttl = ttl
    @cache = {}
  end

  def get_context(strategy:, max_tokens: nil)
    cache_key = "#{strategy}_#{max_tokens}"

    # Check cache
    if cached = @cache[cache_key]
      if Time.now - cached[:time] < @ttl
        return cached[:context]
      end
    end

    # Generate new context
    context = @htm.create_context(
      strategy: strategy,
      max_tokens: max_tokens
    )

    # Cache it
    @cache[cache_key] = {
      context: context,
      time: Time.now
    }

    context
  end

  def invalidate
    @cache.clear
  end
end

# Usage
cache = ContextCache.new(htm, ttl: 30)  # 30 second TTL
context = cache.get_context(strategy: :balanced)  # Cached for 30s
```

### 2. Progressive Context Loading

```ruby
def progressive_context(start_tokens: 5_000, max_tokens: 50_000)
  # Start small
  context = htm.create_context(strategy: :balanced, max_tokens: start_tokens)

  # Check if more context needed (based on your logic)
  if needs_more_context?(context)
    # Expand gradually
    context = htm.create_context(strategy: :balanced, max_tokens: start_tokens * 2)
  end

  if still_needs_more?(context)
    # Expand to max
    context = htm.create_context(strategy: :balanced, max_tokens: max_tokens)
  end

  context
end

def needs_more_context?(context)
  # Your logic here
  context.length < 1000  # Example: too short
end

def still_needs_more?(context)
  # Your logic here
  false  # Example
end
```

### 3. Selective Inclusion

```ruby
def selective_context(query)
  # Determine what's relevant
  include_facts = query.match?(/fact|truth|information/)
  include_decisions = query.match?(/decision|choice|why/)
  include_code = query.match?(/code|implement|example/)

  # Build custom context
  parts = []

  if include_facts
    facts = htm.recall(timeframe: "all time", topic: query)
      .select { |m| m['type'] == 'fact' }
      .first(5)
    parts << "Facts:\n" + facts.map { |f| "- #{f['value']}" }.join("\n")
  end

  if include_decisions
    decisions = htm.recall(timeframe: "all time", topic: query)
      .select { |m| m['type'] == 'decision' }
      .first(5)
    parts << "Decisions:\n" + decisions.map { |d| "- #{d['value']}" }.join("\n")
  end

  if include_code
    code = htm.recall(timeframe: "all time", topic: query)
      .select { |m| m['type'] == 'code' }
      .first(3)
    parts << "Code Examples:\n" + code.map { |c| c['value'] }.join("\n\n")
  end

  parts.join("\n\n")
end
```

## Best Practices

### 1. Choose the Right Strategy

```ruby
# Use :recent for conversations
context = htm.create_context(strategy: :recent)

# Use :important for critical operations
context = htm.create_context(strategy: :important)

# Use :balanced as default (recommended)
context = htm.create_context(strategy: :balanced)
```

### 2. Set Appropriate Token Limits

```ruby
# Don't exceed LLM context window
context = htm.create_context(
  strategy: :balanced,
  max_tokens: 100_000  # Leave room for prompt
)

# Smaller contexts are faster
context = htm.create_context(
  strategy: :recent,
  max_tokens: 5_000  # Quick queries
)
```

### 3. Monitor Context Quality

```ruby
def monitor_context
  context = htm.create_context(strategy: :balanced)

  puts "Context length: #{context.length} characters"

  # Count token estimate
  embedding_service = HTM::EmbeddingService.new
  tokens = embedding_service.count_tokens(context)
  puts "Estimated tokens: #{tokens}"

  # Check if too small or too large
  warn "Context very small!" if tokens < 500
  warn "Context very large!" if tokens > 100_000
end
```

### 4. Include Metadata

```ruby
def context_with_metadata
  context = htm.create_context(strategy: :balanced, max_tokens: 20_000)

  # Add metadata header
  stats = htm.memory_stats

  <<~CONTEXT
    [Context assembled at #{Time.now}]
    [Strategy: balanced]
    [Working memory: #{stats[:working_memory][:node_count]} nodes]
    [Robot: #{htm.robot_name}]

    #{context}
  CONTEXT
end
```

## Complete Example

```ruby
require 'htm'

# Initialize HTM
htm = HTM.new(
  robot_name: "Context Demo",
  working_memory_size: 128_000
)

# Add various memories
htm.add_node("fact_001", "User prefers Ruby", type: :fact, importance: 9.0)
htm.add_node("decision_001", "Use PostgreSQL", type: :decision, importance: 8.0)
htm.add_node("context_001", "Currently debugging auth", type: :context, importance: 7.0)
htm.add_node("code_001", "def auth...", type: :code, importance: 6.0)
htm.add_node("note_001", "Check logs later", type: :context, importance: 2.0)

puts "=== Recent Strategy ==="
recent = htm.create_context(strategy: :recent, max_tokens: 5_000)
puts recent
puts "\n(Newest first)"

puts "\n=== Important Strategy ==="
important = htm.create_context(strategy: :important, max_tokens: 5_000)
puts important
puts "\n(Most important first)"

puts "\n=== Balanced Strategy ==="
balanced = htm.create_context(strategy: :balanced, max_tokens: 5_000)
puts balanced
puts "\n(Recent + important)"

# Use with LLM
def ask_llm(context, question)
  prompt = <<~PROMPT
    Context:
    #{context}

    Question: #{question}
    Answer:
  PROMPT

  # Send to your LLM here
  puts "\n=== LLM Prompt ==="
  puts prompt
end

ask_llm(balanced, "What database are we using?")
```

## Next Steps

- [**Recalling Memories**](recalling-memories.md) - Populate working memory effectively
- [**Working Memory**](working-memory.md) - Understand memory management
- [**Search Strategies**](search-strategies.md) - Optimize retrieval for context
