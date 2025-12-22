# ADR-008: Robot Identification System

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM uses a **dual-identifier system** with mandatory unique `robot_id` (UUID) and optional human-readable `robot_name`. Both are auto-generated if not provided, with automatic robot registration and activity tracking in the database.

**Why**: Unique robot identification enables memory attribution, cross-robot analytics, debugging, and future features like permissions and groups while maintaining developer-friendly names.

**Impact**: Globally unique identity with human-readable names and automatic management, at the cost of dual identifiers and manual persistence requirements for stable identities.

---

## Context

In the HTM hive mind architecture (ADR-004), multiple robots share a global memory database. Each robot needs a unique identity to:

- Attribute memories to their creator
- Track robot activity over time
- Enable queries like "which robot said this?"
- Debug conversation attribution
- Support future features (privacy, analytics, collaboration)

### Identity Requirements

- **Uniqueness**: Must be globally unique (no collisions)
- **Persistence**: Should remain stable across sessions
- **Human-readable**: Developers need to identify robots easily
- **Automation**: Should auto-generate if not provided
- **Registration**: Track all robots using the system

### Alternative Identification Schemes

1. **Auto-generated UUID only**: Unique but not human-readable
2. **User-provided name only**: Readable but collision-prone
3. **UUID + optional name**: Unique ID with optional readable name
4. **Sequential ID**: Simple but requires coordination
5. **Hostname + PID**: Automatic but not persistent across restarts

---

## Decision

We will use a **dual-identifier system**: mandatory unique `robot_id` (UUID) + optional human-readable `robot_name`, with automatic generation if not provided.

### Robot Identification Components

**1. Robot ID (`robot_id`)**

- **Type**: UUID v4 (RFC 4122)
- **Format**: `"f47ac10b-58cc-4372-a567-0e02b2c3d479"`
- **Generation**: `SecureRandom.uuid` if not provided
- **Persistence**: User-provided for stability, or auto-generated per session
- **Usage**: Primary key, foreign key references, attribution

**2. Robot Name (`robot_name`)**

- **Type**: String (optional, human-readable)
- **Format**: Any descriptive string (e.g., "Code Helper", "Research Assistant")
- **Generation**: `"robot_#{robot_id[0..7]}"` if not provided
- **Persistence**: Stored in database, updatable
- **Usage**: Display, debugging, user interfaces

---

## Rationale

### Why UUID + Name?

**UUID provides guarantees**:

- Globally unique (collision probability: ~10^-36)
- No coordination required (decentralized generation)
- Cryptographically random (unpredictable)
- Standard format (RFC 4122, widely supported)

**Name provides usability**:

- Human-readable in logs and debugging
- Meaningful for user-facing features
- Easy to remember ("Code Helper" vs UUID)
- Updatable without breaking references

**Combination is best**:

- UUID for database integrity
- Name for developer experience
- Auto-generation for convenience
- User control for persistence

### Why Auto-Generate?

**Convenience**:

- Users don't need to manage UUIDs manually
- Works out-of-box with no configuration
- Still allows explicit robot_id for persistence

**Session vs Persistent Identity**:

- **Session identity**: Auto-generated UUID, ephemeral robot
- **Persistent identity**: User-provided UUID, stable across restarts

```ruby
# Ephemeral robot (new UUID every session)
htm = HTM.new(robot_name: "Temp Helper")

# Persistent robot (same UUID across sessions)
ROBOT_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
htm = HTM.new(robot_id: ROBOT_ID, robot_name: "Persistent Helper")
```

### Why Register Robots?

**Activity tracking**:

- Know which robots are active
- Monitor robot usage patterns
- Identify inactive robots for cleanup

**Metadata extensibility**:

- Future: Robot roles, permissions, preferences
- Future: Robot groups/teams
- Future: Configuration per robot

**Debugging**:

- "Which robot created this memory?"
- "What has this robot been doing?"
- "When was this robot last active?"

---

## Implementation Details

### Robot Registry

