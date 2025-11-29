# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HTM (Hierarchical Temporary Memory) is a Ruby gem that provides intelligent memory management for LLM-based applications (robots). It implements a two-tier memory architecture:

- **Long-term Memory**: Durable PostgreSQL storage with vector embeddings for semantic search
- **Working Memory**: Token-limited in-memory context for immediate LLM use

Key capabilities include RAG-based retrieval, temporal filtering, multi-robot "hive mind" shared memory, and flexible hierarchical tagging for organization.

## Development Commands

### Setup
```bash
# Set database connection URL (required before any database operations)
export HTM_DBURL="postgresql://postgres@localhost:5432/htm_development"

# Install dependencies
bundle install

# Initialize database schema (run once)
rake db_setup
# OR
ruby -r ./lib/htm -e "HTM::Database.setup"

# Verify database connection
rake db_test
# OR
ruby test_connection.rb
```

### Testing
```bash
# Run all tests (Minitest)
rake test

# Run specific test file
ruby test/htm_test.rb
ruby test/embedding_service_test.rb
ruby test/integration_test.rb
```

### Examples
```bash
# Run basic usage example
rake example
# OR
ruby examples/basic_usage.rb
```

### Gem Tasks
```bash
# Build gem
rake build

# Install gem locally
rake install

# Release gem (requires proper credentials)
rake release
```

### Utilities
```bash
# Show code statistics
rake stats

# Show database table record counts and statistics
rake htm:db:stats

# Rebuild all embeddings (clears and regenerates via LLM)
rake htm:db:rebuild:embeddings

# Enable PostgreSQL extensions (if needed)
ruby enable_extensions.rb
```

## Architecture

### Core Components

**HTM** (`lib/htm.rb`): Main API class that coordinates all components. Handles robot registration, memory operations (add, recall, retrieve, forget), context assembly, and hive mind queries.

**HTM::Database** (`lib/htm/database.rb`): Database schema setup and configuration. Parses connection URLs from `HTM_DBURL` environment variable, verifies extensions (pgvector, pg_trgm), and runs schema migrations using ActiveRecord.

**HTM::LongTermMemory** (`lib/htm/long_term_memory.rb`): PostgreSQL-backed permanent storage with ActiveRecord models. Manages nodes table with many-to-many tagging system, vector search (pgvector), full-text search (PostgreSQL tsvector), and hybrid search capabilities.

**HTM::WorkingMemory** (`lib/htm/working_memory.rb`): In-memory token-limited cache. Tracks active nodes with LRU eviction, manages token budgets, and assembles context strings with multiple strategies (recent, important, balanced).

**HTM::EmbeddingService** (`lib/htm/embedding_service.rb`): Vector embedding validation and processing service. Wraps the configured embedding generator (via RubyLLM), validates responses, handles dimension padding/truncation. Called by `GenerateEmbeddingJob` background job. See ADR-016 for async workflow.

**HTM::TagService** (`lib/htm/tag_service.rb`): Hierarchical tag validation and processing service. Wraps the configured tag extractor (via RubyLLM chat), validates tag format, enforces depth limits. Called by `GenerateTagsJob` background job. Parallel architecture to EmbeddingService. See ADR-016.

**HTM::Configuration** (`lib/htm/configuration.rb`): Multi-provider LLM configuration via RubyLLM. Supports OpenAI, Anthropic, Gemini, Azure, Ollama (default), HuggingFace, OpenRouter, Bedrock, and DeepSeek. Manages API keys, model selection, and timeouts.

**HTM::Models::FileSource** (`lib/htm/models/file_source.rb`): Tracks source files loaded into memory. Stores file path, mtime for re-sync detection, YAML frontmatter metadata, and links to chunked nodes via `source_id` foreign key.

**HTM::Loaders::MarkdownLoader** (`lib/htm/loaders/markdown_loader.rb`): Loads markdown files into long-term memory. Extracts YAML frontmatter, chunks text by paragraph, tracks source file for re-sync, and handles duplicate detection via content hash.

