# MCP Server Guide

HTM includes a Model Context Protocol (MCP) server that exposes memory capabilities to AI assistants. This enables tools like Claude Desktop, Claude Code, and AIA to store, recall, and manage memories through a standardized protocol.

## Overview

The MCP server (`bin/htm_mcp`) uses [FastMCP](https://github.com/yjacket/fast-mcp) to expose HTM's memory operations as MCP tools and resources. Any MCP-compatible client can connect to the server and use HTM's memory capabilities.

### Key Features

- **Session-based robot identity**: Each client session has its own robot identity
- **Full HTM API access**: Remember, recall, forget, restore, and manage tags
- **Session restore**: Restore previous session context from working memory
- **Fuzzy search**: Typo-tolerant tag and topic search
- **Resource access**: Query statistics, tag hierarchy, and recent memories
- **Robot Groups (High-Availability)**: Coordinate multiple robots with shared working memory, failover, and real-time sync

## Prerequisites

Before using the MCP server, ensure you have:

1. **HTM installed and configured**
   ```bash
   gem install htm
   ```

2. **PostgreSQL database set up**
   ```bash
   export HTM_DBURL="postgresql://user@localhost:5432/htm_development"
   htm_mcp setup
   ```

3. **Ollama running** (for embeddings and tag extraction)
   ```bash
   ollama serve
   ollama pull nomic-embed-text
   ollama pull llama3
   ```

## Starting the Server

The MCP server uses STDIO transport which is compatible with most MCP clients. When you do a `gem install htm`, the `htm_mcp` executable is placed on your $PATH.

```bash
htm_mcp
```

The server logs to STDERR to avoid corrupting the JSON-RPC protocol on STDOUT.

## CLI Commands

The `htm_mcp` executable includes management commands for database setup and diagnostics:

| Command | Description |
|---------|-------------|
| `htm_mcp` | Start the MCP server (default) |
| `htm_mcp server` | Start the MCP server (explicit) |
| `htm_mcp setup` | Initialize database schema and run migrations |
| `htm_mcp init` | Alias for setup |
| `htm_mcp verify` | Verify database connection, extensions, and migration status |
| `htm_mcp stats` | Show memory statistics (nodes, tags, robots, database size) |
| `htm_mcp version` | Show HTM version |
| `htm_mcp help` | Show help with all environment variables |

### First-Time Setup

```bash
# Set your database URL
export HTM_DBURL="postgresql://user@localhost:5432/htm_development"

# Initialize the database
htm_mcp setup

# Verify everything is working
htm_mcp verify

# Check memory statistics
htm_mcp stats
```

### Migration Status

The `verify` command shows migration status with `+` (applied) and `-` (pending) indicators:

```
Migration Status
--------------------------------------------------------------------------------
  + 20250101000001_create_schema_migrations
  + 20250101000002_create_robots
  + 20250101000003_create_nodes
  - 20250612000001_add_new_feature
--------------------------------------------------------------------------------
  3 applied, 1 pending
```

## Tools Reference

### SetRobotTool

Set the robot identity for this session. **Call this first** to establish your robot name.

**Parameters:**
- `name` (String, required): The robot name (will be created if it doesn't exist)

**Returns:**
```json
{
  "success": true,
  "robot_id": 5,
  "robot_name": "my-assistant",
  "node_count": 12,
  "message": "Robot 'my-assistant' is now active for this session"
}
```

**Example usage:**
```
Set robot name to "research-bot"
```

---

### GetRobotTool

Get information about the current robot for this session.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "robot_id": 5,
  "robot_name": "my-assistant",
  "initialized": true,
  "memory_summary": {
    "total_nodes": 150,
    "working_memory_nodes": 25
  }
}
```

---

### GetWorkingMemoryTool

Get all working memory contents for the current robot. Use this to restore a previous session.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "robot_id": 5,
  "robot_name": "my-assistant",
  "count": 3,
  "working_memory": [
    {
      "id": 123,
      "content": "User prefers dark mode",
      "tags": ["user:preference", "ui"],
      "remember_count": 5,
      "last_remembered_at": "2024-01-15T10:30:00Z",
      "created_at": "2024-01-10T08:00:00Z"
    }
  ]
}
```

---

### RememberTool

Store information in HTM long-term memory with optional tags.

**Parameters:**
- `content` (String, required): The content to remember
- `tags` (Array<String>, optional): Tags for categorization (e.g., `["database:postgresql", "config"]`)
- `metadata` (Hash, optional): Key-value metadata pairs

**Returns:**
```json
{
  "success": true,
  "node_id": 456,
  "robot_id": 5,
  "robot_name": "my-assistant",
  "content": "PostgreSQL uses pgvector for similarity search",
  "tags": ["database:postgresql", "vector-search"],
  "created_at": "2024-01-15T14:30:00Z"
}
```

**Example usage:**
```
Remember that the user prefers Ruby over Python for scripting tasks
```

---

### RecallTool

Search and retrieve memories from HTM using semantic, full-text, or hybrid search.

**Parameters:**
- `query` (String, required): Search query (natural language or keywords)
- `limit` (Integer, optional): Maximum results (default: 10)
- `strategy` (String, optional): Search strategy - `"vector"`, `"fulltext"`, or `"hybrid"` (default: `"hybrid"`)
- `timeframe` (String, optional): Time filter - `"today"`, `"this week"`, `"this month"`, or ISO8601 date range

**Returns:**
```json
{
  "success": true,
  "query": "database decisions",
  "strategy": "hybrid",
  "robot_name": "my-assistant",
  "count": 3,
  "results": [
    {
      "id": 123,
      "content": "Decided to use PostgreSQL for vector search",
      "tags": ["database:postgresql", "decision"],
      "created_at": "2024-01-10T08:00:00Z",
      "score": 0.89
    }
  ]
}
```

**Example usage:**
```
Recall what we discussed about database architecture last week
```

---

### ForgetTool

Soft-delete a memory from HTM (can be restored later).

**Parameters:**
- `node_id` (Integer, required): The ID of the node to forget

**Returns:**
```json
{
  "success": true,
  "node_id": 123,
  "robot_name": "my-assistant",
  "message": "Memory soft-deleted. Use restore to recover."
}
```

---

### RestoreTool

Restore a soft-deleted memory.

**Parameters:**
- `node_id` (Integer, required): The ID of the node to restore

**Returns:**
```json
{
  "success": true,
  "node_id": 123,
  "robot_name": "my-assistant",
  "message": "Memory restored successfully"
}
```

---

### ListTagsTool

List all tags in HTM, optionally filtered by prefix.

**Parameters:**
- `prefix` (String, optional): Filter tags by prefix (e.g., `"database"` returns `"database:postgresql"`, etc.)

**Returns:**
```json
{
  "success": true,
  "prefix": "database",
  "count": 5,
  "tags": [
    { "name": "database", "node_count": 15 },
    { "name": "database:postgresql", "node_count": 10 },
    { "name": "database:postgresql:extensions", "node_count": 3 }
  ]
}
```

---

### SearchTagsTool

Search for tags using fuzzy matching (typo-tolerant). Use this when you're unsure of exact tag names.

**Parameters:**
- `query` (String, required): Search query (can contain typos, e.g., `"postgrsql"` finds `"database:postgresql"`)
- `limit` (Integer, optional): Maximum results (default: 20)
- `min_similarity` (Float, optional): Minimum similarity threshold 0.0-1.0 (default: 0.3, lower = more fuzzy)

**Returns:**
```json
{
  "success": true,
  "query": "postgrsql",
  "min_similarity": 0.3,
  "count": 2,
  "tags": [
    { "name": "database:postgresql", "similarity": 0.857, "node_count": 10 },
    { "name": "database:postgresql:extensions", "similarity": 0.714, "node_count": 3 }
  ]
}
```

---

### FindByTopicTool

Find memory nodes by topic/tag with optional fuzzy matching for typo tolerance.

**Parameters:**
- `topic` (String, required): Topic or tag to search for
- `fuzzy` (Boolean, optional): Enable fuzzy matching for typo tolerance (default: false)
- `exact` (Boolean, optional): Require exact tag match (default: false, uses prefix matching)
- `limit` (Integer, optional): Maximum results (default: 20)
- `min_similarity` (Float, optional): Minimum similarity for fuzzy mode (default: 0.3)

**Returns:**
```json
{
  "success": true,
  "topic": "database:postgresql",
  "fuzzy": false,
  "exact": false,
  "count": 5,
  "results": [
    {
      "id": 123,
      "content": "PostgreSQL uses pgvector for similarity search...",
      "tags": ["database:postgresql", "vector-search"],
      "created_at": "2024-01-10T08:00:00Z"
    }
  ]
}
```

---

### StatsTool

Get statistics about HTM memory usage.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "current_robot": {
    "name": "my-assistant",
    "id": 5,
    "memory_summary": { "total_nodes": 150, "working_memory_nodes": 25 }
  },
  "statistics": {
    "nodes": {
      "active": 500,
      "deleted": 20,
      "with_embeddings": 495,
      "with_tags": 480
    },
    "tags": { "total": 75 },
    "robots": { "total": 3 }
  }
}
```

## Robot Group Tools

Robot Groups enable high-availability configurations with multiple robots sharing working memory. Groups support active/passive roles, automatic failover, and real-time synchronization via PostgreSQL LISTEN/NOTIFY.

### CreateGroupTool

Create a new robot group with shared working memory.

**Parameters:**
- `name` (String, required): Unique name for the group
- `sync_interval` (Integer, optional): Sync interval in seconds (default: 30)
- `max_members` (Integer, optional): Maximum group members (default: 10)
- `token_budget` (Integer, optional): Shared working memory token limit (default: 4000)

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "sync_interval": 30,
  "max_members": 10,
  "token_budget": 4000,
  "message": "Robot group 'research-team' created successfully"
}
```

