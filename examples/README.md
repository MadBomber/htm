# HTM Examples

This directory contains example applications demonstrating various ways to use the HTM (Hierarchical Temporary Memory) gem.

## Prerequisites

All examples require:

1. **PostgreSQL Database** with pgvector extension:
   ```bash
   export HTM_DBURL="postgresql://user@localhost:5432/htm_development"
   ```

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
- `HTM_DBURL` - PostgreSQL connection (required)
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
| Web application | `sinatra_app/` |
| CLI tool | `cli_app/` |
| Multi-robot coordination | `robot_groups/` |
| High availability | `robot_groups/` |
