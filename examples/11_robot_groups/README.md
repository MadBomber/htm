# Robot Groups - Multi-Robot Coordination with Shared Working Memory

This example demonstrates high-availability patterns for coordinating multiple HTM robots with shared working memory, automatic failover, and real-time synchronization.

There are two scenarios demonstrated.  1) multiple robots in their processes.  These processes could be on the same computer are not.  The only requirement is that all robot processes have access to the same HTM database.

The second scenario is all robots are running within the same process.

## Overview

Robot Groups enable multiple AI agents (robots) to share context and collaborate on tasks. Key capabilities:

- **Shared Working Memory**: Multiple robots access the same context simultaneously
- **Active/Passive Roles**: Active robots handle requests; passive robots maintain warm standby
- **Instant Failover**: When an active robot fails, a passive robot takes over with full context
- **Real-time Sync**: PostgreSQL LISTEN/NOTIFY propagates changes across all robots instantly
- **Dynamic Scaling**: Add or remove robots without service interruption

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Robot Group                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Robot A   │  │   Robot B   │  │   Robot C   │         │
│  │  (active)   │  │  (active)   │  │  (passive)  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                  │
│              ┌───────────▼───────────┐                     │
│              │  Shared Working Memory │                     │
│              │   (PostgreSQL + NOTIFY)│                     │
│              └───────────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Database Setup**
   ```bash
   rake examples:setup
   ```

2. **Ollama Models** (for embeddings and tag extraction)
   ```bash
   ollama pull nomic-embed-text
   ollama pull gemma3
   ```

3. **Ruby Dependencies**
   ```bash
   bundle install
   ```

## Available Scripts

### same_process.rb

Demonstrates robot groups within a **single Ruby process**. Ideal for understanding the concepts without process management complexity.

```bash
ruby examples/11_robot_groups/same_process.rb
```

**Scenarios demonstrated:**

1. **Create a Robot Group** - Initialize with primary (active) and standby (passive) robots
2. **Add Shared Memories** - Primary robot stores information accessible to all
3. **Verify Synchronization** - Confirm all robots see the same context
4. **Simulate Failover** - Primary "fails", standby promotes to active
5. **Verify Context Preservation** - Standby has full context after failover
6. **Dynamic Scaling** - Add a second active robot on-the-fly
7. **Collaborative Memory** - Multiple robots contribute to shared context
8. **Real-time Sync** - PostgreSQL LISTEN/NOTIFY propagates changes instantly

**Example output:**
```
1. Configuring HTM...
✓ HTM configured

2. Creating robot group with primary + standby...
✓ Group created: customer-support-ha
  Active:  support-primary
  Passive: support-standby

3. Adding memories to shared working memory...
  ✓ Remembered customer preference
  ✓ Remembered open ticket
  ✓ Remembered customer status

4. Verifying working memory synchronization...
  Working memory nodes: 3
  Token utilization: 12.5%
  In sync: ✓ Yes

5. Simulating failover scenario...
  ⚠ Primary robot 'support-primary' has stopped responding!
  Active robots now: support-standby
  Passive robots now: (none)

6. Verifying standby has full context after failover...
  ✓ Standby recalled 3 memories about 'customer'
```

### multi_process.rb

Demonstrates robot groups across **separate Ruby processes**. This is closer to production deployments where each robot runs independently.

```bash
ruby examples/11_robot_groups/multi_process.rb
```

**Scenarios demonstrated:**

1. **Start Robot Processes** - Spawn 3 independent worker processes
2. **Cross-Process Memory Sharing** - One robot adds memories, others receive via NOTIFY
3. **Collaborative Memory** - Multiple processes contribute to shared context
4. **Simulated Failover** - Kill a process, verify others retain context
5. **Dynamic Scaling** - Add a new robot process to the group

**Example output:**
```
╔══════════════════════════════════════════════════════════════╗
║     HTM Multi-Process Robot Group Demo                       ║
║     Real-time Sync via PostgreSQL LISTEN/NOTIFY              ║
╚══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SCENARIO 1: Starting Robot Processes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ robot-alpha (PID 12345)
  ✓ robot-beta (PID 12346)
  ✓ robot-gamma (PID 12347)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SCENARIO 4: Simulated Failover
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Killing robot-alpha...
  ⚠ robot-alpha terminated

  Remaining robots retain context:
    robot-beta: 3 nodes, recalls 2
    robot-gamma: 3 nodes, recalls 2

  ✓ Failover successful
```

### robot_worker.rb

A standalone worker process used by `multi_process.rb`. You typically don't run this directly.

