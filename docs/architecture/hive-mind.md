# Hive Mind Architecture: Multi-Robot Shared Memory

HTM implements a "hive mind" architecture where multiple robots (AI agents) share a global memory database. This enables cross-robot learning, context continuity across sessions, and collaborative knowledge building without requiring users to repeat information.

## Overview

In the hive mind model, all robots access a single shared long-term memory database while maintaining independent working memory for process isolation. This design provides the best of both worlds: global knowledge sharing with local performance optimization.

<svg viewBox="0 0 900 600" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <!-- Title -->
  <text x="450" y="30" text-anchor="middle" fill="#E0E0E0" font-size="18" font-weight="bold">Hive Mind: Shared Long-Term Memory</text>

  <!-- Central Database -->
  <ellipse cx="450" cy="300" rx="180" ry="120" fill="rgba(156, 39, 176, 0.2)" stroke="#9C27B0" stroke-width="3"/>
  <text x="450" y="280" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Long-Term Memory</text>
  <text x="450" y="305" text-anchor="middle" fill="#B0B0B0" font-size="12">PostgreSQL/TimescaleDB</text>
  <text x="450" y="325" text-anchor="middle" fill="#B0B0B0" font-size="12">Shared Global Database</text>
  <text x="450" y="345" text-anchor="middle" fill="#4CAF50" font-size="13" font-weight="bold">All Robots Access Here</text>

  <!-- Robot 1: Code Helper -->
  <rect x="50" y="80" width="200" height="100" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="2" rx="5"/>
  <text x="150" y="110" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 1: Code Helper</text>
  <text x="150" y="135" text-anchor="middle" fill="#B0B0B0" font-size="11">ID: robot-abc123</text>
  <text x="150" y="155" text-anchor="middle" fill="#B0B0B0" font-size="11">Own Working Memory</text>

  <!-- Robot 2: Research Assistant -->
  <rect x="650" y="80" width="200" height="100" fill="rgba(76, 175, 80, 0.2)" stroke="#4CAF50" stroke-width="2" rx="5"/>
  <text x="750" y="110" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 2: Research Bot</text>
  <text x="750" y="135" text-anchor="middle" fill="#B0B0B0" font-size="11">ID: robot-xyz789</text>
  <text x="750" y="155" text-anchor="middle" fill="#B0B0B0" font-size="11">Own Working Memory</text>

  <!-- Robot 3: Chat Companion -->
  <rect x="50" y="450" width="200" height="100" fill="rgba(255, 152, 0, 0.2)" stroke="#FF9800" stroke-width="2" rx="5"/>
  <text x="150" y="480" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 3: Chat Bot</text>
  <text x="150" y="505" text-anchor="middle" fill="#B0B0B0" font-size="11">ID: robot-def456</text>
  <text x="150" y="525" text-anchor="middle" fill="#B0B0B0" font-size="11">Own Working Memory</text>

  <!-- Robot 4: Design Assistant -->
  <rect x="650" y="450" width="200" height="100" fill="rgba(244, 67, 54, 0.2)" stroke="#F44336" stroke-width="2" rx="5"/>
  <text x="750" y="480" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 4: Designer</text>
  <text x="750" y="505" text-anchor="middle" fill="#B0B0B0" font-size="11">ID: robot-ghi012</text>
  <text x="750" y="525" text-anchor="middle" fill="#B0B0B0" font-size="11">Own Working Memory</text>

  <!-- Connections to central database -->
  <line x1="150" y1="180" x2="320" y2="240" stroke="#2196F3" stroke-width="3"/>
  <line x1="750" y1="180" x2="580" y2="240" stroke="#4CAF50" stroke-width="3"/>
  <line x1="150" y1="450" x2="320" y2="360" stroke="#FF9800" stroke-width="3"/>
  <line x1="750" y1="450" x2="580" y2="360" stroke="#F44336" stroke-width="3"/>

  <!-- Labels on connections -->
  <text x="235" y="210" fill="#2196F3" font-size="10">read/write</text>
  <text x="650" y="210" fill="#4CAF50" font-size="10">read/write</text>
  <text x="235" y="410" fill="#FF9800" font-size="10">read/write</text>
  <text x="650" y="410" fill="#F44336" font-size="10">read/write</text>

  <!-- Key benefit -->
  <rect x="300" y="520" width="300" height="60" fill="rgba(76, 175, 80, 0.1)" stroke="#4CAF50" stroke-width="2" rx="5"/>
  <text x="450" y="545" text-anchor="middle" fill="#4CAF50" font-size="13" font-weight="bold">Knowledge Sharing:</text>
  <text x="450" y="565" text-anchor="middle" fill="#B0B0B0" font-size="11">All robots see all memories</text>
