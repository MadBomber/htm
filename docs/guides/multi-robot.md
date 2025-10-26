# Multi-Robot Usage

HTM's "hive mind" architecture enables multiple robots to share knowledge through a common long-term memory. This guide covers setting up multi-robot systems, attribution tracking, and collaboration patterns.

## Understanding the Hive Mind

In HTM, all robots share the same long-term memory database but maintain separate working memories:

![HTM Hive Mind Architecture](../assets/images/htm-hive-mind-architecture.svg)

**Key Principles:**

- **Shared Knowledge**: All memories are accessible to all robots
- **Private Working Memory**: Each robot has its own active context
- **Full Attribution**: Track which robot added each memory
- **Collective Intelligence**: Robots learn from each other's experiences

## Setting Up Multiple Robots

### Basic Multi-Robot Setup

```ruby
# Robot 1: Research Assistant
research_bot = HTM.new(
  robot_name: "Research Assistant",
  robot_id: "research-001",
  working_memory_size: 128_000
)

# Robot 2: Code Helper
code_bot = HTM.new(
  robot_name: "Code Helper",
  robot_id: "code-001",
  working_memory_size: 128_000
)

# Robot 3: Documentation Writer
docs_bot = HTM.new(
  robot_name: "Docs Writer",
  robot_id: "docs-001",
  working_memory_size: 64_000
)

# Each robot can access shared knowledge
research_bot.add_node(
  "finding_001",
  "Research shows PostgreSQL outperforms MongoDB for ACID workloads",
  type: :fact,
  importance: 8.0,
  tags: ["research", "database"]
)

# Code bot can access this finding
findings = code_bot.recall(
  timeframe: "last hour",
  topic: "database performance"
)

# Docs bot can document it
docs_bot.add_node(
  "doc_001",
  "PostgreSQL performance documented based on research findings",
  type: :context,
  importance: 6.0,
  tags: ["documentation", "database"],
  related_to: ["finding_001"]
)
```

## Robot Identification

### Session IDs vs Persistent IDs

Choose the right identification strategy:

```ruby
# Strategy 1: Persistent Robot (recommended for production)
persistent_bot = HTM.new(
  robot_name: "Production Assistant",
  robot_id: "prod-assistant-001"  # Fixed, reusable
)

# Strategy 2: Session-based Robot (for temporary workflows)
session_id = SecureRandom.uuid
session_bot = HTM.new(
  robot_name: "Temp Session",
  robot_id: "session-#{session_id}"  # Unique per session
)

# Strategy 3: User-specific Robot
user_id = "alice"
user_bot = HTM.new(
  robot_name: "Alice's Assistant",
  robot_id: "user-#{user_id}-assistant"
)
```

!!! tip "Naming Conventions"
    - **Production robots**: `service-purpose-001` (e.g., `api-assistant-001`)
    - **User robots**: `user-{user_id}-{purpose}` (e.g., `user-alice-assistant`)
    - **Session robots**: `session-{uuid}` (e.g., `session-abc123...`)
    - **Team robots**: `team-{name}-{purpose}` (e.g., `team-eng-reviewer`)

### Robot Registry

All robots are automatically registered:

```ruby
# Robots are registered when created
bot = HTM.new(robot_name: "My Bot", robot_id: "bot-001")

# Query robot registry
config = HTM::Database.default_config
conn = PG.connect(config)

result = conn.exec("SELECT * FROM robots ORDER BY last_active DESC")

puts "Registered robots:"
result.each do |row|
  puts "#{row['name']} (#{row['id']})"
  puts "  Created: #{row['created_at']}"
  puts "  Last active: #{row['last_active']}"
  puts
end

conn.close
```

## Attribution Tracking

### Who Said What?

Track which robot contributed which memories:

```ruby
# Add memories from different robots
alpha = HTM.new(robot_name: "Alpha", robot_id: "alpha")
beta = HTM.new(robot_name: "Beta", robot_id: "beta")

alpha.add_node("alpha_001", "Alpha's insight about caching", type: :fact)
beta.add_node("beta_001", "Beta's approach to testing", type: :fact)

# Query by robot
def memories_by_robot(robot_id)
  config = HTM::Database.default_config
  conn = PG.connect(config)

  result = conn.exec_params(
    "SELECT key, value, type FROM nodes WHERE robot_id = $1",
    [robot_id]
  )

  memories = result.to_a
  conn.close
  memories
end

alpha_memories = memories_by_robot("alpha")
puts "Alpha contributed #{alpha_memories.length} memories"
```