---

### ListGroupsTool

List all active robot groups in the current MCP session.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "count": 2,
  "groups": [
    {
      "name": "research-team",
      "member_count": 3,
      "active_robot": "researcher-1"
    },
    {
      "name": "support-team",
      "member_count": 2,
      "active_robot": "support-bot"
    }
  ]
}
```

---

### GetGroupStatusTool

Get detailed status of a robot group.

**Parameters:**
- `name` (String, required): The group name

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "status": {
    "active_robot": "researcher-1",
    "member_count": 3,
    "members": [
      { "name": "researcher-1", "role": "active", "last_seen": "2024-01-15T10:30:00Z" },
      { "name": "researcher-2", "role": "passive", "last_seen": "2024-01-15T10:29:55Z" },
      { "name": "researcher-3", "role": "passive", "last_seen": "2024-01-15T10:29:50Z" }
    ],
    "working_memory_tokens": 2500,
    "token_budget": 4000,
    "sync_interval": 30
  }
}
```

---

### JoinGroupTool

Add a robot to an existing group.

**Parameters:**
- `group_name` (String, required): The group to join
- `robot_name` (String, required): The robot name to add
- `role` (String, optional): `"active"` or `"passive"` (default: `"passive"`)

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "robot_name": "researcher-4",
  "role": "passive",
  "message": "Robot 'researcher-4' joined group 'research-team' as passive"
}
```

---

### LeaveGroupTool

Remove a robot from a group.

**Parameters:**
- `group_name` (String, required): The group to leave
- `robot_name` (String, required): The robot to remove

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "robot_name": "researcher-4",
  "message": "Robot 'researcher-4' left group 'research-team'"
}
```

