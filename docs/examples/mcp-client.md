# MCP Client Example

This example demonstrates using the HTM MCP (Model Context Protocol) server with an interactive AI chat interface.

**Source:** [`examples/mcp_client.rb`](https://github.com/madbomber/htm/blob/main/examples/mcp_client.rb)

## Overview

The MCP Client example shows:

- Connecting to the HTM MCP server via STDIO transport
- Interactive chat with tool calling
- Memory operations through natural language
- Session persistence and restoration
- Available tools and resources

## Prerequisites

```bash
# Install the MCP client gem
gem install ruby_llm-mcp

# Have Ollama running with a chat model
ollama pull gpt-oss  # or llama3, mistral, etc.

# Set database connection
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
```

## Running the Example

```bash
ruby examples/mcp_client.rb
```

## Code Walkthrough

### MCP Client Setup

```ruby
# Configure RubyLLM for Ollama
RubyLLM.configure do |config|
  config.ollama_api_base = "http://localhost:11434/v1"
end

# Connect to HTM MCP server
@mcp_client = RubyLLM::MCP.client(
  name: 'htm-memory',
  transport_type: :stdio,
  request_timeout: 60_000,
  config: {
    command: RbConfig.ruby,
    args: ['bin/htm_mcp'],
    env: {
      'HTM_DATABASE__URL' => ENV['HTM_DATABASE__URL'],
      'OLLAMA_URL' => 'http://localhost:11434'
    }
  }
)
```

### Set Robot Identity

```ruby
set_robot_tool = @tools.find { |t| t.name == 'SetRobotTool' }
result = set_robot_tool.call(name: "My Assistant")
```

### Chat with Tools

```ruby
@chat = RubyLLM.chat(
  model: 'gpt-oss:latest',
  provider: :ollama,
  assume_model_exists: true
)

# Attach MCP tools to chat
@chat.with_tools(*@tools)

# Natural language interactions
response = @chat.ask("Remember that the API rate limit is 1000 requests per minute")
# The LLM will call RememberTool automatically

response = @chat.ask("What do you know about databases?")
# The LLM will call RecallTool and summarize results
```

### Session Restoration

The client can restore previous session context:

```ruby
get_wm_tool = @tools.find { |t| t.name == 'GetWorkingMemoryTool' }
result = get_wm_tool.call({})

if result['count'] > 0
  # Restore previous memories to chat context
  @chat.add_message(
    role: :user,
    content: "Previous session context: #{memories.join("\n")}"
  )
end
```

## Available Commands

| Command | Description |
|---------|-------------|
| `/tools` | List available MCP tools |
| `/resources` | List available MCP resources |
| `/stats` | Show memory statistics |
| `/tags` | List all tags |
| `/clear` | Clear chat history |
| `/help` | Show help |
| `/exit` | Quit |

## Available MCP Tools

| Tool | Description |
|------|-------------|
| `SetRobotTool` | Set the current robot identity |
| `RememberTool` | Store information in memory |
| `RecallTool` | Query memories by topic |
| `ForgetTool` | Delete a memory by ID |
| `ListTagsTool` | List all hierarchical tags |
| `StatsTool` | Show memory statistics |
| `GetWorkingMemoryTool` | Get current working memory |

## Example Interactions

```
you> Remember that the PostgreSQL connection string is in the DATABASE_URL env var

[Tool Call] RememberTool
  Arguments: {content: "PostgreSQL connection string is in DATABASE_URL env var"}
[Tool Result] RememberTool
  Result: {"success": true, "node_id": 42}

Assistant> I've stored that information about the PostgreSQL connection string.

you> What do you know about databases?

[Tool Call] RecallTool
  Arguments: {topic: "databases", limit: 5}
[Tool Result] RecallTool
  Result: {"memories": [...]}

Assistant> Based on my memories, I know that:
1. PostgreSQL connection string is stored in DATABASE_URL env var
2. PostgreSQL supports vector search via pgvector
...
```

## Configuration

```bash
# Use a different Ollama model
export OLLAMA_MODEL="llama3:latest"

# Use a different Ollama URL
export OLLAMA_URL="http://192.168.1.100:11434"

# Set robot name via environment
export HTM_ROBOT_NAME="My Custom Bot"
```

## See Also

- [MCP Server Guide](../guides/mcp-server.md)
- [HTM API Reference](../api/htm.md)
- [RubyLLM-MCP Documentation](https://github.com/contextco/ruby_llm-mcp)
