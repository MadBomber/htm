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
  <text x="450" y="305" text-anchor="middle" fill="#B0B0B0" font-size="12">PostgreSQL</text>
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
  <text x="400" y="340" text-anchor="middle" fill="#B0B0B0" font-size="12">PostgreSQL</text>
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

## Memory Attribution and Deduplication

HTM uses a many-to-many relationship between robots and nodes, enabling both content deduplication and attribution tracking.

### Attribution Schema

```sql
-- Nodes are content-deduplicated via SHA-256 hash
CREATE TABLE nodes (
  id BIGSERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  content_hash VARCHAR(64) UNIQUE,  -- SHA-256 for deduplication
  ...
);

-- Robot-node relationships tracked in join table
CREATE TABLE robot_nodes (
  id BIGSERIAL PRIMARY KEY,
  robot_id BIGINT NOT NULL REFERENCES robots(id),
  node_id BIGINT NOT NULL REFERENCES nodes(id),
  first_remembered_at TIMESTAMPTZ,  -- When robot first saw this content
  last_remembered_at TIMESTAMPTZ,   -- When robot last tried to remember
  remember_count INTEGER DEFAULT 1  -- How many times robot remembered this
);

-- Indexes for efficient queries
CREATE UNIQUE INDEX idx_robot_nodes_unique ON robot_nodes(robot_id, node_id);
CREATE INDEX idx_robot_nodes_robot_id ON robot_nodes(robot_id);
CREATE INDEX idx_robot_nodes_node_id ON robot_nodes(node_id);
```

### Content Deduplication

When a robot remembers content:

```ruby
def remember(content, tags: [])
  # 1. Compute SHA-256 hash of content
  content_hash = Digest::SHA256.hexdigest(content)

  # 2. Check if node with same hash exists
  existing_node = HTM::Models::Node.find_by(content_hash: content_hash)

  if existing_node
    # 3a. Link robot to existing node (or update remember_count)
    link_robot_to_node(robot_id: @robot_id, node: existing_node)
    return existing_node.id
  else
    # 3b. Create new node and link robot
    node = create_new_node(content, content_hash)
    link_robot_to_node(robot_id: @robot_id, node: node)
    return node.id
  end
end
```

### Attribution Queries

#### Which robots remember this content?

```ruby
# Find all robots that have remembered a specific node
def robots_for_node(node_id)
  HTM::Models::RobotNode
    .where(node_id: node_id)
    .includes(:robot)
    .map do |rn|
      {
        robot_name: rn.robot.name,
        first_remembered_at: rn.first_remembered_at,
        remember_count: rn.remember_count
      }
    end
end

# Example
robots_for_node(123)
# => [
#   { robot_name: "Code Helper", first_remembered_at: "2025-01-15", remember_count: 3 },
#   { robot_name: "Research Bot", first_remembered_at: "2025-01-16", remember_count: 1 }
# ]
```

#### Nodes shared by multiple robots

```ruby
# Find content that multiple robots have remembered
def shared_memories(min_robots: 2, limit: 50)
  HTM::Models::Node
    .joins(:robot_nodes)
    .group('nodes.id')
    .having('COUNT(DISTINCT robot_nodes.robot_id) >= ?', min_robots)
    .order('COUNT(DISTINCT robot_nodes.robot_id) DESC')
    .limit(limit)
    .map(&:attributes)
end

# Example
shared_memories(min_robots: 2)
# => Nodes that 2+ robots have remembered
```

#### Robot activity

```sql
-- Which robots have been active?
SELECT id, name, last_active
FROM robots
ORDER BY last_active DESC;

-- Which robot has remembered the most nodes?
SELECT r.name, COUNT(rn.node_id) as memory_count
FROM robots r
LEFT JOIN robot_nodes rn ON rn.robot_id = r.id
GROUP BY r.id, r.name
ORDER BY memory_count DESC;

-- What has a specific robot remembered recently?
SELECT n.content, rn.first_remembered_at, rn.remember_count
FROM robot_nodes rn
JOIN nodes n ON n.id = rn.node_id
WHERE rn.robot_id = 1
ORDER BY rn.last_remembered_at DESC
LIMIT 50;
```

## Cross-Robot Knowledge Sharing

The power of the hive mind lies in automatic knowledge sharing across robots.

### Use Case 1: Cross-Session Context

A user works with Robot A in one session, then Robot B in another session. Robot B automatically knows what Robot A learned.