---

### GroupRememberTool

Store memory shared across all group members. Only the active robot can write to group memory.

**Parameters:**
- `group_name` (String, required): The target group
- `content` (String, required): The content to remember
- `tags` (Array<String>, optional): Tags for categorization
- `metadata` (Hash, optional): Key-value metadata

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "node_id": 789,
  "content": "Found relevant paper on embeddings",
  "tags": ["research:papers", "ai:embeddings"],
  "message": "Memory stored in group working memory"
}
```

---

### GroupRecallTool

Recall memories from a group's shared context.

**Parameters:**
- `group_name` (String, required): The target group
- `query` (String, required): Search query
- `limit` (Integer, optional): Maximum results (default: 10)
- `strategy` (String, optional): `"vector"`, `"fulltext"`, or `"hybrid"` (default: `"hybrid"`)

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "query": "embeddings",
  "count": 3,
  "results": [
    {
      "id": 789,
      "content": "Found relevant paper on embeddings",
      "tags": ["research:papers", "ai:embeddings"],
      "score": 0.92
    }
  ]
}
```

---

### GetGroupWorkingMemoryTool

Get a group's working memory contents.

**Parameters:**
- `group_name` (String, required): The target group

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "token_usage": 2500,
  "token_budget": 4000,
  "count": 15,
  "working_memory": [
    {
      "id": 789,
      "content": "Found relevant paper on embeddings",
      "tags": ["research:papers"],
      "added_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

### PromoteRobotTool

Promote a passive robot to active role. The current active robot becomes passive.

**Parameters:**
- `group_name` (String, required): The target group
- `robot_name` (String, required): The robot to promote

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "promoted_robot": "researcher-2",
  "previous_active": "researcher-1",
  "message": "Robot 'researcher-2' is now active. 'researcher-1' is now passive."
}
```

---

### FailoverTool

Trigger failover to the next available robot in the group.

**Parameters:**
- `group_name` (String, required): The target group

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "new_active": "researcher-2",
  "previous_active": "researcher-1",
  "message": "Failover complete. 'researcher-2' is now active."
}
```

---

### SyncGroupTool

Manually synchronize group state across all members.

**Parameters:**
- `group_name` (String, required): The target group

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "synced_members": 3,
  "message": "Group state synchronized across 3 members"
}
```

---

### ShutdownGroupTool

Gracefully shutdown a robot group, removing all members.

**Parameters:**
- `group_name` (String, required): The group to shutdown

**Returns:**
```json
{
  "success": true,
  "group_name": "research-team",
  "message": "Robot group 'research-team' has been shut down"
}
```

## Resources Reference

### htm://statistics

Memory statistics as JSON.

```json
{
  "total_nodes": 500,
  "total_tags": 75,
  "total_robots": 3,
  "current_robot": "my-assistant",
  "robot_id": 5,
  "robot_initialized": true,
  "embedding_provider": "ollama",
  "embedding_model": "nomic-embed-text"
}
```

### htm://tags/hierarchy

Tag hierarchy as a text tree:

```
database
├── postgresql
│   ├── extensions
│   └── performance
└── mysql
ai
├── llm
│   ├── embeddings
│   └── prompts
└── rag
```

### htm://memories/recent

Last 20 memories as JSON array.

### htm://groups

Active robot groups and their status:

```json
{
  "count": 2,
  "groups": [
    {
      "name": "research-team",
      "member_count": 3,
      "active_robot": "researcher-1",
      "token_usage": 2500,
      "token_budget": 4000
    },
    {
      "name": "support-team",
      "member_count": 2,
      "active_robot": "support-bot",
      "token_usage": 1200,
      "token_budget": 4000
    }
  ]
}
```

## Client Configuration

### Claude Desktop

Add to `~/.config/claude/claude_desktop_config.json` (Linux/macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "htm-memory": {
      "command": "htm_mcp",
      "env": {
        "HTM_DBURL": "postgresql://user@localhost:5432/htm_development"
      }
    }
  }
}
```