### Which Robot Said...?

Use HTM's built-in attribution tracking:

```ruby
# Find which robots discussed a topic
breakdown = htm.which_robot_said("PostgreSQL")

puts "Robots that discussed PostgreSQL:"
breakdown.each do |robot_id, count|
  puts "  #{robot_id}: #{count} mentions"
end

# Example output:
# Robots that discussed PostgreSQL:
#   research-001: 15 mentions
#   code-001: 8 mentions
#   docs-001: 3 mentions
```

### Conversation Timeline

See the chronological conversation across robots:

```ruby
timeline = htm.conversation_timeline("architecture decisions", limit: 50)

puts "Architecture discussion timeline:"
timeline.each do |entry|
  puts "#{entry[:timestamp]} - #{entry[:robot]}"
  puts "  [#{entry[:type]}] #{entry[:content][0..100]}..."
  puts
end
```

## Collaboration Patterns

### Pattern 1: Specialized Roles

Each robot has a specific role and expertise:

```ruby
class MultiRobotSystem
  def initialize
    @researcher = HTM.new(
      robot_name: "Researcher",
      robot_id: "researcher-001"
    )

    @developer = HTM.new(
      robot_name: "Developer",
      robot_id: "developer-001"
    )

    @reviewer = HTM.new(
      robot_name: "Reviewer",
      robot_id: "reviewer-001"
    )
  end

  def process_feature_request(feature)
    # 1. Researcher gathers requirements
    @researcher.add_node(
      "research_#{feature}",
      "Research findings for #{feature}",
      type: :fact,
      importance: 8.0,
      tags: ["research", feature]
    )

    # 2. Developer recalls research and implements
    research = @developer.recall(
      timeframe: "last hour",
      topic: "research #{feature}"
    )

    @developer.add_node(
      "impl_#{feature}",
      "Implementation plan based on research",
      type: :decision,
      importance: 9.0,
      tags: ["implementation", feature],
      related_to: ["research_#{feature}"]
    )

    # 3. Reviewer checks work
    work = @reviewer.recall(
      timeframe: "last hour",
      topic: feature
    )

    @reviewer.add_node(
      "review_#{feature}",
      "Code review findings",
      type: :context,
      importance: 7.0,
      tags: ["review", feature]
    )
  end
end

system = MultiRobotSystem.new
system.process_feature_request("user-authentication")
```

### Pattern 2: Shift Handoff

Robots pass context between shifts:

```ruby
class ShiftHandoff
  def initialize
    @current_shift = nil
  end

  def start_shift(shift_name)
    @current_shift = HTM.new(
      robot_name: "#{shift_name} Bot",
      robot_id: "shift-#{shift_name.downcase}"
    )

    # Recall context from previous shift
    handoff = @current_shift.recall(
      timeframe: "last 24 hours",
      topic: "shift handoff urgent",
      strategy: :hybrid,
      limit: 20
    )

    puts "#{shift_name} shift starting"
    puts "Received #{handoff.length} items from previous shift"

    handoff
  end

  def end_shift(summary)
    # Document shift handoff
    @current_shift.add_node(
      "handoff_#{Time.now.to_i}",
      summary,
      type: :context,
      importance: 9.0,
      tags: ["shift-handoff", "urgent"]
    )

    puts "Shift handoff documented"
  end
end

# Usage
handoff = ShiftHandoff.new

# Morning shift
morning = handoff.start_shift("Morning")
# ... do morning work
handoff.end_shift("Three critical bugs fixed, deploy scheduled for 2pm")

# Afternoon shift
afternoon = handoff.start_shift("Afternoon")
# ... receives morning's summary
```

### Pattern 3: Expert Consultation

Specialized experts provide knowledge:

