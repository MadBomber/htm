<div align="center">
  <h1>HTM</h1>
  <img src="docs/assets/images/htm_demo.gif" alt="Tree of Knowledge is Growing" width="400">

  <p><strong>Give your AI tools a shared, persistent memory.</strong></p>

  <p>
    <a href="https://rubygems.org/gems/htm"><img src="https://img.shields.io/gem/v/htm.svg" alt="Gem Version"></a>
    <a href="https://github.com/madbomber/htm/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  </p>
</div>

<br/>

## The Problem

Your AI assistants are brilliant but forgetful. Claude Desktop doesn't remember what Claude Code learned. Your custom chatbot can't recall what happened yesterday. Every tool starts fresh, every session.

**HTM fixes this.**

Connect all your MCP-enabled tools to the same long-term memory. What one robot learns, all robots remember. Context persists across sessions, tools, and time.

## What is HTM?

- **Hierarchical**: Organizes information from simple concepts to detailed relationships
- **Temporal**: Retrieves memories across time—from moments ago to months past
- **Memory**: Encodes, stores, and recalls information with semantic understanding

HTM is a Ruby gem that provides durable, shared memory for LLM-powered applications.

## Key Capabilities

### MCP Server — Connect Any AI Tool

HTM includes a Model Context Protocol server with 23 tools for memory management. Connect Claude Desktop, Claude Code, AIA, or any MCP-compatible client:

```json
{
  "mcpServers": {
    "htm": {
      "command": "htm_mcp",
      "env": { "HTM_DBURL": "postgresql://localhost/htm" }
    }
  }
}
```

The `htm_mcp` executable includes CLI commands for database management:

```bash
htm_mcp setup    # Initialize database schema
htm_mcp verify   # Check connection and migrations
htm_mcp stats    # Show memory statistics
htm_mcp help     # Full help with environment variables
htm_mcp          # Start MCP server (default)
```

Now your AI assistant can remember and recall across sessions:
- Store decisions, preferences, and context
- Search memories with natural language
- Build knowledge that compounds over time

### Hive Mind — Shared Knowledge Across Robots

All robots share the same global memory. What one learns, all can access:

```ruby
# Claude Desktop remembers a user preference
claude_desktop.remember("User prefers dark mode and concise responses")

# Later, Claude Code can recall it
claude_code.recall("user preferences")
# => "User prefers dark mode and concise responses"
```

Every tool builds on what came before. No more repeating yourself.

### Long-Term Memory — Never Forget

Two-tier architecture ensures nothing is lost:

- **Working Memory**: Token-limited context for immediate use
- **Long-Term Memory**: Durable PostgreSQL storage with vector search

Memories persist forever unless explicitly deleted. Working memory evicts to long-term storage—it never deletes.

```ruby
htm.remember("PostgreSQL with pgvector handles our vector search")

# Months later...
htm.recall("database decisions", timeframe: "last year")
# => Still there
```

### Robot Groups — High Availability

Coordinate multiple robots with shared working memory and instant failover:

```ruby
group = HTM::RobotGroup.new(
  name: 'support-ha',
  active: ['primary'],
  passive: ['standby']
)

# Primary fails? Standby takes over instantly
group.failover!
```

Real-time synchronization via PostgreSQL LISTEN/NOTIFY. Add or remove robots dynamically.

## Quick Start

```bash
gem install htm
```

```ruby
require 'htm'

# Initialize
htm = HTM.new(robot_name: "MyAssistant")

# Remember
htm.remember("User's project uses Rails 7 with PostgreSQL")

# Recall
memories = htm.recall("tech stack", timeframe: "last month")
```

For MCP integration, database setup, and configuration options, see the [full documentation](https://madbomber.github.io/htm).

## Features at a Glance

| Feature | Description |
|---------|-------------|
| **MCP Server** | 23 tools for AI assistant integration |
| **Hive Mind** | Shared memory across all robots |
| **Vector Search** | Semantic retrieval with pgvector |
| **Hybrid Search** | Combines vector + full-text matching |
| **Temporal Queries** | "last week", "yesterday", date ranges |
| **Auto-Tagging** | LLM extracts hierarchical tags automatically |
| **Robot Groups** | High-availability with failover |
| **Rails Integration** | Auto-configures via Railtie, uses ActiveJob |
| **Telemetry** | Optional OpenTelemetry metrics |

## Requirements

- Ruby 3.0+
- PostgreSQL with pgvector and pg_trgm extensions
- Ollama (default) or any local/private provider for embeddings and classifications

## Documentation

**[https://madbomber.github.io/htm](https://madbomber.github.io/htm)**

- [Installation & Setup](https://madbomber.github.io/htm/getting-started/)
- [MCP Server Guide](https://madbomber.github.io/htm/guides/mcp-server/)
- [Rails Integration](https://madbomber.github.io/htm/guides/rails/)
- [API Reference](https://madbomber.github.io/htm/api/)

## Why "Robots" Instead of "Agents"?

> "What's in a name? That which we call a rose
> By any other name would smell as sweet."
> — Shakespeare, *Romeo and Juliet*

Shakespeare argues names are arbitrary. In software, we respectfully disagree—names shape expectations and understanding.

HTM uses "robots" rather than the fashionable "agents" for several reasons:

- **Semantic clarity**: "Agent" is overloaded—user agents, software agents, real estate agents, secret agents. "Robot" is specific to automated workers.

- **Honest about capabilities**: "Agent" implies autonomy and genuine decision-making. These systems follow instructions—they don't have agency. "Robot" acknowledges what they actually are: tools.

- **Avoiding the hype cycle**: "AI Agent" and "Agentic AI" became buzzwords in 2023-2024, often meaning nothing more than "LLM with a prompt." We prefer terminology that will age well.

- **Many "agent" frameworks are prompt wrappers**: Look under the hood of popular agent libraries and you'll often find a single prompt in a for-loop. Calling that an "agent" sets false expectations.

- **Rich heritage**: "Robot" comes from Karel Čapek's 1920 play *R.U.R.* (from Czech *robota*, meaning labor). Isaac Asimov gave us the Three Laws. There's decades of thoughtful writing about robot ethics and behavior. "Agent" has no comparable tradition.

- **Personality**: Robots are endearing—R2-D2, Wall-E, Bender. They have cultural weight that "agent" lacks.

Honest terminology leads to clearer thinking. These are robots: tireless workers with perfect memory, executing instructions on our behalf. That's exactly what HTM helps them do better.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/madbomber/htm.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