</svg>

!!! info "Related ADR"
    See [ADR-004: Multi-Robot Shared Memory (Hive Mind)](adrs/004-hive-mind.md) for the complete architectural decision record.

## Why Hive Mind?

### Problems with Isolated Memory

When each robot has independent memory:

- Users repeat information across robots
- Context lost when switching robots
- No cross-robot learning
- Fragmented conversation history
- Architectural decisions made by one robot unknown to others

### Benefits of Shared Memory

With the hive mind architecture:

- **Context continuity**: User never repeats themselves
- **Cross-robot learning**: Knowledge compounds across agents
- **Seamless switching**: Switch robots without losing context
- **Unified knowledge base**: Single source of truth
- **Collaborative development**: Robots build on each other's work

!!! success "User Experience"
    With shared memory, users can switch from a code helper to a research assistant without explaining the project context again. The research assistant already knows what the code helper learned.

## Architecture Design

### Memory Topology

HTM uses a hybrid memory topology:

- **Long-Term Memory**: Shared globally across all robots
- **Working Memory**: Per-robot, process-local

<svg viewBox="0 0 800 500" xmlns="http://www.w3.org/2000/svg" style="background: transparent;">
  <!-- Title -->
  <text x="400" y="30" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Memory Topology: Shared LTM + Local WM</text>

  <!-- Legend -->
  <rect x="50" y="50" width="20" height="20" fill="rgba(156, 39, 176, 0.3)" stroke="#9C27B0"/>
  <text x="80" y="65" fill="#B0B0B0" font-size="12">Shared (Global)</text>
  <rect x="200" y="50" width="20" height="20" fill="rgba(33, 150, 243, 0.3)" stroke="#2196F3"/>
  <text x="230" y="65" fill="#B0B0B0" font-size="12">Per-Robot (Local)</text>

  <!-- Robot 1 -->
  <g transform="translate(0, 100)">
    <text x="150" y="0" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 1 (Process 1)</text>
    <rect x="50" y="20" width="200" height="80" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="2" rx="5"/>
    <text x="150" y="50" text-anchor="middle" fill="#E0E0E0" font-size="12">Working Memory</text>
    <text x="150" y="70" text-anchor="middle" fill="#B0B0B0" font-size="10">In-memory, token-limited</text>
    <text x="150" y="85" text-anchor="middle" fill="#B0B0B0" font-size="10">Independent</text>
  </g>

  <!-- Robot 2 -->
  <g transform="translate(300, 100)">
    <text x="150" y="0" text-anchor="middle" fill="#E0E0E0" font-size="14" font-weight="bold">Robot 2 (Process 2)</text>
    <rect x="50" y="20" width="200" height="80" fill="rgba(33, 150, 243, 0.2)" stroke="#2196F3" stroke-width="2" rx="5"/>
    <text x="150" y="50" text-anchor="middle" fill="#E0E0E0" font-size="12">Working Memory</text>
    <text x="150" y="70" text-anchor="middle" fill="#B0B0B0" font-size="10">In-memory, token-limited</text>
    <text x="150" y="85" text-anchor="middle" fill="#B0B0B0" font-size="10">Independent</text>
  </g>

  <!-- Shared Long-Term Memory -->
  <rect x="150" y="280" width="500" height="150" fill="rgba(156, 39, 176, 0.2)" stroke="#9C27B0" stroke-width="3" rx="5"/>
  <text x="400" y="310" text-anchor="middle" fill="#E0E0E0" font-size="16" font-weight="bold">Long-Term Memory (Shared)</text>
  <text x="400" y="340" text-anchor="middle" fill="#B0B0B0" font-size="12">PostgreSQL/TimescaleDB</text>
  <text x="400" y="365" text-anchor="middle" fill="#B0B0B0" font-size="12">All robots read/write here</text>
  <text x="400" y="390" text-anchor="middle" fill="#B0B0B0" font-size="12">Memories attributed with robot_id</text>
  <text x="400" y="410" text-anchor="middle" fill="#4CAF50" font-size="12" font-weight="bold">Single Source of Truth</text>

  <!-- Connections -->
  <line x1="150" y1="200" x2="300" y2="280" stroke="#9C27B0" stroke-width="2" marker-end="url(#arrow-purple)"/>
  <line x1="450" y1="200" x2="400" y2="280" stroke="#9C27B0" stroke-width="2" marker-end="url(#arrow-purple)"/>

  <text x="225" y="240" fill="#9C27B0" font-size="10">read/write</text>
  <text x="425" y="240" fill="#9C27B0" font-size="10">read/write</text>

  <defs>
    <marker id="arrow-purple" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#9C27B0"/>
    </marker>
  </defs>

  <!-- Key Point -->
  <rect x="100" y="460" width="600" height="30" fill="rgba(76, 175, 80, 0.1)" stroke="#4CAF50" stroke-width="1" rx="3"/>
  <text x="400" y="480" text-anchor="middle" fill="#4CAF50" font-size="12">Each robot has fast local cache (WM) + access to global knowledge (LTM)</text>