```ruby
class ExpertSystem
  def initialize
    @experts = {
      database: HTM.new(
        robot_name: "Database Expert",
        robot_id: "expert-database"
      ),
      security: HTM.new(
        robot_name: "Security Expert",
        robot_id: "expert-security"
      ),
      performance: HTM.new(
        robot_name: "Performance Expert",
        robot_id: "expert-performance"
      )
    }

    @general = HTM.new(
      robot_name: "General Assistant",
      robot_id: "assistant-general"
    )
  end

  def consult(topic)
    # Determine which expert to consult
    expert_type = determine_expert(topic)
    expert = @experts[expert_type]

    # Get expert knowledge
    knowledge = expert.recall(
      timeframe: "all time",
      topic: topic,
      strategy: :hybrid,
      limit: 10
    )

    # General assistant learns from expert
    knowledge.each do |k|
      @general.add_node(
        "learned_#{SecureRandom.hex(4)}",
        "Learned from #{expert_type} expert: #{k['value']}",
        type: :fact,
        importance: k['importance'],
        tags: ["learned", expert_type.to_s],
        related_to: [k['key']]
      )
    end

    knowledge
  end

  private

  def determine_expert(topic)
    # Simple keyword matching
    case topic.downcase
    when /database|sql|query/
      :database
    when /security|auth|encryption/
      :security
    when /performance|speed|optimization/
      :performance
    else
      :database  # default
    end
  end
end

system = ExpertSystem.new
knowledge = system.consult("PostgreSQL query optimization")
```

### Pattern 4: Collaborative Decision Making

Multiple robots contribute to decisions:

```ruby
class CollaborativeDecision
  def initialize(topic)
    @topic = topic
    @participants = []
  end

  def add_participant(name, role)
    bot = HTM.new(
      robot_name: "#{name} (#{role})",
      robot_id: "decision-#{role.downcase}-#{SecureRandom.hex(4)}"
    )
    @participants << { name: name, role: role, bot: bot }
    bot
  end

  def gather_input(bot, opinion)
    bot.add_node(
      "opinion_#{SecureRandom.hex(4)}",
      opinion,
      type: :context,
      importance: 8.0,
      tags: ["decision", @topic, "opinion"]
    )
  end

  def make_decision(decision_maker)
    # Recall all opinions
    opinions = decision_maker.recall(
      timeframe: "last hour",
      topic: "decision #{@topic} opinion",
      strategy: :hybrid,
      limit: 50
    )

    puts "#{decision_maker.robot_name} considering:"
    opinions.each do |opinion|
      puts "- #{opinion['value'][0..100]}..."
    end

    # Document final decision
    decision_maker.add_node(
      "decision_#{@topic}_final",
      "Final decision on #{@topic} after considering team input",
      type: :decision,
      importance: 10.0,
      tags: ["decision", @topic, "final"]
    )
  end
end

# Usage
decision = CollaborativeDecision.new("database-choice")

# Gather input
developer = decision.add_participant("Alice", "Developer")
decision.gather_input(developer, "PostgreSQL for reliability")

architect = decision.add_participant("Bob", "Architect")
decision.gather_input(architect, "PostgreSQL for ACID compliance")

dba = decision.add_participant("Carol", "DBA")
decision.gather_input(dba, "PostgreSQL for operational maturity")

# Make decision
lead = decision.add_participant("Dave", "TechLead")
decision.make_decision(lead)
```

## Shared vs Private Knowledge

### Sharing Strategies

Control what gets shared:

```ruby
class SmartSharing
  def initialize(robot_id)
    @htm = HTM.new(robot_name: "Smart Bot", robot_id: robot_id)
    @private_prefix = "private_#{robot_id}_"
  end

  def add_shared(key, value, **opts)
    # Shared with all robots
    @htm.add_node(key, value, **opts.merge(
      tags: (opts[:tags] || []) + ["shared"]
    ))
  end

  def add_private(key, value, **opts)
    # Use robot-specific key prefix
    private_key = "#{@private_prefix}#{key}"
    @htm.add_node(private_key, value, **opts.merge(
      tags: (opts[:tags] || []) + ["private"],
      importance: (opts[:importance] || 5.0)
    ))
  end

  def recall_shared(topic)
    # Only shared knowledge
    @htm.recall(
      timeframe: "all time",
      topic: "shared #{topic}",
      strategy: :hybrid
    ).select { |m| m['tags']&.include?("shared") }
  end

  def recall_private(topic)
    # Only my private knowledge
    @htm.recall(
      timeframe: "all time",
      topic: topic,
      strategy: :hybrid
    ).select { |m| m['key'].start_with?(@private_prefix) }
  end
end

# Usage
bot1 = SmartSharing.new("bot-001")
bot1.add_shared("shared_fact", "Everyone should know this", type: :fact)
bot1.add_private("my_thought", "Private thought", type: :context)

bot2 = SmartSharing.new("bot-002")
shared = bot2.recall_shared("fact")  # Can see shared_fact
private = bot2.recall_private("thought")  # Won't see bot1's private thoughts
```