**HTM::Loaders::ParagraphChunker** (`lib/htm/loaders/paragraph_chunker.rb`): Splits text into paragraph-based chunks. Preserves fenced code blocks (``` and ~~~), splits by blank lines, and merges very short fragments.

### Database Schema

Located in `db/schema.sql`:

- **robots**: Registry of all LLM agents using the HTM system with metadata
- **nodes**: Primary memory storage with vector embeddings (up to 2000 dimensions), full-text search, fuzzy matching, and soft delete support (`deleted_at` column)
- **tags**: Hierarchical tag system using colon-separated namespaces (e.g., `database:postgresql:extensions`)
- **nodes_tags**: Join table implementing many-to-many relationship between nodes and tags
- **file_sources**: Source file metadata for loaded documents (path, mtime, frontmatter, sync status)

The schema uses PostgreSQL 17 with pgvector and pg_trgm extensions. ActiveRecord models are available:
- `HTM::Models::Robot`
- `HTM::Models::Node`
- `HTM::Models::Tag`
- `HTM::Models::NodeTag`
- `HTM::Models::FileSource`

### Memory Types

- `:fact` - Immutable facts about the user or system
- `:context` - Conversational context and state
- `:code` - Code snippets, patterns, and implementations
- `:preference` - User preferences and settings
- `:decision` - Architectural and design decisions
- `:question` - Unresolved questions or uncertainties

### Search Strategies

- **Vector search** (`:vector`): Semantic similarity using pgvector with cosine distance on embeddings
- **Full-text search** (`:fulltext`): Keyword matching using PostgreSQL's tsvector with trigram fuzzy matching
- **Hybrid search** (`:hybrid`): Combines vector and full-text with weighted scoring

### Context Assembly Strategies

- **Recent** (`:recent`): Prioritizes newest memories
- **Important** (`:important`): Prioritizes high importance scores
- **Balanced** (`:balanced`): Importance × recency weighted combination

## Dependencies

### Runtime
- `pg` - PostgreSQL client library
- `pgvector` - Vector similarity search support
- `connection_pool` - Database connection pooling
- `tiktoken_ruby` - Token counting for context management
- `ruby_llm` - Multi-provider LLM client (OpenAI, Anthropic, Gemini, Azure, Ollama, HuggingFace, OpenRouter, Bedrock, DeepSeek)

### Development
- `rake` - Task automation
- `minitest` - Testing framework
- `minitest-reporters` - Enhanced test output
- `debug_me` - Debugging utilities (preferred over puts)

## Environment Variables

### Database
- `HTM_DBURL` - Full PostgreSQL connection URL (preferred)
- `HTM_SERVICE_NAME` - Service identifier
- `HTM_DBNAME` - Database name
- `HTM_DBUSER` - Database username
- `HTM_DBPASS` - Database password
- `HTM_DBPORT` - Database port
- `HTM_DBHOST` - Database host

### LLM Providers (via RubyLLM)
- `OPENAI_API_KEY` - OpenAI API key
- `OPENAI_ORGANIZATION` - OpenAI organization ID (optional)
- `ANTHROPIC_API_KEY` - Anthropic API key
- `GEMINI_API_KEY` - Google Gemini API key
- `AZURE_OPENAI_API_KEY` - Azure OpenAI API key
- `AZURE_OPENAI_ENDPOINT` - Azure OpenAI endpoint URL
- `OLLAMA_URL` - Ollama server URL (default: http://localhost:11434)
- `HUGGINGFACE_API_KEY` - HuggingFace Inference API key
- `OPENROUTER_API_KEY` - OpenRouter API key
- `AWS_ACCESS_KEY_ID` - AWS Bedrock access key
- `AWS_SECRET_ACCESS_KEY` - AWS Bedrock secret key
- `AWS_REGION` - AWS region (default: us-east-1)
- `DEEPSEEK_API_KEY` - DeepSeek API key

## External Services

### LLM Providers (via RubyLLM)

HTM uses RubyLLM for multi-provider LLM support. Configure your preferred provider:

```ruby
# OpenAI (cloud)
HTM.configure do |config|
  config.embedding_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  config.tag_provider = :openai
  config.tag_model = 'gpt-4o-mini'
end

# Anthropic (cloud)
HTM.configure do |config|
  config.tag_provider = :anthropic
  config.tag_model = 'claude-3-haiku-20240307'
end

# Ollama (local - default)
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'
  config.tag_provider = :ollama
  config.tag_model = 'llama3'
end
```

### Ollama (default local provider)

```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull embedding model
ollama pull nomic-embed-text

# Pull chat model for tag extraction
ollama pull llama3

# Verify Ollama is running
curl http://localhost:11434/api/version
```

### PostgreSQL Database
The project uses a local PostgreSQL instance with:
- PostgreSQL 14+ (17.x recommended)
- pgvector extension for vector similarity search
- pg_trgm extension for fuzzy text matching
- ActiveRecord for ORM and migrations

**Quick setup on macOS:**
```bash
brew install postgresql@17
brew services start postgresql@17
createdb htm_development
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

## Testing Philosophy

- All tests use Minitest framework with spec reporter
- Test files located in `test/` directory
- Integration tests require database connection (use test database if available)
- Mock Ollama embeddings in tests to avoid external dependencies

## Code Style

- Use `debug_me` gem for debugging, not `puts`
- Frozen string literals in all files
- Methods should be testable in isolation
- Use 2-space indentation
- Follow Ruby style guide conventions

## Common Development Tasks

### Adding a New Memory Type
1. Create ActiveRecord migration in `db/migrate/` if new columns needed
2. Add type to documentation in `lib/htm.rb` and `CLAUDE.md`
3. Consider adding specialized methods in `HTM` class
4. Add tests for the new type
5. Run `bundle exec rake htm:db:migrate` and `bundle exec rake htm:db:schema:dump`

### Using a Different LLM Provider
HTM uses RubyLLM which supports multiple providers out of the box. To use a different provider:

1. Set the appropriate API key environment variable (e.g., `OPENAI_API_KEY`)
2. Configure HTM with your preferred provider and model:
```ruby
HTM.configure do |config|
  config.embedding_provider = :openai  # or :anthropic, :gemini, :azure, etc.
  config.embedding_model = 'text-embedding-3-small'
  config.tag_provider = :openai
  config.tag_model = 'gpt-4o-mini'
end
```
3. Supported providers: `:openai`, `:anthropic`, `:gemini`, `:azure`, `:ollama`, `:huggingface`, `:openrouter`, `:bedrock`, `:deepseek`

### Modifying Database Schema
1. Create new ActiveRecord migration in `db/migrate/` with timestamp prefix
2. Use ActiveRecord DSL for table/column changes (create_table, add_column, add_index, etc.)
3. Update affected ActiveRecord models in `lib/htm/models/`
4. Update affected classes (`LongTermMemory`, `Database`)
5. Run `bundle exec rake htm:db:migrate` to apply changes
6. Run `bundle exec rake htm:db:schema:dump` to update `db/schema.sql`
7. Update documentation in `docs/development/schema.md` and `CLAUDE.md`
8. Update tests

### Async Background Processing (ADR-016)

HTM uses **async-job** for background processing with two parallel jobs per node:

**Node Creation Flow**:
1. **Save node immediately** (~15ms) - Fast user response
2. **Enqueue `GenerateEmbeddingJob`** - Adds embedding asynchronously
3. **Enqueue `GenerateTagsJob`** - Extracts and adds tags asynchronously

**Eventual Consistency**:
- Node available immediately for basic retrieval
- Embedding added within ~100ms (enables vector search)
- Tags added within ~1 second (enables hierarchical navigation)
- Full-text search works immediately (no dependencies)

**Current workflow**:
```ruby
# 1. Create node (fast response)
node = htm.add_message("PostgreSQL supports vector search via pgvector")
# Returns immediately (~15ms)

# 2. Background jobs run in parallel (user doesn't wait)
# - GenerateEmbeddingJob: Uses EmbeddingService to generate embedding
# - GenerateTagsJob: Uses TagService to extract tags from content

# 3. Node eventually enriched (~1 second)
# - node.embedding populated (enables vector search)
# - tags created and associated (enables tag navigation)
```

### Working with Embeddings
1. **Async generation**: `GenerateEmbeddingJob` runs after node creation
2. **Multi-provider support** (via RubyLLM):
   - Ollama (default): `nomic-embed-text` (768-dim)
   - OpenAI: `text-embedding-3-small` (1536-dim)
   - Gemini: `text-embedding-004` (768-dim)
   - Azure, HuggingFace, OpenRouter, Bedrock, DeepSeek also supported
3. **Dimensions**: Stored in `embedding_dimension` column, max 2000 dimensions (padded automatically)
4. **Error handling**: Failures logged, node remains without embedding
5. **Search behavior**: Vector search excludes nodes without embeddings

### Working with Tags
1. **Async extraction**: `GenerateTagsJob` uses LLM to extract hierarchical tags
2. **Multi-provider support**: Uses RubyLLM chat (same providers as embeddings)
3. **Hierarchical format**: Colon separators (e.g., `ai:llm:embeddings`)
4. **Ontology context**: Uses existing tags to maintain consistency
5. **Query by prefix**: `WHERE tags.name LIKE 'database:%'` finds all database tags
6. **Error handling**: Failures logged, node remains without tags

**Manual tag operations** (if needed):
```ruby
ltm.add_tag(node_id: node.id, tag: 'database:postgresql')  # Manual tag
tags = ltm.node_topics(node.id)  # Returns array of tag names
related = ltm.topic_relationships(min_shared_nodes: 2)  # Co-occurrence
```

**Tag hierarchy visualization**:
```ruby
# Text tree (directory-style)
puts HTM::Models::Tag.all.tree_string

# Mermaid flowchart format
puts HTM::Models::Tag.all.tree_mermaid              # Top-down
puts HTM::Models::Tag.all.tree_mermaid(direction: 'LR')  # Left-to-right

# SVG visualization (dark theme, transparent background)
File.write('tags.svg', HTM::Models::Tag.all.tree_svg)
File.write('tags.svg', HTM::Models::Tag.all.tree_svg(title: 'My Tags'))
```

**Rake tasks for tag management**:
```bash
rake htm:tags:tree                    # Display text tree (all tags)
rake 'htm:tags:tree[database]'        # Display tags with prefix 'database'
rake htm:tags:mermaid                 # Export to tags.md (Mermaid format)
rake 'htm:tags:mermaid[ai]'           # Export tags with prefix 'ai' to tags.md
rake htm:tags:svg                     # Export to tags.svg
rake 'htm:tags:svg[web]'              # Export tags with prefix 'web' to tags.svg
rake htm:tags:export                  # Export all formats (tags.txt, tags.md, tags.svg)
rake 'htm:tags:export[database]'      # Export filtered tags to all formats
rake htm:tags:rebuild                 # Rebuild all tags (clears and regenerates via LLM)
```

### Soft Delete and Memory Recovery

HTM uses soft delete by default when forgetting memories, allowing recovery of accidentally deleted nodes.

**Soft delete (default - recoverable)**:
```ruby
htm.forget(node_id)                   # Soft delete (sets deleted_at timestamp)
htm.forget(node_id, soft: true)       # Explicit soft delete
```

**Restore soft-deleted nodes**:
```ruby
htm.restore(node_id)                  # Clears deleted_at, node visible again
```

**Permanent delete (requires confirmation)**:
```ruby
htm.forget(node_id, soft: false, confirm: :confirmed)  # Permanently removes from database
```

**Purge old soft-deleted nodes**:
```ruby
htm.purge_deleted(older_than: 30.days.ago, confirm: :confirmed)
htm.purge_deleted(older_than: Time.new(2024, 1, 1), confirm: :confirmed)
```

**Query soft-deleted nodes directly**:
```ruby
HTM::Models::Node.deleted                    # All soft-deleted nodes
HTM::Models::Node.with_deleted               # All nodes including deleted
HTM::Models::Node.deleted_before(30.days.ago)  # Deleted before a date

node = HTM::Models::Node.with_deleted.find(id)
node.deleted?      # Check if soft-deleted
node.restore!      # Restore a specific node
node.soft_delete!  # Soft delete a specific node
```

### Loading Files into Memory

HTM can load text-based files (currently markdown) into long-term memory with automatic chunking, source tracking, and re-sync support.

**Load a single file**:
```ruby
htm = HTM.new(robot_name: "Document Loader")

# Load a markdown file - chunks by paragraph, extracts frontmatter
result = htm.load_file("docs/guide.md")
# => { file_source_id: 1, chunks_created: 5, chunks_updated: 0, chunks_deleted: 0 }

# Force re-sync even if file hasn't changed
result = htm.load_file("docs/guide.md", force: true)
```

**Load a directory**:
```ruby
# Load all markdown files in a directory (recursive)
results = htm.load_directory("docs/")
# => [{ file_path: "docs/guide.md", ... }, { file_path: "docs/api.md", ... }]

# Custom glob pattern
results = htm.load_directory("content/", pattern: "**/*.md")
```

**Query nodes from a file**:
```ruby
# Get all nodes loaded from a specific file
nodes = htm.nodes_from_file("docs/guide.md")
# => [#<HTM::Models::Node>, #<HTM::Models::Node>, ...]
```

**Unload a file**:
```ruby
# Soft delete all nodes from a file and remove file source
htm.unload_file("docs/guide.md")
```

**Re-sync behavior**:
- Files are tracked by path with mtime-based change detection
- If file hasn't changed, `load_file` returns early (unless `force: true`)
- Changed files are re-synced: new chunks created, unchanged chunks kept, removed chunks soft-deleted
- YAML frontmatter is extracted and stored as metadata on the file source

**Chunking strategy**:
- Text is split by paragraph (blank lines)
- Fenced code blocks (``` and ~~~) are preserved as single chunks
- Very short fragments (<10 chars) are merged with neighbors
- Each chunk becomes a node with `source_id` linking back to the file

**FileSource model**:
```ruby
source = HTM::Models::FileSource.find_by(file_path: "docs/guide.md")
source.needs_sync?      # Check if file changed since last load
source.chunks           # Get all nodes from this file (ordered by position)
source.frontmatter      # Get parsed YAML frontmatter hash
source.frontmatter_tags # Get tags from frontmatter (if present)
```

**Rake tasks for file loading**:
```bash
rake 'htm:files:load[docs/guide.md]'      # Load a single file
rake 'htm:files:load_dir[docs/]'          # Load all markdown files from directory
rake 'htm:files:load_dir[docs/,**/*.md]'  # Load with custom glob pattern
rake htm:files:list                        # List all loaded file sources
rake 'htm:files:info[docs/guide.md]'      # Show details for a loaded file
rake 'htm:files:unload[docs/guide.md]'    # Unload a file from memory
rake htm:files:sync                        # Sync all loaded files (reload changed)
rake htm:files:stats                       # Show file loading statistics

# Use FORCE=true to reload even if file hasn't changed
FORCE=true rake 'htm:files:load[docs/guide.md]'
```

## Architecture Framework

HTM uses the [ai-software-architect](https://github.com/codenamev/ai-software-architect) framework for managing architectural decisions and reviews.

### Architecture Directory Structure
```
.architecture/
├── decisions/adrs/          # Architectural Decision Records
├── reviews/                 # Architecture review documents
├── recalibration/           # Implementation plans from reviews
├── comparisons/             # Version comparisons
├── docs/                    # Architecture documentation
├── templates/               # Document templates
└── members.yml              # Review team roster
```

### Working with Architecture

**View existing ADRs**: Browse `.architecture/decisions/adrs/` for documented architectural decisions.

**Create new ADR**: Use natural language with Claude Code:
```
Create an ADR for [topic]
```

**Start architecture review**: For version, feature, or component reviews:
```
Start architecture review for version X.Y.Z
Start architecture review for [feature name]
Review architecture for [component description]
```

**Consult specialists**: Invoke specific review perspectives:
```
Ask Security Architect to review this API design
Ask Performance Specialist to review the caching strategy
Ask AI Engineer to review the RAG implementation
```

**View system analysis**: Comprehensive system overview available at `.architecture/reviews/initial-system-analysis.md`.

### Review Team

The architecture review team (defined in `.architecture/members.yml`) includes:
- **Systems Architect**: Distributed systems, scalability, system decomposition
- **Domain Expert**: Domain-driven design, business logic, semantic modeling
- **Security Specialist**: Threat modeling, vulnerability assessment, data protection
- **Maintainability Expert**: Code quality, technical debt, long-term evolution
- **Performance Specialist**: Optimization, profiling, resource utilization
- **AI Engineer**: LLM integration, RAG systems, embedding strategies
- **Ruby Expert**: Ruby idioms, gem development, testing
- **Database Architect**: PostgreSQL, ActiveRecord, pgvector optimization, schema design

## Important Notes

- The gem is under active development; see `htm_teamwork.md` for roadmap
- Database connection requires `HTM_DBURL` environment variable or config/database.yml
- **Async Processing** (ADR-016): Nodes saved immediately (~15ms), embeddings and tags added via background jobs
- **Background Jobs**: Uses `async-job` gem with `GenerateEmbeddingJob` and `GenerateTagsJob`
- **Multi-provider LLM support**: OpenAI, Anthropic, Gemini, Azure, Ollama (default), HuggingFace, OpenRouter, Bedrock, DeepSeek via RubyLLM
- Database uses PostgreSQL 17 with pgvector and pg_trgm extensions
- ActiveRecord models provide ORM layer: Robot, Node, Tag, NodeTag (ADR-013)
- **TagService**: LLM-based hierarchical tag extraction (parallel architecture to EmbeddingService)
- All robots share global memory (hive mind architecture)
- **Soft Delete**: `forget()` performs soft delete by default (recoverable via `restore()`); permanent delete requires `soft: false, confirm: :confirmed`
- Working memory eviction moves nodes to long-term storage, never deletes them
- **Tag Visualization**: Export tag hierarchy as text tree, Mermaid flowchart, or SVG (dark theme)
- Token counting uses Tiktoken with GPT-3.5-turbo encoding
- Architecture decisions are documented in ADRs (see `.architecture/decisions/adrs/`)
- **Key ADRs**: 001 (PostgreSQL), 013 (ActiveRecord+Tags), **016 (Async Jobs)** [supersedes 014, 015]
- **File Loading**: Load markdown files into memory with `load_file()`, `load_directory()`, `unload_file()` methods
- backward-compatibility is not necessary.
- backward compatibility is never a consideration