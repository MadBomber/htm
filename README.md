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

- **Client-Side Embeddings**
    - Automatic embedding generation before database insertion
    - Supports Ollama (local, default) and OpenAI
    - Configurable embedding providers and models

- **Two-Tier Memory Architecture**
    - Working Memory: Token-limited active context for immediate LLM use
    - Long-term Memory: Durable PostgreSQL storage

- **Never Forgets (Unless Told)**
    - All memories persist in long-term storage
    - Only explicit `forget()` commands delete data
    - Working memory evicts to long-term, never deletes

- **RAG-Based Retrieval**
    - Vector similarity search (pgvector)
    - Full-text search (PostgreSQL)
    - Hybrid search (combines both)
    - Temporal filtering ("last week", date ranges)
    - Variable embedding dimensions (384 to 3072)

- **Hive Mind**
    - All robots share global memory
    - Cross-robot context awareness
    - Track which robot said what

- **LLM-Driven Tag Extraction**
    - Automatic hierarchical tag extraction from content
    - Tags in colon-delimited format (e.g., `database:postgresql:performance`)
    - LLM-powered asynchronous processing
    - Enables both structured navigation and semantic discovery
    - Complements vector embeddings (symbolic + sub-symbolic retrieval)

- **Knowledge Graph**
    - Tag-based categorization
    - Hierarchical tag structures

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

HTM uses PostgreSQL for durable long-term memory storage. Set up your database connection via environment variables:

```bash
# Preferred: Full connection URL
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"

# Alternative: Individual parameters
export HTM_DBNAME="htm_production"
export HTM_DBUSER="postgres"
export HTM_DBPASS="your_password"
export HTM_DBHOST="localhost"
export HTM_DBPORT="5432"
```