```sql
CREATE TABLE robots (
  id TEXT PRIMARY KEY,              -- robot_id (UUID)
  name TEXT,                         -- robot_name (human-readable)
  created_at TIMESTAMP DEFAULT NOW(),
  last_active TIMESTAMP DEFAULT NOW(),
  metadata JSONB                     -- future extensibility
);
```

### Robot Attribution

Every memory node stores `robot_id`:

```sql
CREATE TABLE nodes (
  id SERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  robot_id TEXT NOT NULL REFERENCES robots(id),  -- Attribution
  ...
);
```

### Initialization

```ruby
htm = HTM.new(
  robot_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479",  # optional, auto-generated
  robot_name: "Code Helper"                          # optional, descriptive
)

# Auto-generated example:
# robot_id: "3a7b2c4d-8e9f-4a5b-9c8d-7e6f5a4b3c2d"
# robot_name: "robot_3a7b2c4d"
```

### Registration Logic

**Upsert semantics**:

```sql
INSERT INTO robots (id, name)
VALUES ($1, $2)
ON CONFLICT (id) DO UPDATE
SET name = $2, last_active = CURRENT_TIMESTAMP
```

- Automatic on first HTM initialization
- Updates name and last_active if robot_id exists
- Activity tracking: `last_active` updated on every operation

---

## Consequences

### Positive

- Uniqueness guaranteed: UUID collision-proof
- Human-readable: Names easy to identify in logs
- Auto-generation: Works without manual configuration
- Persistence option: User can provide stable robot_id
- Attribution tracking: Every memory linked to creator
- Activity monitoring: Track robot usage over time
- Future-proof: Metadata field for extensibility
- Standard format: UUID is widely recognized

### Negative

- Dual identifiers: Two fields instead of one (complexity)
- Name collisions: Names not unique (only IDs are)
- Manual persistence: User must manage robot_id for stability
- No automatic migration: Robot ID changes break historical attribution
- UUID verbosity: UUIDs are long (36 characters)

### Neutral

- Session vs persistent: User chooses ephemeral or stable identity
- Name mutability: Names can be updated, IDs cannot
- Registry cleanup: Inactive robots accumulate (manual cleanup needed)

---

## Use Cases

### Use Case 1: Ephemeral Robot (Session Identity)

```ruby
# New UUID generated every time
htm = HTM.new(robot_name: "Quick Helper")

# robot_id: auto-generated UUID
# robot_name: "Quick Helper"

# Next session: different robot_id, same name
# Memories attributed to different robot each time
```

### Use Case 2: Persistent Robot (Stable Identity)

```ruby
# Store robot_id in config or environment
ROBOT_ID = ENV['ROBOT_ID'] || "f47ac10b-58cc-4372-a567-0e02b2c3d479"

htm = HTM.new(
  robot_id: ROBOT_ID,
  robot_name: "Code Helper"
)

# Same robot_id across sessions
# Memories consistently attributed to this robot
```

### Use Case 3: Multiple Robots in Same Process

```ruby
# Research assistant
research_bot = HTM.new(
  robot_id: "research-001",
  robot_name: "Research Assistant"
)

# Code helper
code_bot = HTM.new(
  robot_id: "code-001",
  robot_name: "Code Helper"
)

# Each robot has own working memory
# Both share same long-term memory database
# Memories attributed to respective robots
```

### Use Case 4: Robot Activity Analysis

```sql
-- Which robots have been active?
SELECT id, name, last_active
FROM robots
ORDER BY last_active DESC;

-- Which robot contributed most memories?
SELECT robot_id, COUNT(*) as memory_count
FROM nodes
GROUP BY robot_id
ORDER BY memory_count DESC;

-- What has "Code Helper" been doing?
SELECT operation, created_at, details
FROM operations_log
WHERE robot_id = (SELECT id FROM robots WHERE name = 'Code Helper')
ORDER BY created_at DESC
LIMIT 50;
```

### Use Case 5: Conversation Attribution

