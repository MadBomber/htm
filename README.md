<div align="center">
  <h1>HTM</h1>
  <!-- img src="docs/assets/images/htm.jpg" alt="HTM - Hierarchical Temporal Memory" width="600" -->
  <img src="docs/assets/images/htm_demo.gif" alt="HTM Demo" width="400">

  <p>Intelligent memory management for LLM-based applications. HTM implements a two-tier memory system with durable long-term storage and token-limited working memory, enabling robots to recall context from past conversations using RAG (Retrieval-Augmented Generation).</p>
</div>

<br/><br/>

> [!CAUTION]
> This library is under active development. APIs and features may change without notice. Not recommended for production use yet.
> <br /><br/>
> Apologies to Jeff Hawkins for using his term in such a macro-superficial way.

<br/><br/>

## Features

- **Intelligent Embeddings via [pgai](https://github.com/timescale/pgai)**
    - Automatic embedding generation in the database
    - No application-side HTTP calls for embeddings
    - Supports Ollama (local, default) and OpenAI
    - Database triggers handle INSERT/UPDATE automatically
    - 10-20% faster than Ruby-side generation

- **Two-Tier Memory Architecture**
    - Working Memory: Token-limited active context for immediate LLM use
    - Long-term Memory: Durable PostgreSQL/TimescaleDB storage

- **Never Forgets (Unless Told)**
    - All memories persist in long-term storage
    - Only explicit `forget()` commands delete data
    - Working memory evicts to long-term, never deletes

- **RAG-Based Retrieval**
    - Vector similarity search (pgvector + pgai)
    - Full-text search (PostgreSQL)
    - Hybrid search (combines both)
    - Temporal filtering ("last week", date ranges)
    - Variable embedding dimensions (384 to 3072)

- **Hive Mind**
    - All robots share global memory
    - Cross-robot context awareness
    - Track which robot said what

- **LLM-Driven Emergent Ontology**
    - Automatic hierarchical topic extraction from content
    - Topics in colon-delimited format (e.g., `database:postgresql:performance`)
    - LLM-powered via pgai triggers (follows embedding generation pattern)
    - Enables both structured navigation and semantic discovery
    - Complements vector embeddings (symbolic + sub-symbolic retrieval)

- **Knowledge Graph**
    - Relationship tracking between nodes
    - Tag-based categorization
    - Importance scoring

- **Time-Series Optimized**
    - TimescaleDB hypertables
    - Automatic compression for old data
    - Fast time-range queries

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'htm'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install htm
```

## Setup

### 1. Database Configuration

HTM uses TimescaleDB (PostgreSQL with time-series and AI extensions). Set up your database connection via environment variables:

```bash
# Preferred: Full connection URL
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"

# Alternative: Individual parameters
export HTM_DBNAME="tsdb"
export HTM_DBUSER="tsdbadmin"
export HTM_DBPASS="your_password"
export HTM_DBHOST="your-host.tsdb.cloud.timescale.com"
export HTM_DBPORT="37807"
```

See the [Environment Variables](#environment-variables) section below for complete details.

### 2. Enable pgai Extension

HTM uses [pgai](https://github.com/timescale/pgai) for intelligent embedding generation directly in the database.

```bash
# Enable pgai and configure for Ollama
ruby enable_extensions.rb

# Start Ollama and pull embedding model
ollama serve
ollama pull nomic-embed-text
```

**Note**: pgai is built-in on TimescaleDB Cloud. For self-hosted PostgreSQL, [install pgai](https://github.com/timescale/pgai#installation).

### 3. Initialize Database Schema

**Using Rake Tasks (Recommended)**:

HTM provides comprehensive rake tasks for database management. Add this to your application's `Rakefile`:

```ruby
require 'htm/tasks'
```

Then use the tasks:

```bash
# Set up database schema and run migrations
rake htm:db:setup

# Verify connection
rake htm:db:test

# Check database status
rake htm:db:info
```

**Or programmatically**:

```ruby
require 'htm'

# Run once to set up database schema with pgai triggers
HTM::Database.setup
```

**Or from command line**:

```bash
ruby -r ./lib/htm -e "HTM::Database.setup"
```

See [Using HTM Rake Tasks in Your Application](docs/using_rake_tasks_in_your_app.md) for complete integration guide.

### 4. Verify Setup

```bash
rake htm:db:test    # Using rake tasks
# or
ruby test_connection.rb
```

See [SETUP.md](SETUP.md) for detailed setup instructions and [PGAI_MIGRATION.md](PGAI_MIGRATION.md) for pgai configuration.

## Usage

### Basic Example

```ruby
require 'htm'

# Initialize HTM for your robot
# pgai handles embeddings automatically in the database
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000,       # tokens
  embedding_provider: :ollama,        # Uses pgai + Ollama (default)
  embedding_model: 'nomic-embed-text' # 768 dimensions (default)
)