If `htm_mcp` is not in your PATH, use the absolute path:

```json
{
  "mcpServers": {
    "htm-memory": {
      "command": "/path/to/htm_mcp",
      "env": {
        "HTM_DBURL": "postgresql://user@localhost:5432/htm_development"
      }
    }
  }
}
```

After adding the configuration:
1. Restart Claude Desktop
2. Look for the HTM tools in the tools menu (hammer icon)
3. Start a conversation and ask Claude to remember something

### Claude Code

Add to `~/.claude/claude_code_config.json`:

```json
{
  "mcpServers": {
    "htm-memory": {
      "command": "htm_mcp",
      "env": {
        "HTM_DBURL": "postgresql://user@localhost:5432/htm_development"
      }
    }
  }
}
```

After adding the configuration:
1. Restart Claude Code or run `/mcp` to refresh
2. The HTM tools will appear with the `mcp__htm-memory__` prefix
3. Claude Code will automatically use HTM tools when appropriate

**Example prompts for Claude Code:**
```
Remember that this project uses PostgreSQL with pgvector for similarity search

Recall what architecture decisions we made for this project

What tags do we have related to database configuration?
```

### AIA (AI Assistant)

Add to `~/.config/aia/config.yml`:

```yaml
mcp_servers:
  htm-memory:
    command: htm_mcp
    env:
      HTM_DBURL: postgresql://user@localhost:5432/htm_development
```