```ruby
# Session 1 - Robot A (Code Helper)
htm_a = HTM.new(robot_name: "Code Helper A")
htm_a.remember("User prefers debug_me over puts for debugging")
# Stored in long-term memory, linked to robot A via robot_nodes

# === User logs out, logs in next day ===

# Session 2 - Robot B (different process, same or different machine)
htm_b = HTM.new(robot_name: "Code Helper B")

# Robot B recalls preferences
memories = htm_b.recall("debugging preference", timeframe: "last week")
# => Finds preference from Robot A!

# Robot B knows user preference without being told
```

### Use Case 2: Collaborative Development with Deduplication

Different robots working on the same content automatically share nodes.

```ruby
# Robot A (Architecture discussion)
htm_a = HTM.new(robot_name: "Architect Bot")
node_id = htm_a.remember(
  "We decided to use PostgreSQL with pgvector for HTM storage",
  tags: ["architecture", "database"]
)
# => node_id: 123 (new node created)

# Robot B learns the same fact independently
htm_b = HTM.new(robot_name: "Code Bot")
node_id = htm_b.remember(
  "We decided to use PostgreSQL with pgvector for HTM storage"
)
# => node_id: 123 (same node! Content hash matched)

# Both robots now linked to the same node
# Robot A: remember_count = 1
# Robot B: remember_count = 1

# Check shared ownership
rns = HTM::Models::RobotNode.where(node_id: 123)
rns.each { |rn| puts "Robot #{rn.robot_id}: #{rn.remember_count} times" }
# => Robot 1: 1 times
# => Robot 2: 1 times
```

### Use Case 3: Finding Shared Knowledge

Analyze what content is shared across robots:

```ruby
# Find nodes remembered by multiple robots
shared_nodes = HTM::Models::Node
  .joins(:robot_nodes)
  .group('nodes.id')
  .having('COUNT(DISTINCT robot_nodes.robot_id) >= 2')
  .select('nodes.*, COUNT(DISTINCT robot_nodes.robot_id) as robot_count')

shared_nodes.each do |node|
  puts "Node #{node.id}: #{node.robot_count} robots"
  puts "  Content: #{node.content[0..80]}..."

  # Show which robots
  node.robot_nodes.each do |rn|
    puts "  - Robot #{rn.robot.name}: remembered #{rn.remember_count}x"
  end
end
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

### Example 1: Persistent Robot with Named Identity

```ruby
# Initialize with persistent name
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000
)

# Add memories (linked to this robot via robot_nodes)
htm.remember("Use PostgreSQL for ACID guarantees and pgvector support")

# Robot ID is stored in database, robot_name is human-readable
puts "Robot ID: #{htm.robot_id}"
puts "Robot name: #{htm.robot_name}"
```

### Example 2: Multi-Robot Collaboration with Deduplication

```ruby
# Robot A: Architecture discussion
robot_a = HTM.new(robot_name: "Architect")
node_id = robot_a.remember(
  "PostgreSQL chosen for ACID guarantees and pgvector support",
  tags: ["architecture:database", "decision"]
)

# Robot B: Implementation (different process, accesses same LTM)
robot_b = HTM.new(robot_name: "Coder")
decisions = robot_b.recall("database decision", timeframe: "today")
# => Finds Robot A's decision automatically

# If Robot B remembers the same content, it links to existing node
same_node_id = robot_b.remember(
  "PostgreSQL chosen for ACID guarantees and pgvector support"
)
# => same_node_id == node_id (deduplication!)

robot_b.remember(
  "Implemented Database class with connection pooling",
  tags: ["implementation:database", "code:ruby"]
)
```

### Example 3: Robot Activity Dashboard

```ruby
# Get all robots and their activity
stats = []

HTM::Models::Robot.order(last_active: :desc).each do |robot|
  # Count memories via robot_nodes
  memory_count = robot.robot_nodes.count

  # Get remember statistics
  remember_stats = robot.robot_nodes.group(:node_id).count.size  # Unique nodes
  total_remembers = robot.robot_nodes.sum(:remember_count)       # Total remembers

  stats << {
    name: robot.name,
    id: robot.id,
    last_active: robot.last_active,
    unique_memories: memory_count,
    total_remembers: total_remembers
  }
end

# Display dashboard
puts "=" * 60
puts "Robot Activity Dashboard"
puts "=" * 60
stats.each do |data|
  puts "#{data[:name]} (ID: #{data[:id]})"
  puts "  Last active: #{data[:last_active]}"
  puts "  Unique memories: #{data[:unique_memories]}"
  puts "  Total remembers: #{data[:total_remembers]}"
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