# Add memories - pgai generates embeddings automatically in database!
# No application-side HTTP calls needed
htm.add_node(
  "decision_001",
  "We decided to use PostgreSQL for HTM storage",
  type: :decision,
  category: "architecture",
  importance: 9.0,
  tags: ["database", "architecture"]
)

# Recall from the past
memories = htm.recall(
  timeframe: "last week",
  topic: "database decisions"
)

# Create context for LLM
context = htm.create_context(strategy: :balanced)

# Forget (explicit deletion only)
htm.forget("old_decision", confirm: :confirmed)
```

### Memory Types

HTM supports different memory types:

- `:fact` - Immutable facts ("User's name is Dewayne")
- `:context` - Conversation state
- `:code` - Code snippets and patterns
- `:preference` - User preferences
- `:decision` - Architectural/design decisions
- `:question` - Unresolved questions

### Embedding Configuration

HTM supports multiple embedding providers. By default, it uses Ollama with the gpt-oss model:

#### Ollama (Default)

```ruby
# Default: Ollama with gpt-oss model (768 dimensions)
htm = HTM.new(robot_name: "My Robot")

# Explicit Ollama configuration
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  embedding_model: 'gpt-oss'
)

# Use different Ollama model
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  embedding_model: 'nomic-embed-text'  # 768 dimensions
)
```

**Ollama Setup:**
```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull gpt-oss model
ollama pull gpt-oss

# Verify Ollama is running
curl http://localhost:11434/api/version
```

#### OpenAI

```ruby
# OpenAI text-embedding-3-small (1536 dimensions)
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :openai,
  embedding_model: 'text-embedding-3-small'
)

# OpenAI text-embedding-3-large (3072 dimensions - exceeds HNSW limit)
# Note: text-embedding-3-large exceeds the 2000 dimension HNSW index limit
# and will raise a validation error

# OpenAI ada-002 (1536 dimensions)
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :openai,
  embedding_model: 'text-embedding-ada-002'
)
```

**OpenAI Setup:**
```bash
# Set your OpenAI API key
export OPENAI_API_KEY='sk-your-api-key-here'
```

#### Supported Models and Dimensions

HTM automatically detects embedding dimensions for known models:

| Provider | Model | Dimensions |
|----------|-------|------------|
| Ollama | gpt-oss | 768 |
| Ollama | nomic-embed-text | 768 |
| Ollama | all-minilm | 384 |
| Ollama | mxbai-embed-large | 1024 |
| OpenAI | text-embedding-3-small | 1536 |
| OpenAI | text-embedding-ada-002 | 1536 |
| Cohere | embed-english-v3.0 | 1024 (stub) |
| Local | all-MiniLM-L6-v2 | 384 (stub) |

**Important:** The database uses pgvector's HNSW index which has a maximum limit of 2000 dimensions. OpenAI's text-embedding-3-large (3072 dimensions) exceeds this limit and will raise a `HTM::ValidationError`.

#### Custom Dimensions

```ruby
# For custom or unknown models, specify dimensions explicitly
htm = HTM.new(
  robot_name: "My Robot",
  embedding_service: :ollama,
  embedding_model: 'my-custom-model',
  embedding_dimensions: 1024
)
```

### Recall Strategies

```ruby
# Vector similarity search (semantic) - uses Ollama embeddings
htm.recall(timeframe: "last week", topic: "HTM", strategy: :vector)

# Full-text search (keyword matching) - PostgreSQL full-text search
htm.recall(timeframe: "last month", topic: "database", strategy: :fulltext)

# Hybrid (combines both) - best of both worlds
htm.recall(timeframe: "yesterday", topic: "testing", strategy: :hybrid)
```

### Context Assembly

```ruby
# Recent memories first
context = htm.create_context(strategy: :recent)

# Most important memories
context = htm.create_context(strategy: :important)

# Balanced (importance × recency)
context = htm.create_context(strategy: :balanced)

# With token limit
context = htm.create_context(strategy: :balanced, max_tokens: 50_000)
```

### Hive Mind Queries

```ruby
# Which robot discussed a topic?
breakdown = htm.which_robot_said("PostgreSQL")
# => { "robot-123" => 15, "robot-456" => 8 }