For project-specific configuration, add to `.aia/config.yml` in your project root:

```yaml
mcp_servers:
  htm-memory:
    command: htm_mcp
    env:
      HTM_DBURL: postgresql://user@localhost:5432/my_project_htm
```

## Usage Examples

### Basic Workflow

1. **Set your robot identity** (do this first in each session):
   ```
   Set my robot name to "project-assistant"
   ```

2. **Store information as you work**:
   ```
   Remember that we decided to use Redis for caching with a 1-hour TTL
   ```

3. **Recall relevant context**:
   ```
   What caching decisions have we made?
   ```

4. **Browse by topic**:
   ```
   Show me all memories tagged with "architecture"
   ```

### Session Restoration

When starting a new session, you can restore context from a previous session:

1. **Set robot identity** (same name as before):
   ```
   Set robot name to "project-assistant"
   ```

2. **Get working memory**:
   ```
   Get my working memory contents
   ```

3. **Review and continue**:
   The AI assistant will have access to your previous session's context.

### Project-Specific Memory

Use different robot names for different projects:

```
# For project A
Set robot name to "project-a-assistant"
Remember that project A uses React with TypeScript

# For project B
Set robot name to "project-b-assistant"
Remember that project B uses Vue with JavaScript
```

Each robot has its own working memory but shares the global long-term memory (hive mind).

### Using Robot Groups

Robot Groups enable high-availability configurations where multiple robots share working memory:

1. **Create a group**:
   ```
   Create a robot group called "research-team" with 3 max members
   ```

2. **Join robots to the group**:
   ```
   Join robot "researcher-1" to group "research-team" as active
   Join robot "researcher-2" to group "research-team" as passive
   ```

3. **Store shared memories**:
   ```
   Remember in group "research-team" that we found a relevant paper on embeddings
   ```

4. **Recall from group context**:
   ```
   Recall from group "research-team" what we know about embeddings
   ```

5. **Handle failover**:
   ```
   Trigger failover for group "research-team"
   ```

6. **Check group status**:
   ```
   Show status of group "research-team"
   ```

### Searching with Typo Tolerance

Use fuzzy search when you're not sure of exact tag names:

```
Search for tags similar to "postgrsql"
```

This will find `database:postgresql` even with the typo.

## Session Management

### How Sessions Work

