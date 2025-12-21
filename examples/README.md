# HTM Examples

This directory contains example applications demonstrating various ways to use the HTM (Hierarchical Temporal Memory) gem.

## Prerequisites

All examples require:

1. **PostgreSQL Database** with pgvector extension:
   ```bash
   export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
   ```

   > **Note**: Database selection now respects `RAILS_ENV`. If `RAILS_ENV` is set,
   > HTM extracts the base name from `HTM_DATABASE__URL` and appends the environment suffix.
   > For example, with `HTM_DATABASE__URL=...htm_development` and `HTM_ENV=test`, HTM
   > connects to `htm_test`. When `RAILS_ENV` is unset (typical for examples),
   > behavior is unchanged.

2. **Ollama** (recommended for local LLM):
   ```bash
   ollama pull nomic-embed-text  # For embeddings
   ollama pull gemma3            # For tag extraction
   ```

3. **Ruby Dependencies**:
   ```bash
   bundle install
   ```

---

## Standalone Scripts

### basic_usage.rb

**Getting started with HTM fundamentals.**

Demonstrates the core API: configuring HTM, registering a robot, and using the three primary methods (`remember`, `recall`, `forget`).

```bash
ruby examples/basic_usage.rb
```

**Features:**
- HTM configuration with Ollama provider
- Robot initialization
- Storing memories with `remember()`
- Retrieving memories with `recall()` using timeframes
- Understanding async embedding/tag generation

---

### custom_llm_configuration.rb

**Flexible LLM integration patterns.**

Shows how to configure HTM with custom embedding and tag generation methods, supporting multiple LLM providers or custom infrastructure.

```bash
ruby examples/custom_llm_configuration.rb
```

**Features:**
- Default configuration (RubyLLM + Ollama)
- Custom lambdas for embedding generation
- Custom lambdas for tag extraction
- Service object integration pattern
- Mixed configuration (custom embedding + default tags)
- Provider settings (OpenAI, Anthropic, Gemini, etc.)

---

### file_loader_usage.rb

**Loading documents into long-term memory.**

Demonstrates loading markdown files with automatic paragraph chunking, YAML frontmatter extraction, and source tracking for re-sync.

```bash
ruby examples/file_loader_usage.rb
```

**Features:**
- Single file loading with `load_file()`
- Directory loading with glob patterns via `load_directory()`
- YAML frontmatter extraction (title, author, tags)
- Querying nodes from a specific file
- Re-sync behavior (skip unchanged files)
- Force reload option
- Unloading files with `unload_file()`

---

### timeframe_demo.rb

**Flexible time-based filtering for recall.**

Comprehensive demonstration of all timeframe options supported by `recall()`, including natural language parsing.

```bash
ruby examples/timeframe_demo.rb
```

**Features:**
- No filter (`nil`)
- Date/DateTime/Time objects (entire day)
- Range for precise time windows
- Natural language strings ("yesterday", "last week", "few days ago")
- Weekend expressions ("last weekend", "2 weekends ago")
- Automatic extraction (`:auto`) from query text
- Multiple time windows (array of ranges)

---

### telemetry/

**Live Grafana dashboard for HTM metrics.**

A complete telemetry demo using Homebrew-installed Prometheus and Grafana to visualize HTM metrics in real-time graphs.

```bash
cd examples/telemetry
ruby demo.rb
```

The demo automatically:
- Checks/installs Prometheus and Grafana via Homebrew
- Starts both services if not running
- Configures Prometheus to scrape the demo's metrics
- Cleans up previous demo data
- Opens Grafana in your browser

**Features:**
- Live updating dashboard with job counts, latencies, cache hit rates
- Pre-built Grafana dashboard JSON
- No Docker required - uses native macOS services

**Dependencies:**
```bash
brew install prometheus grafana
gem install prometheus-client webrick
```

See [telemetry/README.md](telemetry/README.md) for detailed setup instructions.

---

### mcp_server.rb & mcp_client.rb

**Model Context Protocol (MCP) integration for AI assistants.**

A pair of examples demonstrating how to expose HTM as an MCP server and connect to it from a chat client. This enables AI assistants like Claude Desktop to use HTM's memory capabilities.

#### mcp_server.rb

An MCP server that exposes HTM's memory operations as tools:

```bash
ruby examples/mcp_server.rb
```