</svg>

### Why This Design?

**Shared Long-Term Memory:**

- Global knowledge base accessible to all robots
- Cross-robot context continuity
- Simplified architecture (single database)
- Unified search across all conversations

**Per-Robot Working Memory:**

- Fast O(1) local access without network overhead
- Process isolation (no distributed state synchronization)
- Independent token budgets per robot
- Simple implementation (Ruby Hash, no Redis needed)

!!! warning "Design Trade-off"
    This architecture optimizes for **single-user, multi-robot** scenarios. For multi-tenant deployments, add row-level security or database sharding by tenant_id.

## Robot Identification System

Every robot in the hive mind has a unique identity for attribution tracking and activity monitoring.

### Dual Identifier System

HTM uses two identifiers for each robot:

#### 1. Robot ID (`robot_id`)

- **Type**: UUID v4 (RFC 4122)
- **Format**: `"f47ac10b-58cc-4372-a567-0e02b2c3d479"`
- **Generation**: `SecureRandom.uuid` if not provided
- **Purpose**: Primary key, foreign key references, attribution
- **Uniqueness**: Guaranteed (collision probability: ~10^-36)

#### 2. Robot Name (`robot_name`)

- **Type**: String (human-readable)
- **Format**: Any descriptive string (e.g., "Code Helper", "Research Assistant")
- **Generation**: `"robot_#{robot_id[0..7]}"` if not provided
- **Purpose**: Display, debugging, logging
- **Uniqueness**: Not enforced (names can collide)

### Robot Initialization

