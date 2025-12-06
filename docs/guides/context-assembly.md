# Context Assembly

Context assembly is the process of converting working memory into a formatted string that can be used with your LLM. This guide covers the three assembly strategies, optimization techniques, and best practices for creating high-quality context.

## What is Context Assembly?

Context assembly transforms working memory into LLM-ready context:

<svg viewBox="0 0 900 550" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <defs>
    <style>
      .box { fill: rgba(33, 150, 243, 0.2); stroke: #2196F3; stroke-width: 2; }
      .strategy-box { fill: rgba(76, 175, 80, 0.2); stroke: #4CAF50; stroke-width: 2; }
      .output-box { fill: rgba(255, 152, 0, 0.2); stroke: #FF9800; stroke-width: 2; }
      .llm-box { fill: rgba(156, 39, 176, 0.2); stroke: #9C27B0; stroke-width: 3; }
      .text-header { fill: #E0E0E0; font-size: 16px; font-weight: bold; }
      .text-label { fill: #E0E0E0; font-size: 13px; }
      .text-small { fill: #B0B0B0; font-size: 11px; }
      .arrow { stroke: #4A9EFF; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
    </style>
    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#4A9EFF" />
    </marker>
  </defs>

  <!-- Title -->
  <text x="450" y="25" text-anchor="middle" class="text-header" fill="#E0E0E0">Context Assembly Process</text>

  <!-- Working Memory Box -->
  <rect x="50" y="60" width="200" height="200" class="box" rx="5"/>
  <text x="150" y="85" text-anchor="middle" class="text-header">Working Memory</text>
  <text x="150" y="105" text-anchor="middle" class="text-small">(Nodes)</text>

  <text x="60" y="135" class="text-label">Node 1</text>
  <text x="180" y="135" text-anchor="end" class="text-small">1000 tok</text>
  <text x="60" y="155" class="text-label">Node 2</text>
  <text x="180" y="155" text-anchor="end" class="text-small">500 tok</text>
  <text x="60" y="175" class="text-label">Node 3</text>
  <text x="180" y="175" text-anchor="end" class="text-small">2000 tok</text>
  <text x="60" y="195" class="text-label">Node 4</text>
  <text x="180" y="195" text-anchor="end" class="text-small">800 tok</text>
  <text x="60" y="215" class="text-label">Node 5</text>
  <text x="180" y="215" text-anchor="end" class="text-small">1200 tok</text>
  <text x="60" y="235" class="text-label">...</text>

  <!-- Assembly Strategies -->
  <rect x="330" y="60" width="240" height="200" class="strategy-box" rx="5"/>
  <text x="450" y="85" text-anchor="middle" class="text-header">Assembly Strategy</text>

  <!-- Strategy 1: Recent -->
  <rect x="340" y="100" width="220" height="35" fill="rgba(76, 175, 80, 0.3)" rx="3"/>
  <text x="350" y="120" class="text-label">:recent</text>
  <text x="550" y="120" text-anchor="end" class="text-small">Sort by access time</text>

  <!-- Strategy 2: Important -->
  <rect x="340" y="145" width="220" height="35" fill="rgba(76, 175, 80, 0.3)" rx="3"/>
  <text x="350" y="165" class="text-label">:important</text>
  <text x="550" y="165" text-anchor="end" class="text-small">Sort by importance</text>

  <!-- Strategy 3: Balanced -->
  <rect x="340" y="190" width="220" height="35" fill="rgba(76, 175, 80, 0.3)" rx="3"/>
  <text x="350" y="210" class="text-label">:balanced</text>
  <text x="550" y="210" text-anchor="end" class="text-small">Weighted formula</text>

  <text x="450" y="250" text-anchor="middle" class="text-small">Assembles until max_tokens reached</text>

  <!-- Context String Box -->
  <rect x="650" y="60" width="200" height="200" class="output-box" rx="5"/>
  <text x="750" y="85" text-anchor="middle" class="text-header">Context String</text>
  <text x="750" y="105" text-anchor="middle" class="text-small">(Ordered)</text>

  <text x="660" y="135" class="text-label">Node 3</text>
  <text x="840" y="135" text-anchor="end" class="text-small">(important)</text>
  <text x="660" y="155" class="text-label">Node 1</text>
  <text x="840" y="155" text-anchor="end" class="text-small">(recent)</text>
  <text x="660" y="175" class="text-label">Node 5</text>
  <text x="840" y="175" text-anchor="end" class="text-small">(balanced)</text>
  <text x="660" y="195" class="text-label">Node 2</text>
  <text x="840" y="195" text-anchor="end" class="text-small">(fits)</text>
  <text x="660" y="215" class="text-small" fill="#808080">...</text>
  <text x="750" y="245" text-anchor="middle" class="text-small" fill="#66BB6A">✓ Within token limit</text>

  <!-- LLM Prompt Box -->
  <rect x="250" y="330" width="400" height="180" class="llm-box" rx="5"/>
  <text x="450" y="355" text-anchor="middle" class="text-header">LLM Prompt</text>

  <text x="260" y="385" class="text-small" fill="#BB86FC">System: You are a helpful assistant...</text>
  <text x="260" y="410" class="text-small" fill="#BB86FC">Context from memory:</text>
  <text x="270" y="430" class="text-small" fill="#E0E0E0">[Assembled Context String]</text>
  <text x="260" y="455" class="text-small" fill="#BB86FC">User: How do we handle auth?</text>
  <text x="260" y="480" class="text-small" fill="#BB86FC">Assistant:</text>

  <!-- Arrows -->
  <path d="M 250 160 L 330 160" class="arrow"/>
  <text x="290" y="150" text-anchor="middle" class="text-small">select &amp;</text>
  <text x="290" y="163" text-anchor="middle" class="text-small">sort</text>

  <path d="M 570 160 L 650 160" class="arrow"/>
  <text x="610" y="150" text-anchor="middle" class="text-small">assemble</text>

  <path d="M 750 260 L 750 330" class="arrow"/>
  <text x="770" y="300" class="text-small">insert into</text>
  <text x="770" y="313" class="text-small">prompt</text>

  <!-- Token count indicator -->
  <rect x="650" y="275" width="200" height="30" fill="rgba(255, 152, 0, 0.1)" stroke="#FF9800" stroke-width="1" rx="3"/>
  <rect x="650" y="275" width="140" height="30" fill="rgba(76, 175, 80, 0.3)" rx="3"/>
  <text x="750" y="293" text-anchor="middle" class="text-small">4700 / 5000 tokens</text>
</svg>

## Basic Usage

The `assemble_context` method on working memory creates a context string:

```ruby
# Basic context assembly
context = htm.working_memory.assemble_context(
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
context = htm.working_memory.assemble_context(strategy: :recent)
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
    @htm.remember(
      "User: #{user_message}",
      metadata: { turn: @turn, role: "user" }
    )

    # Get recent context
    context = @htm.working_memory.assemble_context(
      strategy: :recent,
      max_tokens: 10_000
    )

    # Generate response
    response = llm_generate(context, user_message)

    # Store assistant response
    @htm.remember(
      "Assistant: #{response}",
      metadata: { turn: @turn, role: "assistant" }
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

### Frequent Strategy

The `:frequent` strategy prioritizes frequently accessed memories.

```ruby
context = htm.working_memory.assemble_context(strategy: :frequent)
```

**How it works:**

1. Sort memories by access count (highest first)
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
# Knowledge base with priorities tracked via access patterns
class KnowledgeBot
  def initialize
    @htm = HTM.new(robot_name: "Knowledge")

    # Add critical system constraints
    @htm.remember(
      "CRITICAL: Never expose API keys in responses",
      metadata: { priority: "critical", category: "constraint" }
    )

    # Add important user preferences
    @htm.remember(
      "User prefers concise explanations",
      metadata: { priority: "high", category: "preference" }
    )

    # Add general knowledge
    @htm.remember(
      "Python uses indentation for code blocks",
      metadata: { priority: "medium", category: "fact" }
    )
  end

  def answer_question(question)
    # Get most frequently accessed context first
    context = @htm.working_memory.assemble_context(
      strategy: :frequent,
      max_tokens: 5_000
    )

    # Frequently accessed constraints and preferences are included first
    generate_answer(context, question)
  end

  private

  def generate_answer(context, question)
    # LLM integration
    "Answer based on frequently accessed context"
  end
end
```

### Balanced Strategy (Recommended)

The `:balanced` strategy combines access frequency and recency using a weighted formula.

```ruby
context = htm.working_memory.assemble_context(strategy: :balanced)
```

**How it works:**

1. Calculate score: `log(1 + access_count) × recency_factor`
2. Sort by score (highest first)
3. Add memories until token limit reached
4. Return assembled context

**Scoring examples:**

```ruby
# Recent + Frequently accessed: High score
# Access count: 10, Age: 1 hour
# Score: log(11) × (1 / (1 + 1/3600)) ≈ 2.4 ✓ Included

# Old + Frequently accessed: Medium score
# Access count: 10, Age: 24 hours
# Score: log(11) × (1 / (1 + 24)) ≈ 0.10 ≈ Maybe

# Recent + Rarely accessed: Low score
# Access count: 1, Age: 1 hour
# Score: log(2) × (1 / (1 + 1/3600)) ≈ 0.69 ≈ Maybe

# Old + Rarely accessed: Very low score
# Access count: 1, Age: 24 hours
# Score: log(2) × (1 / (1 + 24)) ≈ 0.03 ✗ Excluded
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
    @htm.remember(
      user_input,
      metadata: { role: "user", timestamp: Time.now.to_i }
    )

    # Get balanced context (frequent + recent)
    context = @htm.working_memory.assemble_context(
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
context = htm.working_memory.assemble_context(strategy: :balanced)

# Custom limit
context = htm.working_memory.assemble_context(
  strategy: :balanced,
  max_tokens: 50_000
)

# Small context for simple queries
context = htm.working_memory.assemble_context(
  strategy: :recent,
  max_tokens: 5_000
)

# Large context for complex tasks
context = htm.working_memory.assemble_context(
  strategy: :frequent,
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
  htm.remember("Memory #{i}")
end

# Benchmark strategies
Benchmark.bm(15) do |x|
  x.report("Recent:") do
    100.times { htm.working_memory.assemble_context(strategy: :recent) }
  end

  x.report("Frequent:") do
    100.times { htm.working_memory.assemble_context(strategy: :frequent) }
  end

  x.report("Balanced:") do
    100.times { htm.working_memory.assemble_context(strategy: :balanced) }
  end
end

# Typical results:
#                       user     system      total        real
# Recent:           0.050000   0.000000   0.050000 (  0.051234)
# Frequent:         0.045000   0.000000   0.045000 (  0.047891)
# Balanced:         0.080000   0.000000   0.080000 (  0.082456)
```

**Notes:**

- `:recent` is fastest (simple sort)
- `:frequent` is fast (simple sort)
- `:balanced` is slower (complex calculation)
- All are typically < 100ms for normal working memory sizes

### Quality Comparison

```ruby
# Test scenario: Mix of frequently accessed old data and recent rarely accessed data

# Setup
htm = HTM.new(robot_name: "Test")

# Add frequently accessed data (simulate high access count)
htm.remember("Critical system constraint", metadata: { priority: "critical" })
sleep 1  # Simulate age

# Add recent but rarely accessed data
20.times do |i|
  htm.remember("Recent note #{i}", metadata: { priority: "low" })
end

# Compare strategies
puts "=== Recent Strategy ==="
context = htm.working_memory.assemble_context(strategy: :recent, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

puts "\n=== Frequent Strategy ==="
context = htm.working_memory.assemble_context(strategy: :frequent, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

puts "\n=== Balanced Strategy ==="
context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: 1000)
puts context.include?("Critical system constraint") ? "✓ Has critical" : "✗ Missing critical"

# Results depend on actual access patterns:
# Recent: May miss older frequently accessed data
# Frequent: Prioritizes frequently accessed items
# Balanced: Combines frequency and recency
```

## Advanced Techniques

### 1. Multi-Strategy Context

Use multiple strategies for comprehensive context:

```ruby
def multi_strategy_context(max_tokens_per_strategy: 10_000)
  # Get different perspectives
  recent = htm.working_memory.assemble_context(
    strategy: :recent,
    max_tokens: max_tokens_per_strategy
  )

  frequent = htm.working_memory.assemble_context(
    strategy: :frequent,
    max_tokens: max_tokens_per_strategy
  )

  # Combine (you might want to deduplicate)
  combined = <<~CONTEXT
    === Recent Context ===
    #{recent}

    === Frequently Accessed Context ===
    #{frequent}
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
  elsif query.match?(/important|critical|must|frequent/)
    :frequent
  else
    :balanced
  end

  htm.working_memory.assemble_context(strategy: strategy, max_tokens: 20_000)
end

# Usage
context = smart_context("What are the recent changes?")    # Uses :recent
context = smart_context("What are critical constraints?")  # Uses :frequent
context = smart_context("How do we handle auth?")         # Uses :balanced
```

### 3. Filtered Context

Include only memories matching specific metadata:

```ruby
def filtered_context(category:)
  # Recall memories with specific metadata
  memories = htm.recall(
    category,
    timeframe: "last 24 hours",
    metadata: { category: category },
    strategy: :hybrid,
    limit: 50,
    raw: true
  )

  # Manually assemble context from results
  memories.map { |m| m['content'] }.join("\n\n")
end

# Usage
facts_only = filtered_context(category: "fact")
decisions_only = filtered_context(category: "decision")
```

### 4. Sectioned Context

Organize context into sections:

```ruby
def sectioned_context
  # Get different types of context using metadata filtering
  facts = htm.recall(
    "facts",
    timeframe: "all time",
    metadata: { category: "fact" },
    limit: 5,
    raw: true
  )

  decisions = htm.recall(
    "decisions",
    timeframe: "all time",
    metadata: { category: "decision" },
    limit: 5,
    raw: true
  )

  recent = htm.recall(
    "recent",
    timeframe: "last hour",
    limit: 5,
    raw: true
  )

  # Format as sections
  <<~CONTEXT
    === Core Facts ===
    #{facts.map { |f| "- #{f['content']}" }.join("\n")}

    === Key Decisions ===
    #{decisions.map { |d| "- #{d['content']}" }.join("\n")}

    === Recent Activity ===
    #{recent.map { |r| "- #{r['content']}" }.join("\n")}
  CONTEXT
end
```

### 5. Token-Aware Context

Ensure context fits LLM limits:

```ruby
class TokenAwareContext
  def initialize(htm)
    @htm = htm
  end

  def create(strategy:, llm_context_window:, reserve_for_prompt: 1000)
    # Calculate available tokens
    available = llm_context_window - reserve_for_prompt

    # Get context
    context = @htm.working_memory.assemble_context(
      strategy: strategy,
      max_tokens: available
    )

    # Verify token count
    actual_tokens = HTM.configuration.count_tokens(context)

    if actual_tokens > available
      warn "Context exceeded limit! Truncating..."
      # Retry with smaller limit
      context = @htm.working_memory.assemble_context(
        strategy: strategy,
        max_tokens: (available * 0.9).to_i  # 90% to be safe
      )
    end

    context
  end
end

# Usage
context_builder = TokenAwareContext.new(htm)

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
  context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: 50_000)

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

    @htm.remember(
      user_msg,
      tags: ["conversation:#{@conversation_id}"],
      metadata: { role: "user", timestamp: timestamp }
    )

    @htm.remember(
      assistant_msg,
      tags: ["conversation:#{@conversation_id}"],
      metadata: { role: "assistant", timestamp: timestamp }
    )
  end

  def get_context_for_llm
    # Get recent conversation
    @htm.working_memory.assemble_context(
      strategy: :recent,
      max_tokens: 10_000
    )
  end
end
```

### Pattern 3: RAG with Context

```ruby
def rag_query(question)
  # 1. Retrieve relevant memories (adds to working memory)
  relevant = htm.recall(
    question,
    timeframe: "last month",
    strategy: :hybrid,
    limit: 10
  )

  # 2. Create context from working memory (includes retrieved + existing)
  context = htm.working_memory.assemble_context(
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
    context = @htm.working_memory.assemble_context(
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
  context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: start_tokens)

  # Check if more context needed (based on your logic)
  if needs_more_context?(context)
    # Expand gradually
    context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: start_tokens * 2)
  end

  if still_needs_more?(context)
    # Expand to max
    context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: max_tokens)
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
  # Determine what's relevant based on query
  include_facts = query.match?(/fact|truth|information/)
  include_decisions = query.match?(/decision|choice|why/)
  include_code = query.match?(/code|implement|example/)

  # Build custom context using metadata filtering
  parts = []

  if include_facts
    facts = htm.recall(
      query,
      timeframe: "all time",
      metadata: { category: "fact" },
      limit: 5,
      raw: true
    )
    parts << "Facts:\n" + facts.map { |f| "- #{f['content']}" }.join("\n")
  end

  if include_decisions
    decisions = htm.recall(
      query,
      timeframe: "all time",
      metadata: { category: "decision" },
      limit: 5,
      raw: true
    )
    parts << "Decisions:\n" + decisions.map { |d| "- #{d['content']}" }.join("\n")
  end

  if include_code
    code = htm.recall(
      query,
      timeframe: "all time",
      metadata: { category: "code" },
      limit: 3,
      raw: true
    )
    parts << "Code Examples:\n" + code.map { |c| c['content'] }.join("\n\n")
  end

  parts.join("\n\n")
end
```

## Best Practices

### 1. Choose the Right Strategy

```ruby
# Use :recent for conversations
context = htm.working_memory.assemble_context(strategy: :recent)

# Use :frequent for critical operations
context = htm.working_memory.assemble_context(strategy: :frequent)

# Use :balanced as default (recommended)
context = htm.working_memory.assemble_context(strategy: :balanced)
```

### 2. Set Appropriate Token Limits

```ruby
# Don't exceed LLM context window
context = htm.working_memory.assemble_context(
  strategy: :balanced,
  max_tokens: 100_000  # Leave room for prompt
)

# Smaller contexts are faster
context = htm.working_memory.assemble_context(
  strategy: :recent,
  max_tokens: 5_000  # Quick queries
)
```

### 3. Monitor Context Quality

```ruby
def monitor_context
  context = htm.working_memory.assemble_context(strategy: :balanced)

  puts "Context length: #{context.length} characters"

  # Count tokens
  tokens = HTM.configuration.count_tokens(context)
  puts "Estimated tokens: #{tokens}"

  # Check if too small or too large
  warn "Context very small!" if tokens < 500
  warn "Context very large!" if tokens > 100_000
end
```

### 4. Include Metadata

```ruby
def context_with_metadata
  context = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: 20_000)

  # Add metadata header
  wm = htm.working_memory

  <<~CONTEXT
    [Context assembled at #{Time.now}]
    [Strategy: balanced]
    [Working memory: #{wm.node_count} nodes]
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

# Add various memories with metadata for categorization
htm.remember("User prefers Ruby", metadata: { category: "fact", priority: "high" })
htm.remember("Use PostgreSQL for database", metadata: { category: "decision", priority: "high" })
htm.remember("Currently debugging auth module", metadata: { category: "context", priority: "medium" })
htm.remember("def authenticate(token)...", metadata: { category: "code", priority: "medium" })
htm.remember("Check logs later", metadata: { category: "note", priority: "low" })

puts "=== Recent Strategy ==="
recent = htm.working_memory.assemble_context(strategy: :recent, max_tokens: 5_000)
puts recent
puts "\n(Newest first)"

puts "\n=== Frequent Strategy ==="
frequent = htm.working_memory.assemble_context(strategy: :frequent, max_tokens: 5_000)
puts frequent
puts "\n(Most frequently accessed first)"

puts "\n=== Balanced Strategy ==="
balanced = htm.working_memory.assemble_context(strategy: :balanced, max_tokens: 5_000)
puts balanced
puts "\n(Balanced frequency + recency)"

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