**Tools exposed:**
- `SetRobotTool` - Set the robot identity for this session (call first)
- `GetRobotTool` - Get current robot information
- `GetWorkingMemoryTool` - Get working memory contents for session restore
- `RememberTool` - Store information with optional tags and metadata
- `RecallTool` - Search memories using vector, fulltext, or hybrid strategies
- `ForgetTool` - Soft-delete a memory (recoverable)
- `RestoreTool` - Restore a soft-deleted memory
- `ListTagsTool` - List tags with optional prefix filtering
- `StatsTool` - Get memory usage statistics

**Resources exposed:**
- `htm://statistics` - Memory statistics as JSON
- `htm://tags/hierarchy` - Tag hierarchy as text tree
- `htm://memories/recent` - Last 20 memories

**Claude Desktop configuration** (`~/.config/claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "htm-memory": {
      "command": "ruby",
      "args": ["/path/to/htm/examples/mcp_server.rb"],
      "env": {
        "HTM_DATABASE__URL": "postgresql://user@localhost:5432/htm_development"
      }
    }
  }
}
```

#### mcp_client.rb

An interactive chat client that connects to the MCP server via STDIO and uses a local Ollama model (gpt-oss) for conversation:

```bash
ruby examples/mcp_client.rb
```

**Features:**
- Prompts for robot name on startup (or uses `HTM_ROBOT_NAME` env var)
- Calls `SetRobotTool` to establish robot identity with the server
- Offers to restore previous session from working memory
- Connects to `mcp_server.rb` automatically via STDIO transport
- Interactive chat loop with tool calling
- LLM decides when to remember/recall information
- Logs tool calls and results for visibility

**Commands:**
- `/tools` - List available MCP tools
- `/resources` - List available MCP resources
- `/clear` - Clear chat history
- `/help` - Show help
- `/exit` - Quit

**Example startup and conversation:**
```
$ ruby examples/mcp_client.rb
Connecting to HTM MCP server...
[✓] Connected to HTM MCP server
[✓] Found 9 tools:
    - SetRobotTool: Set the robot identity for this session...
    - GetRobotTool: Get information about the current robot...
    - GetWorkingMemoryTool: Get all working memory contents...
    ...

Enter your robot name (or press Enter for default): alice-assistant
[✓] Robot name: alice-assistant
Setting robot identity on MCP server...
[✓] Robot identity set: alice-assistant (id=5, nodes=12)

Found 3 memories in working memory from previous session.
Restore previous session? (y/N): y
[✓] Will restore 3 memories after chat setup

Initializing chat with gpt-oss:latest...
[✓] Chat initialized with tools attached
Restoring 3 memories to chat context...
[✓] Restored 3 memories to chat context

======================================================================
HTM MCP Client - AI Chat with Memory Tools
======================================================================

Robot: alice-assistant
Model: gpt-oss:latest (via Ollama)
...

you> What's the API rate limit?

assistant> The API rate limit is 1000 requests per minute.
```

**Additional dependencies:**
```bash
gem install fast-mcp ruby_llm-mcp
ollama pull gpt-oss  # Or your preferred model
```

**Environment Variables:**
- `HTM_DATABASE__URL` - PostgreSQL connection (required)
- `OLLAMA_URL` - Ollama server URL (default: http://localhost:11434)
- `OLLAMA_MODEL` - Model to use (default: gpt-oss:latest)
- `HTM_ROBOT_NAME` - Robot name (optional, prompts if not set)

---

## Application Examples

### example_app/

**Full-featured HTM demonstration with RubyLLM integration.**

A standalone application showing complete HTM workflow with database connection, Ollama integration, memory operations, and multiple search strategies.

```bash
ruby examples/example_app/app.rb
```

**Features:**
- Database connection verification
- RubyLLM configuration for embeddings and tags
- Async embedding/tag generation with wait
- Comparison of search strategies (:fulltext, :vector, :hybrid)
- Detailed output of generated tags and embeddings

---

### sinatra_app/

**Web application with Sidekiq background processing.**

A Sinatra-based web application demonstrating HTM in a multi-user web context with async job processing.

```bash
cd examples/sinatra_app
bundle install
bundle exec ruby app.rb
```

**Features:**
- Sidekiq integration for background jobs
- Session-based robot identification
- RESTful API endpoints:
  - `POST /api/remember` - Store information
  - `GET /api/recall` - Search memories with timeframe filtering
  - `GET /api/stats` - Memory statistics
  - `GET /api/tags` - Tag tree structure
  - `GET /api/health` - Health check
- Interactive HTML UI with hybrid search scoring display
- Tag tree visualization

**Environment Variables:**
- `HTM_DATABASE__URL` - PostgreSQL connection (required)
- `REDIS_URL` - Redis for Sidekiq (default: redis://localhost:6379/0)
- `SESSION_SECRET` - Session encryption key

---

### cli_app/

**Interactive command-line application.**

A REPL-style CLI demonstrating synchronous job execution with the `:inline` backend, ideal for CLI tools and scripts.

```bash
ruby examples/cli_app/htm_cli.rb
```

**Commands:**
- `remember <text>` - Store information (waits for embedding/tags)
- `recall <topic>` - Hybrid search with LLM-powered response generation
- `tags [prefix]` - List all tags with linked node content
- `stats` - Memory statistics
- `help` - Show help
- `exit` - Quit

**Features:**
- Synchronous job execution (`:inline` backend)
- Real-time progress feedback
- Tag extraction visibility during search
- Hybrid search with scoring (similarity, tag_boost, combined)
- RubyLLM chat integration for context-aware responses
- Response storage in long-term memory

See [cli_app/README.md](cli_app/README.md) for detailed documentation.

---

### robot_groups/

**Multi-robot coordination with shared working memory.**

Demonstrates high-availability patterns with shared working memory, failover, and real-time synchronization via PostgreSQL LISTEN/NOTIFY.

#### same_process.rb

Single-process demonstration of robot groups:

```bash
ruby examples/robot_groups/same_process.rb
```

**Scenarios demonstrated:**
1. Creating a group with primary + standby robots
2. Adding shared memories
3. Verifying synchronization
4. Simulating failover (primary dies, standby takes over)
5. Verifying standby has full context
6. Dynamic scaling (adding new robots)
7. Collaborative memory (multiple robots adding)
8. Real-time sync via PostgreSQL LISTEN/NOTIFY

#### multi_process.rb

Cross-process demonstration with separate Ruby processes:

```bash
ruby examples/robot_groups/multi_process.rb
```

**Scenarios demonstrated:**
1. Spawning robot worker processes
2. Cross-process memory sharing
3. Collaborative memory updates
4. Failover when a process dies
5. Dynamic scaling (adding new processes)

**Key concepts:**
- **Shared Working Memory**: Multiple robots share context via `robot_nodes` table
- **Active/Passive Roles**: Active robots participate; passive robots maintain warm standby
- **Failover**: Instant takeover with full context already loaded
- **Real-time Sync**: PostgreSQL LISTEN/NOTIFY for in-memory cache coordination

---

## Directory Structure

```
examples/
├── README.md                      # This file
├── basic_usage.rb                 # Core API demonstration
├── custom_llm_configuration.rb    # LLM integration patterns
├── file_loader_usage.rb           # Document loading
├── timeframe_demo.rb              # Time-based filtering
├── telemetry/
│   ├── demo.rb                    # Live Grafana metrics dashboard
│   ├── README.md
│   ├── SETUP_README.md
│   └── grafana/dashboards/htm-metrics.json
├── mcp_server.rb                  # MCP server exposing HTM tools
├── mcp_client.rb                  # MCP client with chat interface
├── example_app/
│   ├── app.rb                     # Full-featured demo app
│   └── Rakefile
├── sinatra_app/
│   ├── app.rb                     # Sinatra web application
│   ├── Gemfile
│   └── Gemfile.lock
├── cli_app/
│   ├── htm_cli.rb                 # Interactive CLI
│   └── README.md                  # Detailed CLI documentation
└── robot_groups/
    ├── same_process.rb            # Single-process robot groups
    ├── multi_process.rb           # Multi-process coordination
    ├── robot_worker.rb            # Worker process for multi_process.rb
    └── lib/
        ├── robot_group.rb         # RobotGroup coordination class
        └── working_memory_channel.rb  # PostgreSQL pub/sub
```

---

## Choosing the Right Example

| Use Case | Example |
|----------|---------|
| Learning HTM basics | `basic_usage.rb` |
| Custom LLM integration | `custom_llm_configuration.rb` |
| Loading documents/files | `file_loader_usage.rb` |
| Time-based queries | `timeframe_demo.rb` |
| Production observability | `telemetry/` |
| MCP server for AI assistants | `mcp_server.rb` |
| MCP client with chat interface | `mcp_client.rb` |
| Web application | `sinatra_app/` |
| CLI tool | `cli_app/` |
| Multi-robot coordination | `robot_groups/` |
| High availability | `robot_groups/` |
