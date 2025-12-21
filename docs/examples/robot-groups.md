# Robot Groups Example

This example demonstrates coordinating multiple robots with shared working memory and automatic failover capabilities.

**Source:** [`examples/robot_groups/same_process.rb`](https://github.com/madbomber/htm/blob/main/examples/robot_groups/same_process.rb)

## Overview

Robot Groups enable:

- **Shared Working Memory**: Multiple robots share the same in-memory context
- **Active/Passive Roles**: Active robots handle requests; passive robots maintain synchronized context
- **Instant Failover**: When an active robot fails, passive robots take over with full context
- **Real-time Sync**: PostgreSQL LISTEN/NOTIFY enables real-time synchronization
- **Dynamic Scaling**: Add or remove robots on demand

## Running the Example

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
ruby examples/robot_groups/same_process.rb
```

## Code Walkthrough

### Create a Robot Group

```ruby
group = HTM::RobotGroup.new(
  name: 'customer-support-ha',
  active: ['support-primary'],      # Active robot names
  passive: ['support-standby'],     # Standby robot names
  max_tokens: 8000                  # Token limit for shared memory
)
```

### Add Shared Memories

```ruby
# Memories are automatically shared across all robots in the group
group.remember(
  'Customer account #12345 prefers email communication.',
  originator: 'support-primary'
)

group.remember(
  'Open ticket #789: Billing discrepancy reported.',
  originator: 'support-primary'
)
```

### Check Synchronization Status

```ruby
status = group.status
# => {
#   name: 'customer-support-ha',
#   active: ['support-primary'],
#   passive: ['support-standby'],
#   working_memory_nodes: 3,
#   token_utilization: 0.15,
#   in_sync: true
# }
```

### Simulate Failover

```ruby
# Primary robot fails
puts "Primary robot stopped responding!"

# Failover to standby
group.failover!

status = group.status
# Active robots now: ['support-standby']
# Passive robots now: []
```

### Recall with Full Context

```ruby
# Standby has full context after failover
memories = group.recall('customer', limit: 5, strategy: :fulltext)
# => All memories are available immediately
```

### Scale Up (Add Robots)

```ruby
# Add a second active robot
group.add_active('support-secondary')
group.sync_robot('support-secondary')

# Both robots now share the same working memory
```

### Collaborative Memory

```ruby
# Either robot can add memories that sync to all
group.remember(
  'Issue escalated to billing department.',
  originator: 'support-secondary'
)
# Automatically synced to all group members
```

## Real-Time Sync

Robot Groups use PostgreSQL LISTEN/NOTIFY for real-time synchronization:

```ruby
sync_stats = group.sync_stats
# => {
#   nodes_synced: 5,
#   evictions_synced: 0,
#   notifications_received: 8
# }

# Check listener status
group.channel.listening?  # => true
```

## High Availability Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    RobotGroup                           │
│                'customer-support-ha'                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐     ┌─────────────────┐           │
│  │  support-primary│     │ support-standby │           │
│  │     (ACTIVE)    │     │    (PASSIVE)    │           │
│  └────────┬────────┘     └────────┬────────┘           │
│           │                       │                     │
│           └───────────┬───────────┘                     │
│                       │                                 │
│            ┌──────────▼──────────┐                     │
│            │  Shared Working     │                     │
│            │      Memory         │                     │
│            └──────────┬──────────┘                     │
│                       │                                 │
│            ┌──────────▼──────────┐                     │
│            │ PostgreSQL          │                     │
│            │ LISTEN/NOTIFY       │                     │
│            └─────────────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

## Use Cases

### Customer Support

Multiple support agents share context about ongoing conversations:

```ruby
group = HTM::RobotGroup.new(
  name: 'support-team',
  active: ['agent-1', 'agent-2', 'agent-3'],
  passive: ['backup-agent'],
  max_tokens: 16000
)
```

### Load Balancing

Distribute queries across multiple active robots:

```ruby
group = HTM::RobotGroup.new(
  name: 'query-handlers',
  active: ['handler-1', 'handler-2'],
  passive: [],
  max_tokens: 8000
)
```

### Disaster Recovery

Keep a warm standby ready to take over:

```ruby
group = HTM::RobotGroup.new(
  name: 'primary-with-dr',
  active: ['primary'],
  passive: ['dr-standby'],
  max_tokens: 32000
)

# On primary failure
group.failover!
```

## Cleanup

```ruby
# Clear shared working memory
group.clear_working_memory

# Stop the LISTEN/NOTIFY listener
group.shutdown
```

## See Also

- [Multi-Robot Usage Guide](../guides/multi-robot.md)
- [Hive Mind Architecture](../architecture/hive-mind.md)
- [Working Memory API](../api/working-memory.md)
