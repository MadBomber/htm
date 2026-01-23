# HTM Examples

This directory contains example applications demonstrating various ways to use the HTM (Hierarchical Temporal Memory) gem.

## Quick Start

All examples use the `htm_examples` database, isolated from development and production data.

```bash
# One-time setup: create and configure examples database
rake examples:setup

# Run the basic example
rake examples:basic

# Run all standalone examples
rake examples:all

# Check examples database status
rake examples:status
```

## Prerequisites

1. **PostgreSQL Database** with pgvector extension:
   ```bash
   # Create the examples database (done automatically by rake examples:setup)
   createdb htm_examples
   psql htm_examples -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
   ```

   > **Note**: All examples use `HTM_ENV=examples` which connects to `htm_examples` database.
   > This isolation prevents examples from polluting development or production data.

2. **Ollama** (recommended for local LLM):
   ```bash
   ollama pull nomic-embed-text  # For embeddings
   ollama pull gemma3            # For tag extraction
   ```

3. **Ruby Dependencies**:
   ```bash
   bundle install
   ```

## Available Rake Tasks

```bash
rake examples:setup    # Set up examples database (create + setup schema)
rake examples:reset    # Reset examples database (drop + create + setup)
rake examples:basic    # Run basic_usage example
rake examples:all      # Run all standalone examples
rake examples:status   # Show examples database status
rake example           # Alias for examples:basic
```

---

## Example Progression

Examples are numbered to indicate recommended learning order, from basic concepts to advanced features.

### 00_create_examples_db.rb

**Database setup for examples.**

Creates and configures the `htm_examples` database. Run this first before other examples.

```bash
ruby examples/00_create_examples_db.rb
```

---

### 01_basic_usage.rb

**Getting started with HTM fundamentals.**

Demonstrates the core API: configuring HTM, registering a robot, and using the three primary methods (`remember`, `recall`, `forget`).

```bash
ruby examples/01_basic_usage.rb
```

**Features:**
- HTM configuration with Ollama provider
- Robot initialization
- Storing memories with `remember()`
- Retrieving memories with `recall()` using timeframes
- Understanding async embedding/tag generation

---

### 02_config_file_example/

**Configuration management with source tracing.**

Demonstrates how HTM uses `anyway_config` for layered configuration from multiple sources, with source tracing to show where each value originated.

```bash
cd examples/02_config_file_example
ruby show_config.rb
```

**Features:**
- Configuration priority order (defaults → XDG → project → local → env vars)
- Source tracing showing origin of each config value
- `HTM_CONF` environment variable for custom config file paths
- Environment-specific configuration (`HTM_ENV`)
- Generating config templates with `htm_mcp config`

**Usage examples:**
```bash
# Basic - loads ./config/htm.local.yml automatically
ruby show_config.rb

# Use custom config file
HTM_CONF=./custom_config.yml ruby show_config.rb

# Override with environment variables
HTM_EMBEDDING__MODEL=mxbai-embed-large ruby show_config.rb

# Different environment
HTM_ENV=production ruby show_config.rb
```

See [02_config_file_example/README.md](02_config_file_example/README.md) for detailed documentation.

---

### 03_custom_llm_configuration.rb

**Flexible LLM integration patterns.**

Shows how to configure HTM with custom embedding and tag generation methods, supporting multiple LLM providers or custom infrastructure.

```bash
ruby examples/03_custom_llm_configuration.rb
```

**Features:**
- Default configuration (RubyLLM + Ollama)
- Custom lambdas for embedding generation
- Custom lambdas for tag extraction
- Service object integration pattern
- Mixed configuration (custom embedding + default tags)
- Provider settings (OpenAI, Anthropic, Gemini, etc.)

---

### 04_file_loader_usage.rb

**Loading documents into long-term memory.**

Demonstrates loading markdown files with automatic paragraph chunking, YAML frontmatter extraction, and source tracking for re-sync.

```bash
ruby examples/04_file_loader_usage.rb
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

### 05_timeframe_demo.rb

**Flexible time-based filtering for recall.**

Comprehensive demonstration of all timeframe options supported by `recall()`, including natural language parsing.

```bash
ruby examples/05_timeframe_demo.rb
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

### 06_example_app/

**Full-featured HTM demonstration with RubyLLM integration.**

A standalone application showing complete HTM workflow with database connection, Ollama integration, memory operations, and multiple search strategies.

```bash
ruby examples/06_example_app/app.rb
```

**Features:**
- Database connection verification
- RubyLLM configuration for embeddings and tags
- Async embedding/tag generation with wait
- Comparison of search strategies (:fulltext, :vector, :hybrid)
- Detailed output of generated tags and embeddings

---

### 07_cli_app/

**Interactive command-line application.**