```ruby
# Option 1: Auto-generated identity (ephemeral robot)
htm = HTM.new(robot_name: "Code Helper")
# robot_id: auto-generated UUID (new each session)
# robot_name: "Code Helper"

# Option 2: Persistent identity (stable robot)
ROBOT_ID = ENV['ROBOT_ID'] || "f47ac10b-58cc-4372-a567-0e02b2c3d479"
htm = HTM.new(
  robot_id: ROBOT_ID,
  robot_name: "Code Helper"
)
# robot_id: same across sessions
# robot_name: "Code Helper"

# Option 3: Minimal (auto-generate everything)
htm = HTM.new
# robot_id: auto-generated UUID
# robot_name: "robot_f47ac10b" (derived from UUID)
```

!!! tip "Persistent vs Ephemeral Robots"
    - **Ephemeral**: New UUID every session. Useful for testing or one-off tasks.
    - **Persistent**: Store robot_id in config/environment. Recommended for production robots with stable identities.

### Robot Registry

All robots are registered in the `robots` table on first initialization:

```sql
CREATE TABLE robots (
  id TEXT PRIMARY KEY,              -- robot_id (UUID)
  name TEXT,                         -- robot_name (human-readable)
  created_at TIMESTAMP DEFAULT NOW(),
  last_active TIMESTAMP DEFAULT NOW(),
  metadata JSONB                     -- future extensibility
);
```

**Registration flow:**

```ruby
def register_robot
  @long_term_memory.register_robot(@robot_id, @robot_name)
end

# SQL: UPSERT semantics
# INSERT INTO robots (id, name) VALUES ($1, $2)
# ON CONFLICT (id) DO UPDATE
# SET name = $2, last_active = CURRENT_TIMESTAMP
```

!!! info "Related ADR"
    See [ADR-008: Robot Identification System](adrs/008-robot-identification.md) for detailed design decisions.

## Memory Attribution

Every memory node stores the `robot_id` of the robot that created it, enabling attribution tracking and analysis.

### Attribution Schema

```sql
CREATE TABLE nodes (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  robot_id TEXT NOT NULL REFERENCES robots(id),  -- Attribution!
  ...
);

-- Index for robot-specific queries
CREATE INDEX idx_nodes_robot_id ON nodes(robot_id);
```

### Attribution Tracking

When a robot adds a memory:

```ruby
def add_node(key, value, ...)
  # Store with attribution
  node_id = @long_term_memory.add(
    key: key,
    value: value,
    robot_id: @robot_id,  # Attribution
    ...
  )
end
```

### Attribution Queries

#### Which robot said this?

```ruby
def which_robot_said(topic, limit: 100)
  results = @long_term_memory.search_fulltext(
    timeframe: (Time.at(0)..Time.now),
    query: topic,
    limit: limit
  )

  results.group_by { |n| n['robot_id'] }
         .transform_values(&:count)
end

# Example usage
breakdown = htm.which_robot_said("PostgreSQL")
# => { "robot-abc123" => 15, "robot-xyz789" => 8 }

# Get robot names
breakdown.map do |robot_id, count|
  robot = db.query("SELECT name FROM robots WHERE id = $1", [robot_id]).first
  "#{robot['name']}: #{count} mentions"
end
# => ["Code Helper: 15 mentions", "Research Bot: 8 mentions"]
```

#### Conversation timeline

```ruby
def conversation_timeline(topic, limit: 50)
  results = @long_term_memory.search_fulltext(
    timeframe: (Time.at(0)..Time.now),
    query: topic,
    limit: limit
  )

  results.sort_by { |n| n['created_at'] }
         .map { |n| {
           timestamp: n['created_at'],
           robot: n['robot_id'],
           content: n['value'],
           type: n['type']
         }}
end

# Example usage
timeline = htm.conversation_timeline("HTM design", limit: 20)
# => [
#   { timestamp: "2025-10-20 10:00:00", robot: "robot-abc123", content: "Let's use PostgreSQL", ... },
#   { timestamp: "2025-10-20 10:15:00", robot: "robot-xyz789", content: "I agree, TimescaleDB is perfect", ... },
#   ...
# ]
```

#### Robot activity

