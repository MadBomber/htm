# ADR-004: Multi-Robot Shared Memory (Hive Mind)

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

## Context

In LLM-based applications, users often interact with multiple "robots" (AI agents) over time. These robots may serve different purposes (coding assistant, research assistant, chat companion) or represent different instances of the same application across sessions.

Challenges with isolated memory:

- Each robot has independent context
- User repeats information across robots
- No cross-robot learning
- Conversations fragmented across agents
- Lost context when switching robots

Alternative approaches:

1. **Isolated memory**: Each robot has completely separate memory
2. **Shared memory (hive mind)**: All robots access global memory pool
3. **Hierarchical memory**: Per-robot memory + shared global memory
4. **Explicit sharing**: User chooses what to share across robots

## Decision

We will implement a **shared memory (hive mind) architecture** where all robots access a single global memory database, with attribution tracking to identify which robot contributed each memory.

## Rationale

### Why Shared Memory?

**Context continuity**:

- User doesn't repeat themselves across robots
- "You" refers to the user consistently
- Preferences persist across sessions
- Conversation history accessible to all

**Cross-robot learning**:

- Knowledge gained by one robot benefits all
- Architectural decisions visible to coding assistants
- Research findings available to writers
- Bug fixes remembered globally

**Simplified data model**:

- Single source of truth
- No synchronization complexity
- Unified search across all conversations
- Consistent robot registry

**User experience**:

- Seamless switching between robots
- Coherent memory across interactions
- No need to "catch up" new robots
- Transparent collaboration

### Attribution Tracking

Every node stores `robot_id`:
```sql
CREATE TABLE nodes (
  ...
  robot_id TEXT NOT NULL,
  ...
);
```

Benefits:

- Track which robot said what
- Debug conversation attribution
- Analyze robot behavior patterns
- Support privacy controls (future)

### Hive Mind Queries

```ruby
# Which robot discussed this topic?
breakdown = htm.which_robot_said("PostgreSQL")
# => { "robot-123" => 15, "robot-456" => 8 }

# Get chronological conversation
timeline = htm.conversation_timeline("HTM design", limit: 50)
# => [{ timestamp: ..., robot: "...", content: "..." }, ...]
```

### Robot Registry

```sql
CREATE TABLE robots (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP,
  last_active TIMESTAMP,
  metadata JSONB
);
```

Tracks all robots using the system:
- Registration on first use
- Activity timestamps
- Custom metadata (configuration, purpose, etc.)

## Implementation Details

### Robot Initialization
```ruby
htm = HTM.new(
  robot_name: "Code Helper",
  robot_id: "robot-123"  # optional, auto-generated if not provided
)

# Registers robot in database
@long_term_memory.register_robot(@robot_id, @robot_name)
```

### Adding Memories with Attribution
```ruby
def add_node(key, value, ...)
  node_id = @long_term_memory.add(
    key: key,
    value: value,
    robot_id: @robot_id,  # Attribution
    ...
  )
end
```

### Querying by Robot
```ruby
# All nodes by specific robot
SELECT * FROM nodes WHERE robot_id = 'robot-123';

# Breakdown by robot
SELECT robot_id, COUNT(*)
FROM nodes
WHERE value ILIKE '%PostgreSQL%'
GROUP BY robot_id;
```

### Working Memory: Per-Robot

**Important distinction**: While long-term memory is shared globally, working memory is per-robot instance (per-process):

```ruby
class HTM
  def initialize(...)
    @working_memory = WorkingMemory.new(max_tokens: 128_000)  # Per-instance
    @long_term_memory = LongTermMemory.new(db_config)         # Shared database
  end
end
```

Each robot has:
- **Own working memory**: Token-limited, process-local
- **Shared long-term memory**: Durable, global PostgreSQL

This design provides:

- Fast local access (working memory)
- Global knowledge sharing (long-term memory)
- Process isolation (no cross-process RAM access needed)

## Consequences

### Positive

✅ **Seamless context**: User never repeats information
✅ **Cross-robot learning**: Knowledge compounds across agents
✅ **Conversation attribution**: Clear ownership of memories
✅ **Unified search**: Find information regardless of which robot stored it
✅ **Simplified architecture**: Single database, no synchronization
✅ **Activity tracking**: Monitor robot usage patterns
✅ **Debugging**: Trace memories back to source robot

### Negative

❌ **Privacy complexity**: All robots see all data (no isolation)
❌ **Namespace conflicts**: Key collisions across robots (mitigated by UUID keys)
❌ **Context pollution**: Irrelevant memories from other robots
❌ **Testing complexity**: Shared state harder to isolate in tests
❌ **Multi-tenancy**: No built-in tenant isolation (future requirement)

### Neutral

➡️ **Global namespace**: Requires coordination for key naming
➡️ **Robot identity**: User must provide meaningful robot names
➡️ **Memory attribution**: "Who said this?" vs. "What was said?"

## Design Decisions

### Decision: Global by Default
**Rationale**: Simplicity and user experience trump isolation. Users can implement privacy layers on top if needed.

**Alternative**: Per-robot namespaces with opt-in sharing
**Rejected**: Adds complexity, defeats purpose of hive mind

### Decision: Robot ID Required
**Rationale**: Essential for attribution and debugging

**Alternative**: Optional robot_id
**Rejected**: Lose critical context and debugging capability