**Communication protocol** (JSON over stdin/stdout):

| Command | Request | Response |
|---------|---------|----------|
| ping | `{"cmd": "ping"}` | `{"status": "ok", "message": "pong"}` |
| remember | `{"cmd": "remember", "content": "..."}` | `{"status": "ok", "node_id": 123}` |
| recall | `{"cmd": "recall", "query": "...", "limit": 5}` | `{"status": "ok", "count": 3}` |
| status | `{"cmd": "status"}` | `{"status": "ok", "working_memory_nodes": 5, ...}` |
| shutdown | `{"cmd": "shutdown"}` | `{"status": "ok", "message": "bye"}` |

## Key Concepts

### Active vs Passive Robots

| Role | Behavior |
|------|----------|
| **Active** | Handles requests, adds memories, participates in conversations |
| **Passive** | Mirrors active robot's context silently, ready for instant takeover |

### Failover Process

1. Active robot becomes unresponsive
2. `group.failover!` promotes first passive robot to active
3. Promoted robot has full context (warm standby)
4. Service continues without context loss

### Real-time Synchronization

PostgreSQL LISTEN/NOTIFY enables sub-second sync:

```
Robot A adds memory → PostgreSQL NOTIFY → Robot B receives → Updates local cache
```

Events propagated:
- `:added` - New node added to working memory
- `:evicted` - Node removed due to token limits
- `:cleared` - Working memory cleared entirely

### Token Budget Management

Each group has a `max_tokens` limit. When exceeded:
1. Oldest/least-accessed nodes are evicted
2. Eviction notifications sent to all robots
3. All robots stay within budget

## Use Cases

### Customer Support

Multiple support agents share customer context:
```ruby
group = HTM::RobotGroup.new(
  name: 'support-team',
  active: ['agent-1', 'agent-2', 'agent-3'],
  max_tokens: 16000
)

# Any agent can add context
group.remember('Customer prefers email', originator: 'agent-1')

# All agents see the context
group.recall('customer preferences')  # Returns same results for all
```

### High Availability

Primary + standby for critical systems:
```ruby
group = HTM::RobotGroup.new(
  name: 'production-bot',
  active: ['primary'],
  passive: ['standby-1', 'standby-2'],
  max_tokens: 32000
)

# If primary fails
group.failover!  # standby-1 becomes active instantly
```

### Load Balancing

Multiple active robots share the load:
```ruby
group = HTM::RobotGroup.new(
  name: 'api-handlers',
  active: ['handler-1', 'handler-2', 'handler-3', 'handler-4'],
  max_tokens: 64000
)

# Any handler can process requests with shared context
```

## API Reference

### HTM::RobotGroup

```ruby
# Create a group
group = HTM::RobotGroup.new(
  name: 'my-group',
  active: ['robot-1'],
  passive: ['robot-2'],
  max_tokens: 8000
)

# Add memories
group.remember(content, originator: 'robot-1')

# Search memories
group.recall(query, limit: 10, strategy: :hybrid)

# Check status
group.status
# => { name:, active:, passive:, working_memory_nodes:, token_utilization:, in_sync: }

# Failover
group.failover!

# Add/remove robots
group.add_active('new-robot')
group.add_passive('standby-robot')

# Sync operations
group.sync_all
group.sync_robot('robot-name')

# Cleanup
group.clear_working_memory
group.shutdown
```

### HTM::WorkingMemoryChannel

```ruby
# Create channel for cross-process sync
channel = HTM::WorkingMemoryChannel.new(group_name, db_config)

# Register callback for changes
channel.on_change do |event, node_id, origin_robot_id|
  case event
  when :added then # handle new node
  when :evicted then # handle removal
  when :cleared then # handle clear
  end
end

# Start/stop listening
channel.start_listening
channel.stop_listening

# Send notifications
channel.notify(:added, node_id: 123, robot_id: 456)
```

## Troubleshooting

### Robots not receiving notifications

1. Verify PostgreSQL is running with LISTEN/NOTIFY support
2. Check that all robots use the same `group_name`
3. Ensure `channel.start_listening` was called

### High memory usage

1. Reduce `max_tokens` for the group
2. Call `group.clear_working_memory` periodically
3. Use more aggressive eviction strategies

### Slow synchronization

1. Check PostgreSQL connection latency
2. Reduce notification frequency for bulk operations
3. Consider batching memory additions

## Environment Variables

| Variable | Description |
|----------|-------------|
| `HTM_DATABASE__URL` | PostgreSQL connection URL (required) |
| `HTM_ENV` | Environment name (set to `examples` by helper) |