```sql
-- Which robots have been active?
SELECT id, name, last_active
FROM robots
ORDER BY last_active DESC;

-- Which robot contributed most memories?
SELECT r.name, COUNT(n.id) as memory_count
FROM robots r
LEFT JOIN nodes n ON n.robot_id = r.id
GROUP BY r.id, r.name
ORDER BY memory_count DESC;

-- What has a specific robot been doing?
SELECT operation, created_at, details
FROM operations_log
WHERE robot_id = 'robot-abc123'
ORDER BY created_at DESC
LIMIT 50;
```

## Cross-Robot Knowledge Sharing

The power of the hive mind lies in automatic knowledge sharing across robots.

### Use Case 1: Cross-Session Context

A user works with Robot A in one session, then Robot B in another session. Robot B automatically knows what Robot A learned.

```ruby
# Session 1 - Robot A (Code Helper)
htm_a = HTM.new(robot_id: "robot-abc123", robot_name: "Code Helper A")
htm_a.add_node(
  "user_pref_001",
  "User prefers debug_me over puts for debugging",
  type: :preference,
  importance: 9.0
)
# Stored in long-term memory with robot_id: "robot-abc123"

# === User logs out, logs in next day ===

# Session 2 - Robot B (different process, same or different machine)
htm_b = HTM.new(robot_id: "robot-xyz789", robot_name: "Code Helper B")

# Robot B recalls preferences
memories = htm_b.recall(timeframe: "last week", topic: "debugging preference")
# => Finds preference from Robot A!
# => [{ "key" => "user_pref_001", "robot_id" => "robot-abc123", ... }]

# Robot B knows user preference without being told
```

### Use Case 2: Collaborative Development

Different robots working on different aspects of a project can build on each other's knowledge.

```ruby
# Robot A (Architecture discussion)
htm_a = HTM.new(robot_name: "Architect Bot")
htm_a.add_node(
  "decision_001",
  "We decided to use PostgreSQL with TimescaleDB for HTM storage",
  type: :decision,
  importance: 10.0,
  tags: ["architecture", "database"]
)

# Robot B (Implementation)
htm_b = HTM.new(robot_name: "Code Bot")
memories = htm_b.recall(timeframe: "today", topic: "database decision")
# => Finds architectural decision from Robot A

# Robot B implements based on Robot A's decision
htm_b.add_node(
  "implementation_001",
  "Implemented Database class with ConnectionPool for PostgreSQL",
  type: :code,
  importance: 7.0,
  related_to: ["decision_001"],  # Link to Robot A's decision
  tags: ["implementation", "database"]
)
```

### Use Case 3: Multi-Robot Conversation Analysis

Analyze contributions from different robots across a conversation:

```ruby
# Get all mentions of "TimescaleDB"
breakdown = htm.which_robot_said("TimescaleDB", limit: 100)
# => {
#   "robot-abc123" => 25,  # Architect Bot
#   "robot-xyz789" => 12,  # Code Bot
#   "robot-def456" => 8    # Research Bot
# }

# Get chronological conversation
timeline = htm.conversation_timeline("TimescaleDB design", limit: 50)
# => [
#   { timestamp: "2025-10-20 10:00", robot: "robot-abc123", content: "Let's explore TimescaleDB" },
#   { timestamp: "2025-10-20 10:15", robot: "robot-xyz789", content: "I'll implement the connection" },
#   { timestamp: "2025-10-20 10:30", robot: "robot-def456", content: "Here's the research on compression" },
#   ...
# ]
```

## Robot Activity Tracking

HTM automatically tracks robot activity through:

### 1. Robot Registry Updates

Every HTM operation updates the robot's `last_active` timestamp:

```ruby
def update_robot_activity
  @long_term_memory.update_robot_activity(@robot_id)
end

# SQL
# UPDATE robots
# SET last_active = CURRENT_TIMESTAMP
# WHERE id = $1
```

### 2. Operations Log