1. **Per-client isolation**: Each MCP client spawns its own server process
2. **Robot identity**: The `SetRobotTool` establishes which robot you're using
3. **Working memory**: Each robot has its own working memory tracked in the database
4. **Hive mind**: All robots share the same long-term memory

### Best Practices

1. **Always set robot identity first**: Call `SetRobotTool` at the start of each session
2. **Use consistent robot names**: Use the same name to maintain continuity
3. **Restore previous sessions**: Use `GetWorkingMemoryTool` to restore context
4. **Use descriptive robot names**: e.g., `"code-review-assistant"`, `"project-x-helper"`

## Troubleshooting

### Server Won't Start

**Error: `fast-mcp gem not found`**
```bash
gem install fast-mcp
```

**Error: `HTM_DBURL not set`**
```bash
export HTM_DBURL="postgresql://user@localhost:5432/htm_development"
```

### Database Connection Issues

**Error: `could not connect to server`**
1. Verify PostgreSQL is running
2. Check your connection URL
3. Test with: `rake htm:db:test`

**Error: `extension "vector" does not exist`**
```bash
# Install pgvector extension
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

### Client Can't Connect

**Claude Desktop doesn't show HTM tools:**
1. Verify the config file path is correct for your OS
2. Check that `htm_mcp` is in your PATH or use an absolute path
3. Restart Claude Desktop completely
4. Check Claude Desktop logs for errors

**Claude Code doesn't recognize tools:**
1. Run `/mcp` to refresh MCP connections
2. Verify config is valid JSON
3. Check that HTM_DBURL is set in the env section

### Embedding/Tag Errors

**Error: `Connection refused` (Ollama)**
1. Start Ollama: `ollama serve`
2. Pull required models:
   ```bash
   ollama pull nomic-embed-text
   ollama pull llama3
   ```

### Debugging

Enable verbose logging by checking STDERR output:
```bash
htm_mcp 2>&1 | tee mcp_debug.log
```

The server logs all tool calls and errors to STDERR.

## Environment Variables

Run `htm_mcp help` for a complete list. Key variables:

### Database (required)

| Variable | Description |
|----------|-------------|
| `HTM_DBURL` | PostgreSQL connection URL (e.g., `postgresql://user:pass@localhost:5432/htm_development`) |

### Database (alternative to HTM_DBURL)

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_DBNAME` | Database name | - |
| `HTM_DBHOST` | Database host | `localhost` |
| `HTM_DBPORT` | Database port | `5432` |
| `HTM_DBUSER` | Database username | - |
| `HTM_DBPASS` | Database password | - |
| `HTM_DBSSLMODE` | SSL mode | `prefer` |

### LLM Providers

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_EMBEDDING_PROVIDER` | Embedding provider | `ollama` |
| `HTM_EMBEDDING_MODEL` | Embedding model | `nomic-embed-text:latest` |
| `HTM_TAG_PROVIDER` | Tag extraction provider | `ollama` |
| `HTM_TAG_MODEL` | Tag model | `gemma3:latest` |
| `HTM_OLLAMA_URL` | Ollama server URL | `http://localhost:11434` |

### Other Providers (set API keys as needed)

| Variable | Description |
|----------|-------------|
| `HTM_OPENAI_API_KEY` | OpenAI API key |
| `HTM_ANTHROPIC_API_KEY` | Anthropic API key |
| `HTM_GEMINI_API_KEY` | Google Gemini API key |
| `HTM_AZURE_API_KEY` | Azure OpenAI API key |
| `HTM_AZURE_ENDPOINT` | Azure OpenAI endpoint |

## Next Steps

- [Getting Started](getting-started.md) - HTM basics
- [Adding Memories](adding-memories.md) - Learn about tags and metadata
- [Recalling Memories](recalling-memories.md) - Search strategies
- [Multi-Robot Systems](multi-robot.md) - Working with multiple robots