## Cross-Robot Queries

### Finding Robot Activity

```ruby
# Get all robots and their activity
def get_robot_activity
  config = HTM::Database.default_config
  conn = PG.connect(config)

  result = conn.exec(
    <<~SQL
      SELECT
        r.id,
        r.name,
        COUNT(n.id) as memory_count,
        MAX(n.created_at) as last_memory,
        r.last_active
      FROM robots r
      LEFT JOIN nodes n ON r.id = n.robot_id
      GROUP BY r.id, r.name, r.last_active
      ORDER BY r.last_active DESC
    SQL
  )

  robots = result.to_a
  conn.close
  robots
end

# Display activity
robots = get_robot_activity
puts "Robot Activity Report:"
robots.each do |r|
  puts "\n#{r['name']} (#{r['id']})"
  puts "  Memories: #{r['memory_count']}"
  puts "  Last memory: #{r['last_memory']}"
  puts "  Last active: #{r['last_active']}"
end
```

### Cross-Robot Search

```ruby
def search_across_robots(topic, limit_per_robot: 5)
  config = HTM::Database.default_config
  conn = PG.connect(config)

  # Get all robots
  robots = conn.exec("SELECT id, name FROM robots")

  results = {}

  robots.each do |robot|
    # Search memories from this robot
    stmt = conn.prepare(
      "search_#{robot['id']}",
      <<~SQL
        SELECT key, value, type, importance, created_at
        FROM nodes
        WHERE robot_id = $1
        AND to_tsvector('english', value) @@ plainto_tsquery('english', $2)
        ORDER BY importance DESC
        LIMIT $3
      SQL
    )

    robot_results = conn.exec_prepared(
      "search_#{robot['id']}",
      [robot['id'], topic, limit_per_robot]
    )

    results[robot['name']] = robot_results.to_a
  end

  conn.close
  results
end

# Usage
results = search_across_robots("authentication")
results.each do |robot_name, memories|
  puts "\n=== #{robot_name} ==="
  memories.each do |m|
    puts "- [#{m['type']}] #{m['value'][0..80]}..."
  end
end
```

## Monitoring Multi-Robot Systems

### Dashboard

```ruby
class MultiRobotDashboard
  def initialize
    @config = HTM::Database.default_config
  end

  def summary
    conn = PG.connect(@config)

    # Total stats
    total_robots = conn.exec("SELECT COUNT(*) FROM robots").first['count'].to_i
    total_memories = conn.exec("SELECT COUNT(*) FROM nodes").first['count'].to_i

    # Per-robot breakdown
    breakdown = conn.exec(
      <<~SQL
        SELECT
          r.name,
          COUNT(n.id) as memories,
          AVG(n.importance) as avg_importance,
          MAX(n.created_at) as last_contribution
        FROM robots r
        LEFT JOIN nodes n ON r.id = n.robot_id
        GROUP BY r.id, r.name
        ORDER BY memories DESC
      SQL
    ).to_a

    conn.close

    {
      total_robots: total_robots,
      total_memories: total_memories,
      breakdown: breakdown
    }
  end

  def print_summary
    data = summary

    puts "=== Multi-Robot System Dashboard ==="
    puts "Total robots: #{data[:total_robots]}"
    puts "Total memories: #{data[:total_memories]}"
    puts "\nPer-robot breakdown:"

    data[:breakdown].each do |robot|
      puts "\n#{robot['name']}"
      puts "  Memories: #{robot['memories']}"
      puts "  Avg importance: #{robot['avg_importance'].to_f.round(2)}"
      puts "  Last contribution: #{robot['last_contribution']}"
    end
  end
end

dashboard = MultiRobotDashboard.new
dashboard.print_summary
```

## Best Practices

### 1. Clear Robot Roles

```ruby
# Good: Clear, specific roles
researcher = HTM.new(robot_name: "Research Specialist", robot_id: "research-001")
coder = HTM.new(robot_name: "Code Generator", robot_id: "coder-001")

# Avoid: Vague roles
bot1 = HTM.new(robot_name: "Bot 1", robot_id: "bot1")
```

### 2. Consistent Naming