Every operation is logged with robot attribution:

```ruby
def add_node(key, value, ...)
  # ... add node ...

  # Log operation
  @long_term_memory.log_operation(
    operation: 'add',
    node_id: node_id,
    robot_id: @robot_id,
    details: { key: key, type: type }
  )
end
```

```sql
CREATE TABLE operations_log (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  operation TEXT NOT NULL,  -- add, retrieve, recall, forget, evict
  node_id BIGINT REFERENCES nodes(id),
  robot_id TEXT NOT NULL REFERENCES robots(id),
  details JSONB
);
```

### 3. Activity Queries

```sql
-- Active robots in last 24 hours
SELECT id, name, last_active
FROM robots
WHERE last_active > NOW() - INTERVAL '24 hours'
ORDER BY last_active DESC;

-- Operations by robot
SELECT r.name, COUNT(ol.id) as operation_count
FROM robots r
JOIN operations_log ol ON ol.robot_id = r.id
WHERE ol.timestamp > NOW() - INTERVAL '7 days'
GROUP BY r.name
ORDER BY operation_count DESC;

-- Most active robots by memory contributions
SELECT r.name, COUNT(n.id) as memory_count
FROM robots r
JOIN nodes n ON n.robot_id = r.id
WHERE n.created_at > NOW() - INTERVAL '30 days'
GROUP BY r.name
ORDER BY memory_count DESC;
```

## Privacy Considerations

The hive mind architecture has important privacy implications:

### Current Design: Single-User Assumption

HTM v1 assumes a **single-user scenario** where all robots work for the same user:

- All robots see all memories
- No isolation between robots
- No access control or permissions
- Simple, performant, easy to use

!!! warning "Privacy Warning"
    In the current design, **all robots can access all memories**. This is intentional for single-user scenarios but unsuitable for multi-user or multi-tenant deployments without additional security layers.

### Future: Multi-Tenancy Support

For multi-user scenarios, consider these privacy enhancements:

#### 1. Row-Level Security (RLS)

PostgreSQL's RLS can enforce tenant isolation:

```sql
-- Enable RLS on nodes table
ALTER TABLE nodes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own tenant's nodes
CREATE POLICY tenant_isolation ON nodes
  FOR ALL
  TO PUBLIC
  USING (tenant_id = current_setting('app.tenant_id')::TEXT);

-- Set tenant context per connection
SET app.tenant_id = 'user-123';
```

#### 2. Robot Visibility Levels

Add visibility controls to nodes:

```sql
ALTER TABLE nodes ADD COLUMN visibility TEXT DEFAULT 'shared';
-- Values: 'private' (robot-only), 'shared' (all robots), 'team' (robot group)

-- Private memory (only this robot)
htm.add_node("private_key", "sensitive data", visibility: :private)

-- Shared with specific robots
htm.add_node("team_key", "team data", visibility: { team: ['robot-a', 'robot-b'] })
```

#### 3. Robot Groups/Teams

Organize robots into teams with shared memory:

```sql
CREATE TABLE robot_teams (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE robot_team_members (
  robot_id TEXT REFERENCES robots(id),
  team_id BIGINT REFERENCES robot_teams(id),
  PRIMARY KEY (robot_id, team_id)
);

-- Query memories by team
SELECT n.*
FROM nodes n
JOIN robot_team_members rtm ON rtm.robot_id = n.robot_id
WHERE rtm.team_id = $1;
```

## Performance Characteristics

### Shared Long-Term Memory

| Aspect | Performance | Notes |
|--------|------------|-------|
| **Concurrent reads** | Excellent | PostgreSQL read scaling |
| **Concurrent writes** | Good | MVCC handles concurrent inserts |
| **Attribution queries** | Fast | Indexed on `robot_id` |
| **Cross-robot search** | Fast | Same as single-robot search |
| **Registry updates** | Minimal overhead | Simple UPDATE per operation |