# Get conversation timeline
timeline = htm.conversation_timeline("HTM design", limit: 50)
# => [{ timestamp: ..., robot: "...", content: "...", type: :decision }, ...]
```

### Memory Statistics

```ruby
stats = htm.memory_stats
# => {
#   total_nodes: 1234,
#   nodes_by_robot: { "robot-1" => 800, "robot-2" => 434 },
#   working_memory: { current_tokens: 45000, max_tokens: 128000, utilization: 35.16 },
#   database_size: 52428800,  # bytes
#   ...
# }
```

## Environment Variables

HTM uses environment variables for database and service configuration. These can be set in your shell profile, a `.env` file, or exported directly.

### Database Configuration

#### HTM_DBURL (Recommended)

The preferred method for database configuration is a single connection URL:

```bash
export HTM_DBURL="postgresql://username:password@host:port/dbname?sslmode=require"
```

**Format:** `postgresql://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=MODE`

**Example for TimescaleDB Cloud:**
```bash
export HTM_DBURL="postgresql://tsdbadmin:mypassword@abc123.tsdb.cloud.timescale.com:37807/tsdb?sslmode=require"
```

**Example for Local PostgreSQL:**
```bash
export HTM_DBURL="postgresql://postgres:postgres@localhost:5432/htm_dev?sslmode=disable"
```

#### Individual Database Parameters (Alternative)

If `HTM_DBURL` is not set, HTM will use individual parameters:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HTM_DBNAME` | Database name | None | Yes |
| `HTM_DBUSER` | Database username | None | Yes |
| `HTM_DBPASS` | Database password | None | Yes |
| `HTM_DBHOST` | Database hostname or IP | `cw7rxj91bm.srbbwwxn56.tsdb.cloud.timescale.com` | No |
| `HTM_DBPORT` | Database port | `37807` | No |
| `HTM_SERVICE_NAME` | Service identifier (informational only) | None | No |

**Example:**
```bash
export HTM_DBNAME="tsdb"
export HTM_DBUSER="tsdbadmin"
export HTM_DBPASS="secure_password_here"
export HTM_DBHOST="myservice.tsdb.cloud.timescale.com"
export HTM_DBPORT="37807"
export HTM_SERVICE_NAME="production-db"
```

**Configuration Priority:**
1. `HTM_DBURL` (if set, this takes precedence)
2. Individual parameters (`HTM_DBNAME`, `HTM_DBUSER`, etc.)
3. Direct configuration passed to `HTM.new(db_config: {...})`

### Embedding Service Configuration

#### OPENAI_API_KEY

Required when using OpenAI as your embedding provider:

```bash
export OPENAI_API_KEY="sk-proj-your-api-key-here"
```

This is required for:
- `embedding_service: :openai`
- Models: `text-embedding-3-small`, `text-embedding-ada-002`

#### OLLAMA_URL

Custom Ollama server URL (optional):

```bash
export OLLAMA_URL="http://localhost:11434"  # Default
export OLLAMA_URL="http://ollama-server:11434"  # Custom
```

If not set, HTM defaults to `http://localhost:11434`.

### Topic Extraction Configuration

HTM automatically extracts hierarchical topics from node content using LLM-powered analysis via pgai. Configure the topic extraction behavior with these environment variables:

#### HTM_TOPIC_PROVIDER

Which LLM provider to use for topic extraction:

```bash
export HTM_TOPIC_PROVIDER="ollama"  # Default (local, recommended)
export HTM_TOPIC_PROVIDER="openai"  # Cloud-based (requires API key)
```

#### HTM_TOPIC_MODEL

Which model to use for topic extraction:

```bash
# For Ollama (default)
export HTM_TOPIC_MODEL="llama3"

# For OpenAI
export HTM_TOPIC_MODEL="gpt-4-turbo"
```

#### HTM_TOPIC_BASE_URL

LLM service endpoint:

```bash
export HTM_TOPIC_BASE_URL="http://localhost:11434"  # Default Ollama
export HTM_TOPIC_BASE_URL="http://ollama-server:11434"  # Custom Ollama server
```

#### Embedding Configuration

Similarly, configure embedding generation:

```bash
# Embedding provider and model
export HTM_EMBEDDINGS_PROVIDER="ollama"  # Default
export HTM_EMBEDDINGS_MODEL="nomic-embed-text"  # Default
export HTM_EMBEDDINGS_BASE_URL="http://localhost:11434"
export HTM_EMBEDDINGS_DIMENSION="768"  # Optional, auto-detected
```

### Quick Setup Examples

#### TimescaleDB Cloud

```bash
# Option 1: Single URL (recommended)
export HTM_DBURL="postgresql://tsdbadmin:PASSWORD@SERVICE.tsdb.cloud.timescale.com:37807/tsdb?sslmode=require"

# Option 2: Individual parameters
export HTM_SERVICE_NAME="my-service"
export HTM_DBNAME="tsdb"
export HTM_DBUSER="tsdbadmin"
export HTM_DBPASS="your_password"
export HTM_DBHOST="abc123.tsdb.cloud.timescale.com"
export HTM_DBPORT="37807"
```