See the [Environment Variables](#environment-variables) section below for complete details.

### 2. Configure LLM Providers

HTM uses LLM providers for embedding generation and tag extraction. By default, it uses Ollama (local).

**Start Ollama (Default Configuration)**:
```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Start Ollama and pull models
ollama serve
ollama pull nomic-embed-text  # For embeddings (768 dimensions)
ollama pull llama3           # For tag extraction
```

**Configure HTM** (optional - uses defaults if not configured):
```ruby
require 'htm'

# Use defaults (Ollama with nomic-embed-text and llama3)
HTM.configure

# Or customize providers
HTM.configure do |config|
  # Embedding configuration
  config.embedding_provider = :ollama  # or :openai
  config.embedding_model = 'nomic-embed-text'
  config.embedding_dimensions = 768
  config.ollama_url = 'http://localhost:11434'

  # Tag extraction configuration
  config.tag_provider = :ollama  # or :openai
  config.tag_model = 'llama3'

  # Logger configuration (optional)
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO

  # Custom embedding generator (advanced)
  config.embedding_generator = ->(text) {
    # Your custom implementation
    # Must return Array<Float>
  }

  # Custom tag extractor (advanced)
  config.tag_extractor = ->(text, ontology) {
    # Your custom implementation
    # Must return Array<String>
  }

  # Token counter (optional, defaults to Tiktoken)
  config.token_counter = ->(text) {
    # Your custom implementation
    # Must return Integer
  }
end
```

See the [Configuration](#configuration) section below for complete details.

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

# Run once to set up database schema
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

See [docs/setup_local_database.md](docs/setup_local_database.md) for detailed local database setup instructions.

## Usage

### Basic Example

```ruby
require 'htm'
require 'ruby_llm'
require 'logger'

# Configure HTM with RubyLLM for embeddings and tag extraction
HTM.configure do |config|
  # Configure logger (optional - uses STDOUT at INFO level if not provided)
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO

  # Configure embedding generation using RubyLLM with Ollama
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'
  config.embedding_dimensions = 768
  config.ollama_url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

  # Configure tag extraction using RubyLLM with Ollama
  config.tag_provider = :ollama
  config.tag_model = 'llama3'

  # Apply configuration (sets up default RubyLLM implementations)
  config.reset_to_defaults
end

# Initialize HTM for your robot
htm = HTM.new(
  robot_name: "Code Helper",
  working_memory_size: 128_000  # tokens
)

# Remember information - embeddings and tags generated asynchronously
node_id = htm.remember(
  "We decided to use PostgreSQL for HTM storage",
  source: "architect"
)

# Recall from the past (uses semantic search with embeddings)
memories = htm.recall(
  "database decisions",
  timeframe: "last week",
  strategy: :hybrid  # Combines vector + full-text search
)

# Forget (explicit deletion only)
htm.forget(node_id, confirm: :confirmed)
```

### Automatic Tag Extraction

HTM automatically extracts hierarchical tags from content using LLM analysis. Tags are inferred from the content itself - you never specify them manually.

**Example:**
```ruby
htm.remember(
  "User prefers dark mode for all interfaces",
  source: "user"
)
# Tags like "preference", "ui", "dark-mode" may be auto-extracted by the LLM
# The specific tags depend on the LLM's analysis of the content
```

### Async Job Processing

HTM automatically generates embeddings and extracts tags asynchronously in background jobs. This avoids blocking the main request path.

**Monitor job processing:**
```bash
# Show statistics for nodes and async processing
rake htm:jobs:stats

# Output:
# Total nodes: 150
# Nodes with embeddings: 145 (96.7%)
# Nodes without embeddings: 5 (3.3%)
# Nodes with tags: 140 (93.3%)
# Total tags in ontology: 42
```

**Process pending jobs manually:**
```bash
# Process all pending embedding jobs
rake htm:jobs:process_embeddings

# Process all pending tag extraction jobs
rake htm:jobs:process_tags

# Process both embeddings and tags
rake htm:jobs:process_all
```

**Reprocess all nodes (force regeneration):**
```bash
# Regenerate embeddings for ALL nodes
rake htm:jobs:reprocess_embeddings

# WARNING: Prompts for confirmation
```

**Show failed/stuck jobs:**
```bash
# Show nodes that failed async processing (>1 hour old without embeddings/tags)
rake htm:jobs:failed
```

**Clear all for testing:**
```bash
# Clear ALL embeddings and tags (development/testing only)
rake htm:jobs:clear_all

# WARNING: Prompts for confirmation
```

See `rake -T htm:jobs` for complete list of job management tasks.

## Configuration

HTM uses dependency injection for LLM access, allowing you to configure embedding generation, tag extraction, logging, and token counting.

### Default Configuration

By default, HTM uses:
- **Embedding Provider**: Ollama (local) with `nomic-embed-text` model (768 dimensions)
- **Tag Provider**: Ollama (local) with `llama3` model
- **Logger**: Ruby's standard Logger to STDOUT at INFO level
- **Token Counter**: Tiktoken with GPT-3.5-turbo encoding

```ruby
require 'htm'

# Use defaults
HTM.configure  # or omit this - configuration is lazy-loaded
```

### Custom Configuration

Configure HTM before creating instances:

#### Using Ollama (Default)

```ruby
HTM.configure do |config|
  # Embedding configuration
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'  # 768 dimensions
  config.embedding_dimensions = 768
  config.ollama_url = 'http://localhost:11434'

  # Tag extraction configuration
  config.tag_provider = :ollama
  config.tag_model = 'llama3'

  # Logger configuration
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO
end
```

**Ollama Setup:**
```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull models
ollama pull nomic-embed-text  # For embeddings
ollama pull llama3           # For tag extraction

# Verify Ollama is running
curl http://localhost:11434/api/version
```

#### Using OpenAI

```ruby
HTM.configure do |config|
  # Embedding configuration (OpenAI)
  config.embedding_provider = :openai
  config.embedding_model = 'text-embedding-3-small'  # 1536 dimensions
  config.embedding_dimensions = 1536

  # Tag extraction (can mix providers)
  config.tag_provider = :openai
  config.tag_model = 'gpt-4'

  # Logger
  config.logger = Rails.logger  # Use Rails logger
end
```

**OpenAI Setup:**
```bash
# Set your OpenAI API key
export OPENAI_API_KEY='sk-your-api-key-here'
```

**Important:** The database uses pgvector with HNSW indexing, which has a maximum dimension limit of 2000. Embeddings exceeding this limit will be automatically truncated with a warning.

#### Custom Providers

Provide your own LLM implementations:

```ruby
HTM.configure do |config|
  # Custom embedding generator
  config.embedding_generator = ->(text) {
    # Call your custom LLM service
    response = MyEmbeddingService.generate(text)

    # Must return Array<Float>
    response[:embedding]  # e.g., [0.123, -0.456, ...]
  }

  # Custom tag extractor
  config.tag_extractor = ->(text, existing_ontology) {
    # Call your custom LLM service for tag extraction
    # existing_ontology is Array<String> of recent tags for context
    response = MyTagService.extract(text, context: existing_ontology)

    # Must return Array<String> in hierarchical format
    # e.g., ["ai:llm:embeddings", "database:postgresql"]
    response[:tags]
  }

  # Custom token counter (optional)
  config.token_counter = ->(text) {
    # Your token counting implementation
    # Must return Integer
    MyTokenizer.count(text)
  }
end
```

#### Logger Configuration

Customize logging behavior:

```ruby
HTM.configure do |config|
  # Use custom logger
  config.logger = Logger.new('log/htm.log')
  config.logger.level = Logger::DEBUG

  # Or use Rails logger
  config.logger = Rails.logger

  # Or disable logging
  config.logger = Logger.new(IO::NULL)
  config.logger.level = Logger::FATAL
end

# Control log level via environment variable
ENV['HTM_LOG_LEVEL'] = 'DEBUG'  # or INFO, WARN, ERROR
HTM.configure  # Respects HTM_LOG_LEVEL
```

#### Service Layer Architecture

HTM uses a service layer to process LLM responses:

- **EmbeddingService**: Calls your configured `embedding_generator`, validates responses, handles padding/truncation, and formats for storage
- **TagService**: Calls your configured `tag_extractor`, parses responses (String or Array), validates format, and filters invalid tags

This separation allows you to provide raw LLM access while HTM handles response processing, validation, and storage formatting.

### Recall Strategies

HTM supports three retrieval strategies:

```ruby
# Vector similarity search (semantic) - uses configured embedding provider
memories = htm.recall(
  "HTM architecture",
  timeframe: "last week",
  strategy: :vector  # Semantic similarity using embeddings
)

# Full-text search (keyword matching) - PostgreSQL full-text search with trigrams
memories = htm.recall(
  "database performance",
  timeframe: "last month",
  strategy: :fulltext  # Keyword-based matching
)

# Hybrid (combines both) - best of both worlds
memories = htm.recall(
  "testing strategies",
  timeframe: "yesterday",
  strategy: :hybrid  # Weighted combination of vector + full-text
)
```

**Strategy Details:**
- `:vector` - Semantic search using pgvector cosine similarity (requires embeddings)
- `:fulltext` - PostgreSQL tsvector with pg_trgm fuzzy matching
- `:hybrid` - Combines both with weighted scoring (default: 70% vector, 30% full-text)

## API Reference

HTM provides a minimal, focused API with only 3 core instance methods for memory operations:

### Core Memory Operations

#### `remember(content, source: "")`

Store information in memory. Embeddings and tags are automatically generated asynchronously.

**Parameters:**
- `content` (String, required) - The information to remember. Converted to string if nil. Returns ID of last node if empty.
- `source` (String, optional) - Where the content came from (e.g., "user", "assistant", "system"). Defaults to empty string.

**Returns:** Integer - The node ID of the stored memory

**Example:**
```ruby
# Store with source
node_id = htm.remember("PostgreSQL is excellent for vector search with pgvector", source: "architect")

# Store without source (uses default empty string)
node_id = htm.remember("HTM uses two-tier memory architecture")

# Nil/empty handling
node_id = htm.remember(nil)  # Returns ID of last node without creating duplicate
node_id = htm.remember("")   # Returns ID of last node without creating duplicate
```

---

#### `recall(topic, timeframe: nil, limit: 20, strategy: :vector, with_relevance: false, query_tags: [])`

Retrieve memories using temporal filtering and semantic/keyword search.

**Parameters:**
- `topic` (String, required) - Query text for semantic/keyword matching (first positional argument)
- `timeframe` (Range, String, optional) - Time range to search within. Default: "last 7 days"
  - Range: `(Time.now - 3600)..Time.now`
  - String: `"last hour"`, `"last week"`, `"yesterday"`
- `limit` (Integer, optional) - Maximum number of results. Default: 20
- `strategy` (Symbol, optional) - Search strategy. Default: `:vector`
  - `:vector` - Semantic search using embeddings (cosine similarity)
  - `:fulltext` - Keyword search using PostgreSQL full-text + trigrams
  - `:hybrid` - Weighted combination (70% vector, 30% full-text)
- `with_relevance` (Boolean, optional) - Include dynamic relevance scores. Default: false
- `query_tags` (Array<String>, optional) - Filter results by tags. Default: []

**Returns:** Array<Hash> - Matching memories with fields: `id`, `content`, `source`, `created_at`, `access_count`, (optionally `relevance`)

**Example:**
```ruby
# Basic recall with time range
memories = htm.recall(
  "database architecture",
  timeframe: (Time.now - 86400)..Time.now
)

# Using human-readable timeframe
memories = htm.recall(
  "PostgreSQL performance",
  timeframe: "last week",
  strategy: :hybrid,
  limit: 10
)

# With relevance scoring
memories = htm.recall(
  "HTM design decisions",
  timeframe: "last month",
  with_relevance: true,
  query_tags: ["architecture"]
)
# => [{ "id" => 123, "content" => "...", "relevance" => 0.92, ... }, ...]
```

---

#### `forget(node_id, confirm: false)`

Permanently delete a memory from both working memory and long-term storage.

**Parameters:**
- `node_id` (Integer, required) - The ID of the node to delete
- `confirm` (Symbol, Boolean, required) - Must be `:confirmed` or `true` to proceed

**Returns:** Boolean - `true` if deleted, `false` if not found

**Safety:** This is the ONLY way to delete memories. Requires explicit confirmation to prevent accidental deletion.

**Example:**
```ruby
# Delete with symbol confirmation (recommended)
htm.forget(node_id, confirm: :confirmed)

# Delete with boolean confirmation
htm.forget(node_id, confirm: true)

# Will raise error - confirmation required
htm.forget(node_id)  # ArgumentError: Must confirm deletion
htm.forget(node_id, confirm: false)  # ArgumentError: Must confirm deletion
```

---

### Complete Usage Example

```ruby
require 'htm'

# Configure once globally (optional - uses defaults if not called)
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'
  config.tag_provider = :ollama
  config.tag_model = 'llama3'
end

# Initialize for your robot
htm = HTM.new(robot_name: "Assistant", working_memory_size: 128_000)

# Store information
htm.remember("PostgreSQL with pgvector for vector search", source: "architect")
htm.remember("User prefers dark mode", source: "user")
htm.remember("Use debug_me for debugging, not puts", source: "system")

# Retrieve by time + topic
recent = htm.recall(
  "PostgreSQL",
  timeframe: "last week",
  strategy: :hybrid,
  limit: 5
)

# Delete if needed (requires node ID from remember or recall)
htm.forget(node_id, confirm: :confirmed)
```

## Use with Rails

HTM is designed to integrate seamlessly with Ruby on Rails applications. It uses ActiveRecord models and follows Rails conventions, making it easy to add AI memory capabilities to existing Rails apps.

### Why HTM Works Well with Rails

**1. Uses ActiveRecord**
- HTM models are standard ActiveRecord classes with associations, validations, and scopes
- Follows Rails naming conventions and patterns
- Models are namespaced under `HTM::Models::` to avoid conflicts

**2. Standard Rails Configuration**
- Uses `config/database.yml` (Rails convention)
- Respects `RAILS_ENV` environment variable
- Supports ERB in configuration files

**3. Separate Database**
- HTM uses its own PostgreSQL database connection
- Won't interfere with your Rails app's database
- Configured with `prepared_statements: false` and `advisory_locks: false` for compatibility
- Thread-safe for Rails multi-threading

**4. Connection Management**
- Separate connection pool from your Rails app
- Configurable pool size and timeouts
- Proper cleanup and disconnection support

### Integration Steps

#### 1. Add to Gemfile

```ruby
gem 'htm'
```

Then run:
```bash
bundle install
```

#### 2. Configure Environment Variables

Add HTM database configuration to your Rails environment. You can use `.env` files (with `dotenv-rails`) or set them directly:

```ruby
# .env or config/application.rb
HTM_DBURL=postgresql://user:pass@localhost:5432/htm_production
```

Or use individual variables:
```ruby
HTM_DBHOST=localhost
HTM_DBNAME=htm_production
HTM_DBUSER=postgres
HTM_DBPASS=password
HTM_DBPORT=5432
```

#### 3. Create Initializer

Create `config/initializers/htm.rb`:

```ruby
# config/initializers/htm.rb

# Configure HTM
HTM.configure do |config|
  # Use Rails logger
  config.logger = Rails.logger

  # Embedding configuration (optional - uses Ollama defaults if not set)
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'

  # Tag extraction configuration (optional - uses Ollama defaults if not set)
  config.tag_provider = :ollama
  config.tag_model = 'llama3'

  # Custom providers (optional)
  # config.embedding_generator = ->(text) { YourEmbeddingService.call(text) }
  # config.tag_extractor = ->(text, ontology) { YourTagService.call(text, ontology) }
end

# Establish HTM database connection
HTM::ActiveRecordConfig.establish_connection!

# Verify required PostgreSQL extensions are installed
HTM::ActiveRecordConfig.verify_extensions!

Rails.logger.info "HTM initialized with database: #{HTM::Database.default_config[:database]}"
```

#### 4. Set Up Database

Run the HTM database setup:

```bash
# Using HTM rake tasks
rake htm:db:setup

# Or manually in Rails console
rails c
> HTM::Database.setup
```

#### 5. Use in Your Rails App

**In Controllers:**

```ruby
class ChatsController < ApplicationController
  before_action :initialize_memory

  def create
    # Add user message to memory (embeddings + tags auto-extracted asynchronously)
    @memory.remember(
      params[:message],
      source: "user-#{current_user.id}"
    )

    # Recall relevant context for the conversation
    context = @memory.create_context(strategy: :balanced)

    # Use context with your LLM to generate response
    response = generate_llm_response(context, params[:message])

    # Store assistant's response
    @memory.remember(
      response,
      source: "assistant"
    )

    render json: { response: response }
  end

  private

  def initialize_memory
    @memory = HTM.new(
      robot_name: "ChatBot-#{current_user.id}",
      working_memory_size: 128_000
    )
  end
end
```

**In Background Jobs:**

```ruby
class ProcessDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)

    # Initialize HTM for this job
    memory = HTM.new(robot_name: "DocumentProcessor")

    # Store document content in memory (embeddings + tags auto-extracted asynchronously)
    memory.remember(
      document.content,
      source: "document-#{document.id}"
    )

    # Recall related documents (uses vector similarity)
    related = memory.recall(
      document.category,
      timeframe: "last month",
      strategy: :vector
    )

    # Process with context...
  end
end
```

**In Models (as a concern):**

```ruby
# app/models/concerns/memorable.rb
module Memorable
  extend ActiveSupport::Concern

  included do
    after_create :store_in_memory
    after_update :update_memory
  end

  def store_in_memory
    memory = HTM.new(robot_name: "Rails-#{Rails.env}")

    memory.remember(
      memory_content,
      source: "#{self.class.name}-#{id}"
    )
  end

  def update_memory
    # Update existing memory node
    store_in_memory
  end

  private

  def memory_content
    # Override in model to customize what gets stored
    attributes.to_json
  end
end

# Then in your model:
class Article < ApplicationRecord
  include Memorable

  private

  def memory_content
    "Article: #{title}\n\n#{body}\n\nCategory: #{category}"
  end
end
```

### Multi-Database Configuration (Rails 6+)

If you want to use Rails' built-in multi-database support, you can configure HTM in your `config/database.yml`:

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: myapp_production

  htm:
    adapter: postgresql
    encoding: unicode
    database: <%= ENV['HTM_DBNAME'] || 'htm_production' %>
    host: <%= ENV['HTM_DBHOST'] || 'localhost' %>
    port: <%= ENV['HTM_DBPORT'] || 5432 %>
    username: <%= ENV['HTM_DBUSER'] || 'postgres' %>
    password: <%= ENV['HTM_DBPASS'] %>
    pool: <%= ENV['HTM_DB_POOL_SIZE'] || 10 %>
```

Then update your HTM initializer:

```ruby
# config/initializers/htm.rb
HTM::ActiveRecordConfig.establish_connection!

# Or use Rails' connection
# ActiveRecord::Base.connected_to(role: :writing, shard: :htm) do
#   HTM::ActiveRecordConfig.verify_extensions!
# end
```

### Testing with Rails

**In RSpec:**

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.before(:suite) do
    HTM::ActiveRecordConfig.establish_connection!
  end

  config.after(:suite) do
    HTM::ActiveRecordConfig.disconnect!
  end
end

# spec/features/chat_spec.rb
RSpec.describe "Chat with memory", type: :feature do
  let(:memory) { HTM.new(robot_name: "TestBot") }

  before do
    memory.remember("User prefers Ruby over Python", source: "user")
  end

  it "recalls user preferences" do
    context = memory.create_context(strategy: :balanced)
    expect(context).to include("Ruby")
  end
end
```

**In Minitest:**

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  setup do
    HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?
  end
end

# test/integration/chat_test.rb
class ChatTest < ActionDispatch::IntegrationTest
  test "stores chat messages in memory" do
    memory = HTM.new(robot_name: "TestBot")

    post chats_path, params: { message: "Hello!" }

    assert_response :success

    # Verify message was stored
    nodes = memory.recall("Hello", timeframe: "last hour")
    assert_not_empty nodes
  end
end
```

### Production Considerations

1. **Connection Pooling**: Set appropriate pool size based on your Rails app's concurrency:
   ```ruby
   ENV['HTM_DB_POOL_SIZE'] = '20'  # Match or exceed Rails pool
   ```

2. **Separate Database Server**: For production, use a dedicated PostgreSQL instance for HTM

3. **Required Extensions**: Ensure `pgvector` and `pg_trgm` extensions are installed on your PostgreSQL server

4. **Memory Management**: HTM's working memory is per-instance. Consider using a singleton pattern or Rails cache for shared instances

5. **Background Processing**: Use Sidekiq or similar for embedding generation if processing large amounts of data

### Example Rails App Structure

```
app/
├── controllers/
│   └── chats_controller.rb        # Uses HTM for conversation memory
├── jobs/
│   └── process_document_job.rb    # Background HTM processing
├── models/
│   ├── concerns/
│   │   └── memorable.rb           # HTM integration concern
│   └── article.rb                 # Includes Memorable
└── services/
    └── memory_service.rb          # Centralized HTM access

config/
├── initializers/
│   └── htm.rb                     # HTM setup
└── database.yml                   # Optional: multi-database config

.env
  HTM_DBURL=postgresql://...       # HTM database connection
  OPENAI_API_KEY=sk-...            # If using OpenAI embeddings
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
| `HTM_DBHOST` | Database hostname or IP | `localhost` | No |
| `HTM_DBPORT` | Database port | `5432` | No |
| `HTM_SERVICE_NAME` | Service identifier (informational only) | None | No |

**Example:**
```bash
export HTM_DBNAME="htm_production"
export HTM_DBUSER="postgres"
export HTM_DBPASS="secure_password_here"
export HTM_DBHOST="localhost"
export HTM_DBPORT="5432"
export HTM_SERVICE_NAME="production-db"
```

**Configuration Priority:**
1. `HTM_DBURL` (if set, this takes precedence)
2. Individual parameters (`HTM_DBNAME`, `HTM_DBUSER`, etc.)
3. Direct configuration passed to `HTM.new(db_config: {...})`

### LLM Provider Configuration

HTM configuration is done programmatically via `HTM.configure` (see [Configuration](#configuration) section). However, a few environment variables are still used:

#### OPENAI_API_KEY

Required when using OpenAI as your embedding or tag extraction provider:

```bash
export OPENAI_API_KEY="sk-proj-your-api-key-here"
```

This is required when you configure:
```ruby
HTM.configure do |config|
  config.embedding_provider = :openai
  # or
  config.tag_provider = :openai
end
```

#### OLLAMA_URL

Custom Ollama server URL (optional):

```bash
export OLLAMA_URL="http://localhost:11434"  # Default
export OLLAMA_URL="http://ollama-server:11434"  # Custom
```

HTM defaults to `http://localhost:11434` if not set.

#### HTM_LOG_LEVEL

Control logging verbosity:

```bash
export HTM_LOG_LEVEL="DEBUG"  # DEBUG, INFO, WARN, ERROR, FATAL
export HTM_LOG_LEVEL="INFO"   # Default
```

This is used by the default logger when `HTM.configure` is called without a custom logger.

### Quick Setup Examples

#### Local Development (PostgreSQL)

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
# Manually export HTM_DBURL
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

### Async Job Management

HTM provides rake tasks under the `htm:jobs` namespace for managing async embedding and tag extraction jobs:

```bash
# List all job management tasks
rake -T htm:jobs

# Show statistics for async processing
rake htm:jobs:stats

# Process pending jobs
rake htm:jobs:process_embeddings    # Process nodes without embeddings
rake htm:jobs:process_tags          # Process nodes without tags
rake htm:jobs:process_all           # Process both

# Reprocess all nodes (force regeneration)
rake htm:jobs:reprocess_embeddings  # WARNING: Prompts for confirmation

# Debugging and maintenance
rake htm:jobs:failed                # Show stuck jobs (>1 hour old)
rake htm:jobs:clear_all            # Clear all embeddings/tags (testing only)
```

**Common Workflows**:

```bash
# Monitor async processing
rake htm:jobs:stats

# Manually process pending jobs (if async job runner is not running)
rake htm:jobs:process_all

# Debug stuck jobs
rake htm:jobs:failed
rake htm:jobs:process_embeddings    # Retry failed embeddings

# Development/testing: force regeneration
rake htm:jobs:reprocess_embeddings  # Regenerate all embeddings
rake htm:jobs:clear_all             # Clear everything and start fresh
```

See the [Async Job Processing](#async-job-processing) section for more details.

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

- **HTM**: Main API class that coordinates all components and provides the primary interface
- **Configuration**: Dependency injection for LLM providers (embedding_generator, tag_extractor, token_counter, logger)
- **WorkingMemory**: In-memory, token-limited active context for immediate LLM use
- **LongTermMemory**: PostgreSQL-backed permanent storage with connection pooling
- **EmbeddingService**: Processing and validation layer for vector embeddings (calls configured `embedding_generator`)
- **TagService**: Processing and validation layer for hierarchical tags (calls configured `tag_extractor`)
- **Database**: Schema setup, migrations, and management
- **Background Jobs**: Async processing for embedding generation and tag extraction

### Database Schema

- `robots`: Robot registry for all LLM agents using HTM
- `nodes`: Main memory storage with vector embeddings (pgvector), full-text search (tsvector), metadata
- `tags`: Hierarchical tag ontology (format: `root:level1:level2:level3`)
- `node_tags`: Join table implementing many-to-many relationship between nodes and tags

### Service Architecture

HTM uses a layered architecture for LLM integration:

1. **Configuration Layer** (`HTM.configure`): Provides raw LLM access via `embedding_generator` and `tag_extractor` callables
2. **Service Layer** (`EmbeddingService`, `TagService`): Processes and validates LLM responses, handles padding/truncation, formats for storage
3. **Consumer Layer** (`GenerateEmbeddingJob`, `GenerateTagsJob`, rake tasks): Uses services for async or synchronous processing

This separation allows you to provide any LLM implementation while HTM handles response processing, validation, and storage.

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