```ruby
# Which robot discussed PostgreSQL?
breakdown = htm.which_robot_said("PostgreSQL")
# => { "f47ac10b-..." => 15, "3a7b2c4d-..." => 8 }

# Get robot names
robot_names = breakdown.keys.map do |robot_id|
  db.query("SELECT name FROM robots WHERE id = $1", [robot_id]).first
end
```

---

## Robot Identity Lifecycle

### 1. Creation

```ruby
htm = HTM.new(robot_id: uuid, robot_name: name)
```

### 2. Registration

```sql
INSERT INTO robots (id, name, created_at, last_active)
VALUES (uuid, name, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET name = name, last_active = NOW()
```

### 3. Activity Tracking

```ruby
# On every HTM operation (add_node, recall, forget, retrieve)
@long_term_memory.update_robot_activity(@robot_id)
```

```sql
UPDATE robots
SET last_active = CURRENT_TIMESTAMP
WHERE id = robot_id
```

### 4. Attribution

```ruby
# Every node stores robot_id
node_id = @long_term_memory.add(
  key: key,
  value: value,
  robot_id: @robot_id,  # Attribution
  ...
)
```

### 5. Querying

```sql
-- Find memories by robot
SELECT * FROM nodes WHERE robot_id = 'f47ac10b-...'

-- Find robot by name
SELECT * FROM robots WHERE name = 'Code Helper'
```

### 6. Cleanup (Manual)

```sql
-- Find inactive robots
SELECT * FROM robots WHERE last_active < NOW() - INTERVAL '30 days';

-- Delete robot and all its memories (use with caution!)
DELETE FROM nodes WHERE robot_id = 'f47ac10b-...';
DELETE FROM robots WHERE id = 'f47ac10b-...';
```

---

## Performance Characteristics

### UUID Generation

- **Time**: < 1ms (SecureRandom.uuid)
- **Collision probability**: ~10^-36 for v4 UUID
- **Entropy**: 122 random bits

### Robot Registration

- **Upsert query**: < 5ms
- **Index**: Primary key on `robots.id`
- **Frequency**: Once per HTM initialization

### Activity Tracking

- **Update query**: < 2ms
- **Frequency**: Every HTM operation
- **Index**: Primary key on `robots.id`

### Attribution Queries

- **Foreign key join**: O(log n) with index
- **Index**: `nodes.robot_id` indexed as foreign key

---

## Design Decisions

### Decision: UUID v4 (Random) Instead of UUID v1 (Timestamp)

**Rationale**:

- No MAC address leakage (privacy)
- Cryptographically random (security)
- No clock synchronization needed

**Alternative**: UUID v1 (timestamp-based)

**Rejected**: MAC address exposure, clock sync issues

### Decision: Optional robot_id, Mandatory robot_name

**Rationale**: Auto-generate both if not provided, allow user override

**Alternative**: Require user to provide robot_id

**Rejected**: Too much friction, poor DX

### Decision: Auto-Generated Name Format

**Rationale**: `"robot_#{uuid[0..7]}"` provides:

- Uniqueness (first 8 chars usually unique)
- Traceability (prefix of robot_id)
- Consistency (predictable format)

**Alternative**: Random adjective + noun ("Happy Robot")

**Rejected**: Harder to correlate with robot_id

### Decision: Upsert Semantics for Registration

**Rationale**: Allows robot_name updates, prevents duplicate registration errors

**Alternative**: Strict insert-only (error on duplicate)

**Rejected**: Prevents name updates, complicates initialization

### Decision: JSONB Metadata Field

**Rationale**: Future extensibility without schema migrations

**Alternative**: Add columns as needed

**Deferred**: JSONB is flexible, add columns for indexed fields later

---

## Risks and Mitigations

### Risk: Robot ID Changes Break Attribution

!!! danger "Risk"
    User changes robot_id, breaks historical attribution

**Likelihood**: Low (user must explicitly change)

**Impact**: High (attribution lost)

**Mitigation**:

