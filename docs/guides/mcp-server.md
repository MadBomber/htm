# MCP Server Guide

HTM includes a Model Context Protocol (MCP) server that exposes memory capabilities to AI assistants. This enables tools like Claude Desktop, Claude Code, and AIA to store, recall, and manage memories through a standardized protocol.

## Overview

The MCP server (`bin/htm_mcp.rb`) uses [FastMCP](https://github.com/yjacket/fast-mcp) to expose HTM's memory operations as MCP tools and resources. Any MCP-compatible client can connect to the server and use HTM's memory capabilities.

### Key Features

- **Session-based robot identity**: Each client session has its own robot identity
- **Full HTM API access**: Remember, recall, forget, restore, and manage tags
- **Session restore**: Restore previous session context from working memory
- **Fuzzy search**: Typo-tolerant tag and topic search
- **Resource access**: Query statistics, tag hierarchy, and recent memories

## Prerequisites

Before using the MCP server, ensure you have:

1. **HTM installed and configured**
   ```bash
   gem install htm
   ```

2. **PostgreSQL database set up**
   ```bash
   export HTM_DBURL="postgresql://user@localhost:5432/htm_development"
   rake htm:db:setup
   ```

3. **Ollama running** (for embeddings and tag extraction)
   ```bash
   ollama serve
   ollama pull nomic-embed-text
   ollama pull llama3
   ```

## Starting the Server

The MCP server uses STDIO transport which is compatible with most MCP clients.  When you do a `gem install htm` the htm_mcp.rb executable is placed on your $PATH.

```bash
htm_mcp.rb
```

The server logs to STDERR to avoid corrupting the JSON-RPC protocol on STDOUT.

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

## Client Configuration

### Claude Desktop

Add to `~/.config/claude/claude_desktop_config.json` (Linux/macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "htm-memory": {
      "command": "ruby",
      "args": ["/absolute/path/to/htm/bin/htm_mcp.rb"],
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
      "command": "ruby",
      "args": ["/absolute/path/to/htm/bin/htm_mcp.rb"],
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
    command: ruby
    args:
      - /absolute/path/to/htm/bin/htm_mcp.rb
    env:
      HTM_DBURL: postgresql://user@localhost:5432/htm_development
```

For project-specific configuration, add to `.aia/config.yml` in your project root:

```yaml
mcp_servers:
  htm-memory:
    command: ruby
    args:
      - /absolute/path/to/htm/bin/htm_mcp.rb
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
2. Check that the path to `htm_mcp.rb` is absolute
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
ruby bin/htm_mcp.rb 2>&1 | tee mcp_debug.log
```

The server logs all tool calls and errors to STDERR.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `HTM_DBURL` | PostgreSQL connection URL | Yes |
| `OLLAMA_URL` | Ollama server URL (default: `http://localhost:11434`) | No |
| `HTM_ROBOT_NAME` | Default robot name for clients | No |

## Next Steps

- [Getting Started](getting-started.md) - HTM basics
- [Adding Memories](adding-memories.md) - Learn about tags and metadata
- [Recalling Memories](recalling-memories.md) - Search strategies
- [Multi-Robot Systems](multi-robot.md) - Working with multiple robots