```ruby
# Good: Consistent naming scheme
class RobotFactory
  def self.create(service, purpose, instance = "001")
    HTM.new(
      robot_name: "#{service.capitalize} #{purpose.capitalize}",
      robot_id: "#{service}-#{purpose}-#{instance}"
    )
  end
end

api_assistant = RobotFactory.create("api", "assistant", "001")
api_validator = RobotFactory.create("api", "validator", "001")
```

### 3. Attribution in Content

```ruby
# Include attribution in the content itself
bot.add_node(
  "finding_001",
  "Research by #{bot.robot_name}: PostgreSQL outperforms MongoDB",
  type: :fact,
  importance: 8.0
)
```

### 4. Regular Reconciliation

```ruby
# Periodically sync understanding across robots
def sync_robots(*robots)
  # Find recent high-importance memories
  shared_knowledge = robots.first.recall(
    timeframe: "last 24 hours",
    topic: "important shared",
    strategy: :hybrid,
    limit: 50
  ).select { |m| m['importance'].to_f >= 8.0 }

  puts "Syncing #{shared_knowledge.length} important memories across #{robots.length} robots"
end
```

### 5. Clean Up Inactive Robots

```ruby
def cleanup_inactive_robots(days: 30)
  config = HTM::Database.default_config
  conn = PG.connect(config)

  cutoff = Time.now - (days * 24 * 3600)

  result = conn.exec_params(
    "SELECT id, name FROM robots WHERE last_active < $1",
    [cutoff]
  )

  puts "Inactive robots (last active > #{days} days):"
  result.each do |robot|
    puts "- #{robot['name']} (#{robot['id']})"
  end

  conn.close
end

cleanup_inactive_robots(days: 90)
```

## Complete Example

```ruby
require 'htm'

# Create a multi-robot development team
class DevTeam
  def initialize
    @analyst = HTM.new(
      robot_name: "Requirements Analyst",
      robot_id: "team-analyst-001"
    )

    @developer = HTM.new(
      robot_name: "Senior Developer",
      robot_id: "team-developer-001"
    )

    @tester = HTM.new(
      robot_name: "QA Tester",
      robot_id: "team-tester-001"
    )
  end

  def process_feature(feature_name)
    puts "\n=== Processing Feature: #{feature_name} ==="

    # 1. Analyst documents requirements
    puts "\n1. Analyst gathering requirements..."
    @analyst.add_node(
      "req_#{feature_name}",
      "Requirements for #{feature_name}: Must support OAuth2",
      type: :fact,
      importance: 9.0,
      tags: ["requirements", feature_name]
    )

    # 2. Developer recalls requirements and designs
    puts "\n2. Developer reviewing requirements..."
    requirements = @developer.recall(
      timeframe: "last hour",
      topic: "requirements #{feature_name}"
    )

    puts "Found #{requirements.length} requirements"

    @developer.add_node(
      "design_#{feature_name}",
      "Design for #{feature_name} based on requirements",
      type: :decision,
      importance: 9.0,
      tags: ["design", feature_name],
      related_to: ["req_#{feature_name}"]
    )

    # 3. Tester recalls everything and creates test plan
    puts "\n3. Tester creating test plan..."
    context = @tester.recall(
      timeframe: "last hour",
      topic: feature_name,
      strategy: :hybrid
    )

    puts "Tester reviewed #{context.length} items"

    @tester.add_node(
      "test_#{feature_name}",
      "Test plan for #{feature_name}",
      type: :context,
      importance: 8.0,
      tags: ["testing", feature_name],
      related_to: ["design_#{feature_name}", "req_#{feature_name}"]
    )

    # 4. Show collaboration
    puts "\n4. Collaboration summary:"
    timeline = @analyst.conversation_timeline(feature_name)
    timeline.each do |entry|
      puts "- #{entry[:robot]}: #{entry[:type]}"
    end

    # 5. Show attribution
    puts "\n5. Who contributed:"
    breakdown = @analyst.which_robot_said(feature_name)
    breakdown.each do |robot_id, count|
      puts "- #{robot_id}: #{count} memories"
    end
  end
end

# Run the team
team = DevTeam.new
team.process_feature("oauth-integration")
```

## Next Steps

- [**Context Assembly**](context-assembly.md) - Build context from multi-robot memories
- [**Long-term Memory**](long-term-memory.md) - Understand the shared storage layer
- [**Search Strategies**](search-strategies.md) - Find relevant memories across robots