### Per-Robot Working Memory

| Aspect | Performance | Notes |
|--------|------------|-------|
| **Memory isolation** | O(1) | No synchronization needed |
| **Process independence** | Excellent | No shared state |
| **Eviction** | O(n log n) | Per-robot, doesn't affect others |
| **Context assembly** | O(n log n) | Per-robot, fast |

### Scalability

#### Vertical Scaling

- **Database connections**: Use connection pooling (default)
- **Robot count**: Limited by database connections (~100-200 concurrent)
- **Memory size**: Each robot process uses ~1-2GB RAM for working memory

#### Horizontal Scaling

- **Multi-process**: Each robot process is independent
- **Multi-host**: All hosts share PostgreSQL database
- **Read replicas**: Route reads to replicas, writes to primary
- **Sharding**: Partition by `robot_id` or `tenant_id` for massive scale

## Code Examples

### Example 1: Persistent Robot with Stable Identity

```ruby
# Store robot ID in config or environment
ROBOT_ID = ENV.fetch('ROBOT_ID', 'code-helper-001')

# Initialize with persistent identity
htm = HTM.new(
  robot_id: ROBOT_ID,
  robot_name: "Code Helper",
  working_memory_size: 128_000
)

# Add memories (attributed to this robot)
htm.add_node("arch_decision", "Use PostgreSQL", importance: 10.0)

# All memories from this robot_id across sessions
```

### Example 2: Multi-Robot Collaboration

```ruby
# Robot A: Architecture discussion
robot_a = HTM.new(robot_id: "arch-001", robot_name: "Architect")
robot_a.add_node(
  "db_choice",
  "PostgreSQL chosen for ACID guarantees and pgvector support",
  type: :decision,
  importance: 10.0
)

# Robot B: Implementation (different process, accesses same LTM)
robot_b = HTM.new(robot_id: "code-001", robot_name: "Coder")
decisions = robot_b.recall(timeframe: "today", topic: "database")
# => Finds Robot A's decision automatically

robot_b.add_node(
  "db_impl",
  "Implemented Database class with connection pooling",
  type: :code,
  related_to: ["db_choice"]  # Link to Robot A's decision
)
```

### Example 3: Robot Activity Dashboard

```ruby
# Get all robots and their activity
stats = {}

robots = db.query("SELECT * FROM robots ORDER BY last_active DESC")

robots.each do |robot|
  # Count memories
  memory_count = db.query(<<~SQL, [robot['id']]).first['count'].to_i
    SELECT COUNT(*) FROM nodes WHERE robot_id = $1
  SQL

  # Recent operations
  recent_ops = db.query(<<~SQL, [robot['id']]).to_a
    SELECT operation, COUNT(*) as count
    FROM operations_log
    WHERE robot_id = $1 AND timestamp > NOW() - INTERVAL '7 days'
    GROUP BY operation
  SQL

  stats[robot['name']] = {
    id: robot['id'],
    last_active: robot['last_active'],
    total_memories: memory_count,
    recent_operations: recent_ops
  }
end

# Display dashboard
stats.each do |name, data|
  puts "#{name} (#{data[:id]})"
  puts "  Last active: #{data[:last_active]}"
  puts "  Total memories: #{data[:total_memories]}"
  puts "  Recent operations:"
  data[:recent_operations].each do |op|
    puts "    #{op['operation']}: #{op['count']}"
  end
  puts
end
```

## Related Documentation

- [Architecture Index](index.md) - System overview and component summary
- [Architecture Overview](overview.md) - Detailed architecture and data flows
- [Two-Tier Memory System](two-tier-memory.md) - Working memory and long-term memory design
- [ADR-004: Multi-Robot Shared Memory (Hive Mind)](adrs/004-hive-mind.md)
- [ADR-008: Robot Identification System](adrs/008-robot-identification.md)
- [API Reference](../api/htm.md) - Complete API documentation
