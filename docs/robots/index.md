# Robots

HTM uses **robots** rather than the fashionable "agents" deliberately and thoughtfully. This section explains why, and how HTM's robot architecture enables intelligent memory management for LLM-based applications.

## Section Overview

| Document | Description |
|----------|-------------|
| [Why "Robots"?](why-robots.md) | The philosophical and practical reasons HTM uses "robot" terminology |
| [Hive Mind](hive-mind.md) | How all robots share a common long-term memory |
| [Two-Tier Memory](two-tier-memory.md) | The working memory and long-term storage architecture |
| [Multi-Robot Systems](multi-robot.md) | Running multiple robots with shared knowledge |
| [Robot Groups](robot-groups.md) | Organizing robots into collaborative groups |

## The Robot Philosophy

```
┌─────────────────────────────────────────────────────┐
│                  Shared Long-Term Memory            │
│              (The Hive Mind / Collective)           │
│                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
│  │ Memory  │  │ Memory  │  │ Memory  │  ...         │
│  └─────────┘  └─────────┘  └─────────┘              │
└─────────────────────────────────────────────────────┘
        ▲              ▲              ▲
        │              │              │
   ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
   │ Robot A │    │ Robot B │    │ Robot C │
   │         │    │         │    │         │
   │ Working │    │ Working │    │ Working │
   │ Memory  │    │ Memory  │    │ Memory  │
   └─────────┘    └─────────┘    └─────────┘
```

**Robots are workers**: They execute tasks, store memories, recall information.

**Robots are individuals**: Each has its own name, identity, and working context.

**Robots are collective**: They share knowledge, learn from each other's experiences.

**Robots are persistent**: They're registered, tracked, and their contributions are attributed.

## Quick Start

```ruby
# Create a robot
htm = HTM.new(robot_name: "research_assistant")

# Robot remembers information
htm.remember("PostgreSQL supports vector search via pgvector")

# Robot recalls relevant memories
memories = htm.recall("database search capabilities", limit: 5)

# Another robot can access the same memories
htm2 = HTM.new(robot_name: "documentation_writer")
memories = htm2.recall("vector search")  # Finds the first robot's memory
```

## Key Concepts

- **Robot Identity**: Each robot has a unique name and ID, tracked in the `robots` table
- **Working Memory**: Token-limited context for immediate use (per-robot)
- **Long-Term Memory**: Durable PostgreSQL storage (shared across all robots)
- **Hive Mind**: All robots contribute to and benefit from collective knowledge
- **Never Forget**: Memories are never truly deleted, only soft-deleted

## See Also

- [Getting Started Guide](../getting-started/index.md)
- [ADR-004: Hive Mind Architecture](../architecture/adrs/004-hive-mind.md)
- [ADR-008: Robot Identification](../architecture/adrs/008-robot-identification.md)