### Decision: Working Memory Per-Process
**Rationale**: Avoid distributed state synchronization complexity

**Alternative**: Shared working memory (Redis)
**Deferred**: Consider for multi-process/multi-host scenarios

## Risks and Mitigations

### Risk: Context Pollution

- **Risk**: Robot sees irrelevant memories from other robots
- **Likelihood**: Medium (depends on use patterns)
- **Impact**: Medium (degraded relevance)
- **Mitigation**:
  - Importance scoring helps filter
  - Robot-specific recall filters (future)
  - Category/tag-based filtering
  - Smart context assembly

### Risk: Privacy Violations

- **Risk**: Sensitive data accessible to all robots
- **Likelihood**: Low (single-user scenario)
- **Impact**: High (if multi-user)
- **Mitigation**:
  - Document single-user assumption
  - Add row-level security for multi-tenant (future)
  - Encryption for sensitive data (future)

### Risk: Key Collisions

- **Risk**: Different robots use same key for different data
- **Likelihood**: Low (UUID recommendations)
- **Impact**: Medium (data corruption)
- **Mitigation**:
  - Recommend UUIDs or prefixed keys
  - Unique constraint on key column
  - Error handling for collisions

### Risk: Unbounded Growth

- **Risk**: Memory grows indefinitely with multiple robots
- **Likelihood**: High (no automatic cleanup)
- **Impact**: Medium (storage costs, query slowdown)
- **Mitigation**:
  - Retention policies (future)
  - Archival strategies
  - Importance-based pruning (future)

## Use Cases

### Use Case 1: Cross-Session Context
```ruby
# Session 1 - Robot A
htm_a = HTM.new(robot_name: "Code Helper A")
htm_a.add_node("user_pref_001", "User prefers debug_me over puts",
               type: :preference)

# Session 2 - Robot B (different process, later time)
htm_b = HTM.new(robot_name: "Code Helper B")
memories = htm_b.recall(timeframe: "last week", topic: "debugging")
# => Finds preference from Robot A
```

### Use Case 2: Collaborative Development
```ruby
# Robot A (architecture discussion)
htm_a.add_node("decision_001",
               "We decided to use PostgreSQL for storage",
               type: :decision)

# Robot B (implementation)
htm_b.recall(timeframe: "today", topic: "database")
# => Finds architectural decision from Robot A
```

### Use Case 3: Activity Analysis
```ruby
# Which robot has been most active?
SELECT robot_id, COUNT(*) as contributions
FROM nodes
GROUP BY robot_id
ORDER BY contributions DESC;

# What did each robot contribute this week?
SELECT r.name, COUNT(n.id) as memories_added
FROM robots r
JOIN nodes n ON n.robot_id = r.id
WHERE n.created_at > NOW() - INTERVAL '7 days'
GROUP BY r.name;
```

## Future Enhancements

### Privacy Controls
```ruby
# Mark memories as private to specific robot
htm.add_node("private_key", "sensitive data",
             visibility: :private)  # Only accessible to this robot

# Or shared with specific robots
htm.add_node("shared_key", "team data",
             visibility: [:shared, robot_ids: ['robot-a', 'robot-b']])
```

### Robot Groups/Teams
```ruby
# Group robots by purpose
htm.add_robot_to_group("robot-123", "coding-team")
htm.add_robot_to_group("robot-456", "research-team")

# Query by group
memories = htm.recall(robot_group: "coding-team", topic: "APIs")
```

### Multi-Tenancy
```ruby
# Tenant isolation
htm = HTM.new(
  robot_name: "Helper",
  tenant_id: "user-abc123"  # Row-level security
)
```

## Alternatives Considered

### Isolated Memory (Per-Robot)
**Pros**: Complete isolation, no pollution, simpler privacy
**Cons**: User repeats information, no cross-robot learning
**Decision**: ❌ Rejected - defeats purpose of persistent memory

### Hierarchical Memory (Per-Robot + Global)
**Pros**: Best of both worlds, explicit sharing
**Cons**: Complex synchronization, unclear semantics
**Decision**: ❌ Rejected - too complex for v1

### Explicit Sharing
**Pros**: User controls what's shared
**Cons**: Friction, user burden, complexity
**Decision**: ❌ Rejected - simplicity and UX trump control

### Federated Memory (P2P)
**Pros**: Distributed, no central database
**Cons**: Sync complexity, consistency challenges
**Decision**: ❌ Rejected - unnecessary complexity

## References

- [Collective Intelligence](https://en.wikipedia.org/wiki/Collective_intelligence)
- [Hive Mind Concept](https://en.wikipedia.org/wiki/Hive_mind)
- [Multi-Agent Systems](https://en.wikipedia.org/wiki/Multi-agent_system)
- [HTM Robot Registry](../../lib/htm/long_term_memory.rb)

## Review Notes

**Systems Architect**: ✅ Simple and effective for single-user scenario. Plan for multi-tenancy early.

**Domain Expert**: ✅ Hive mind metaphor maps well to shared knowledge base. Consider robot personality/role in memory interpretation.

**Security Specialist**: ⚠️ Single-user assumption is critical. Document clearly and add tenant isolation before production multi-user deployment.

**AI Engineer**: ✅ Cross-robot context sharing improves LLM effectiveness. Monitor for context pollution in practice.

**Database Architect**: ✅ Robot_id indexing will scale well. Consider partitioning by robot_id if one robot dominates.