A REPL-style CLI demonstrating synchronous job execution with the `:inline` backend, ideal for CLI tools and scripts.

```bash
ruby examples/07_cli_app/htm_cli.rb
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

See [07_cli_app/README.md](07_cli_app/README.md) for detailed documentation.

---

### 08_sinatra_app/

**Web application with Sidekiq background processing.**

A Sinatra-based web application demonstrating HTM in a multi-user web context with async job processing.

```bash
cd examples/08_sinatra_app
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

### 09_mcp_client.rb

**Model Context Protocol (MCP) client for AI assistants.**

An interactive chat client that connects to an MCP server via STDIO and uses a local Ollama model for conversation. This enables AI assistants like Claude Desktop to use HTM's memory capabilities.

```bash
ruby examples/09_mcp_client.rb
```

**Features:**
- Prompts for robot name on startup (or uses `HTM_ROBOT_NAME` env var)
- Calls `SetRobotTool` to establish robot identity with the server
- Offers to restore previous session from working memory
- Connects to MCP server automatically via STDIO transport
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
$ ruby examples/09_mcp_client.rb
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

### 10_telemetry/

**Live Grafana dashboard for HTM metrics.**

A complete telemetry demo using Homebrew-installed Prometheus and Grafana to visualize HTM metrics in real-time graphs.

```bash
cd examples/10_telemetry
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

See [10_telemetry/README.md](10_telemetry/README.md) for detailed setup instructions.

---

### 11_robot_groups/

**Multi-robot coordination with shared working memory.**

Demonstrates high-availability patterns with shared working memory, failover, and real-time synchronization via PostgreSQL LISTEN/NOTIFY.

#### same_process.rb

Single-process demonstration of robot groups:

```bash
ruby examples/11_robot_groups/same_process.rb
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
ruby examples/11_robot_groups/multi_process.rb
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

### 12_rails_app/

**Rails integration example.**

A complete Rails application demonstrating HTM integration with Rails controllers, views, and background jobs.

```bash
cd examples/12_rails_app
bundle install
bin/rails db:create db:migrate
bin/dev
```

See [12_rails_app/README.md](12_rails_app/README.md) for detailed documentation.

---

## Directory Structure

```
examples/
├── README.md                           # This file
├── examples_helper.rb                  # Shared setup for all examples
├── 00_create_examples_db.rb            # Database setup
├── 01_basic_usage.rb                   # Core API demonstration
├── 02_config_file_example/
│   ├── show_config.rb                  # Config source tracing demo
│   ├── custom_config.yml               # Example for HTM_CONF
│   ├── README.md                       # Configuration documentation
│   └── config/
│       └── htm.local.yml               # Auto-loaded local overrides
├── 03_custom_llm_configuration.rb      # LLM integration patterns
├── 04_file_loader_usage.rb             # Document loading
├── 05_timeframe_demo.rb                # Time-based filtering
├── 06_example_app/
│   ├── app.rb                          # Full-featured demo app
│   └── Rakefile
├── 07_cli_app/
│   ├── htm_cli.rb                      # Interactive CLI
│   └── README.md                       # Detailed CLI documentation
├── 08_sinatra_app/
│   ├── app.rb                          # Sinatra web application
│   ├── Gemfile
│   └── Gemfile.lock
├── 09_mcp_client.rb                    # MCP client with chat interface
├── 10_telemetry/
│   ├── demo.rb                         # Live Grafana metrics dashboard
│   ├── README.md
│   ├── SETUP_README.md
│   └── grafana/dashboards/htm-metrics.json
├── 11_robot_groups/
│   ├── same_process.rb                 # Single-process robot groups
│   ├── multi_process.rb                # Multi-process coordination
│   ├── robot_worker.rb                 # Worker process for multi_process.rb
│   └── lib/
│       ├── robot_group.rb              # RobotGroup coordination class
│       └── working_memory_channel.rb   # PostgreSQL pub/sub
└── 12_rails_app/
    ├── app/                            # Rails application files
    ├── config/                         # Rails configuration
    ├── Gemfile
    └── README.md
```

---

## Choosing the Right Example

| Use Case | Example |
|----------|---------|
| Database setup | `00_create_examples_db.rb` |
| Learning HTM basics | `01_basic_usage.rb` |
| Configuration management | `02_config_file_example/` |
| Custom LLM integration | `03_custom_llm_configuration.rb` |
| Loading documents/files | `04_file_loader_usage.rb` |
| Time-based queries | `05_timeframe_demo.rb` |
| Full-featured demo | `06_example_app/` |
| CLI tool | `07_cli_app/` |
| Web application | `08_sinatra_app/` |
| MCP client with chat | `09_mcp_client.rb` |
| Production observability | `10_telemetry/` |
| Multi-robot coordination | `11_robot_groups/` |
| Rails integration | `12_rails_app/` |