#### Local Development (PostgreSQL/TimescaleDB)

```bash
# Simple local setup
export HTM_DBURL="postgresql://postgres:postgres@localhost:5432/htm_dev?sslmode=disable"

# With custom user
export HTM_DBURL="postgresql://myuser:mypass@localhost:5432/htm_dev"
```

#### With OpenAI Embeddings

```bash
# Database + OpenAI
export HTM_DBURL="postgresql://user:pass@host:port/db?sslmode=require"
export OPENAI_API_KEY="sk-proj-your-api-key-here"
```

### Persistent Configuration

To make environment variables permanent, add them to your shell profile:

**For Bash (~/.bashrc or ~/.bash_profile):**
```bash
echo 'export HTM_DBURL="postgresql://user:pass@host:port/db?sslmode=require"' >> ~/.bashrc
source ~/.bashrc
```

**For Zsh (~/.zshrc):**
```bash
echo 'export HTM_DBURL="postgresql://user:pass@host:port/db?sslmode=require"' >> ~/.zshrc
source ~/.zshrc
```

**Or create a dedicated file (~/.bashrc__htm):**
```bash
# ~/.bashrc__htm
export HTM_DBURL="postgresql://user:pass@host:port/db?sslmode=require"
export OPENAI_API_KEY="sk-proj-your-api-key"
export HTM_SERVICE_NAME="my-service"

# Then source it from your main profile
echo 'source ~/.bashrc__htm' >> ~/.bashrc
```

### Verification

Verify your configuration:

```bash
# Check database connection
ruby test_connection.rb

# Or in Ruby
irb -r ./lib/htm
> HTM::Database.default_config
> # Should return a hash with your connection parameters
```

## Development

After checking out the repo, run:

```bash
# Install dependencies
bundle install

# Enable direnv (loads .envrc environment variables)
direnv allow

# Run tests
rake test

# Run example
ruby examples/basic_usage.rb
```

### Database Management

HTM provides comprehensive rake tasks under the `htm:db` namespace for managing the database:

```bash
# List all database tasks
rake -T htm:db

# Set up database (create schema + run migrations)
rake htm:db:setup

# Run pending migrations only
rake htm:db:migrate

# Show migration status (which migrations are applied)
rake htm:db:status

# Show database info (size, tables, extensions, row counts)
rake htm:db:info

# Test database connection
rake htm:db:test

# Open PostgreSQL console (interactive psql session)
rake htm:db:console

# Seed database with sample data
rake htm:db:seed

# Drop all HTM tables (WARNING: destructive!)
rake htm:db:drop

# Drop and recreate database (WARNING: destructive!)
rake htm:db:reset
```

**Important**: Make sure `direnv allow` has been run once in the project directory to load database environment variables from `.envrc`. Alternatively, you can manually export the environment variables:

```bash
# Source Tiger database credentials (if using TimescaleDB Cloud)
source ~/.bashrc__tiger

# Or manually export HTM_DBURL
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"
```

**Common Workflows**:

```bash
# Initial setup (first time)
direnv allow
rake htm:db:setup        # Creates schema and runs migrations

# After pulling new migrations
rake htm:db:migrate      # Run pending migrations

# Check database state
rake htm:db:status       # See migration status
rake htm:db:info         # See database details

# Reset database (development only!)
rake htm:db:reset        # Drops and recreates everything

# Open database console for debugging
rake htm:db:console      # Opens psql
```

## Testing

HTM uses Minitest:

```bash
# Run all tests
rake test

# Run specific test file
ruby test/htm_test.rb
```

## Architecture

See [htm_teamwork.md](htm_teamwork.md) for detailed design documentation and planning notes.

### Key Components

- **HTM**: Main API, coordinates all components
- **WorkingMemory**: In-memory, token-limited active context
- **LongTermMemory**: PostgreSQL-backed permanent storage with connection pooling
- **EmbeddingService**: Vector embedding generation (Ollama, OpenAI, Cohere, Local)
- **Database**: Schema setup, migrations, and management

### Database Schema

- `nodes`: Main memory storage with vector embeddings
- `relationships`: Knowledge graph connections
- `tags`: Flexible categorization
- `operations_log`: Audit trail (hypertable)
- `robots`: Robot registry

## Roadmap

- [x] Phase 1: Foundation (basic two-tier memory)
- [ ] Phase 2: RAG retrieval (semantic search)
- [ ] Phase 3: Relationships & tags
- [ ] Phase 4: Working memory management
- [ ] Phase 5: Hive mind features
- [ ] Phase 6: Operations & observability
- [ ] Phase 7: Advanced features
- [ ] Phase 8: Production-ready gem


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/madbomber/htm.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