- Document robot_id persistence clearly
- Recommend storing robot_id in config
- Consider robot_id migration tool (future)

### Risk: Name Collisions

!!! info "Risk"
    Multiple robots with same name

**Likelihood**: Medium (names not enforced unique)

**Impact**: Low (IDs are unique, names just for display)

**Mitigation**:

- Document that names are not unique
- Use robot_id for queries, name for display
- Consider unique constraint on name (future)

### Risk: Robot Registry Growth

!!! warning "Risk"
    Inactive robots accumulate indefinitely

**Likelihood**: High (no automatic cleanup)

**Impact**: Low (storage, query slowdown)

**Mitigation**:

- Document cleanup procedures
- Provide cleanup utilities (future)
- Monitor robot registry size

### Risk: UUID Verbosity

!!! info "Risk"
    UUIDs are long (36 chars) in logs

**Likelihood**: High (by design)

**Impact**: Low (readability in logs)

**Mitigation**:

- Use robot_name for logging
- Truncate UUID for display: `robot_id[0..7]`
- Full UUID available for debugging

---

## Future Enhancements

### Robot Groups/Teams

```ruby
# Assign robots to teams
robot_team = db.exec("INSERT INTO robot_teams (robot_id, team_name) VALUES ($1, $2)",
                     [robot_id, "coding-team"])

# Query by team
memories = htm.recall(robot_team: "coding-team", topic: "APIs")
```

### Robot Permissions

```ruby
# Role-based access control
robot_role = db.exec("INSERT INTO robot_roles (robot_id, role) VALUES ($1, $2)",
                     [robot_id, "admin"])

# Restrict operations by role
htm.forget(key, confirm: :confirmed)  # Requires admin role
```

### Robot Configuration

```ruby
# Per-robot settings
htm = HTM.new(
  robot_id: uuid,
  robot_name: name,
  robot_config: {
    embedding_model: "custom-model",
    working_memory_size: 256_000,
    preferences: { language: "en" }
  }
)
```

### Robot Migration Tool

```ruby
# Migrate memories from old robot_id to new one
HTM::Migration.migrate_robot(
  from: "old-robot-id",
  to: "new-robot-id"
)

# Updates all nodes.robot_id references
# Merges robot registry entries
```

### Short Robot IDs

```ruby
# Generate shorter IDs (like GitHub: 7 chars)
short_id = SecureRandom.hex(4)  # "3a7b2c4d"

htm = HTM.new(
  robot_id: short_id,
  robot_name: "Helper"
)

# Trade-off: Lower collision resistance, better readability
```

---

## Alternatives Comparison

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **UUID + Name** | **Unique + readable** | **Dual identifiers** | **ACCEPTED** |
| UUID Only | Simple, guaranteed unique | Not human-readable | Rejected |
| Name Only | Simple, readable | Collision-prone | Rejected |
| Sequential IDs | Short, sortable | Requires coordination | Rejected |
| Hostname + PID | Automatic | Not persistent | Rejected |
| ULID | Sortable, shorter | Less standard | Deferred |

---

## References

- [RFC 4122: UUID Specification](https://tools.ietf.org/html/rfc4122)
- [UUID v4 (Random)](https://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_(random))
- [ULID Specification](https://github.com/ulid/spec)
- [Robot Registry Pattern](https://martinfowler.com/eaaCatalog/registry.html)
- [ADR-004: Hive Mind Architecture](004-hive-mind.md)
- [Multi-Robot Guide](../../robots/multi-robot.md)

---

## Review Notes

**Systems Architect**: UUID + name is the right balance. Consider ULID for future versions.

**Database Architect**: Foreign key on robot_id is correct. Index on `nodes.robot_id` for attribution queries.

**Ruby Expert**: SecureRandom.uuid is standard. Consider `robot_id: SecureRandom.uuid` as default parameter.

**Security Specialist**: UUID v4 is cryptographically secure. No MAC address leakage.

**Domain Expert**: Auto-generation + manual override gives flexibility. Document persistence clearly.
