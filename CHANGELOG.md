# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.6] - 2025-11-28

### Added
- **Automatic timeframe extraction from queries** - No LLM required
  - `TimeframeExtractor` service parses natural language time expressions
  - Uses `chronic` gem for robust date/time parsing
  - Supports standard expressions: "yesterday", "last week", "this morning", etc.
  - `FEW` constant (3) maps "few", "a few", "several" to numeric values
  - "recently"/"recent" without units defaults to 3 days
  - Custom weekend handling: "weekend before last", "N weekends ago"
  - Returns cleaned query with temporal expression removed
- **Flexible `timeframe` parameter in `recall` method** - Multiple input types:
  - `nil` - No time filter (searches all time)
  - `Date` / `DateTime` / `Time` - Entire day (00:00:00 to 23:59:59)
  - `Range` - Exact time window
  - `String` - Natural language parsing via Chronic
  - `:auto` - Extract timeframe from query text automatically
  - `Array<Range>` - Multiple time windows OR'd together
- **`HTM::Timeframe` normalizer class** - Converts all input types to Range or Array<Range>
  - `Timeframe.normalize(input, query:)` handles all conversions
  - `Timeframe.valid?(input)` validates timeframe input
  - Returns `Result` struct with `:timeframe`, `:query`, `:extracted` when using `:auto`
- **Configurable week start** - `HTM.configuration.week_start`
  - Options: `:sunday` (default) or `:monday`
  - Passed to Chronic for "last week" and similar expressions
- **Timeframe demo** - `examples/timeframe_demo.rb` showcasing all input types
  - Run with `rake timeframe_demo`
- **New rake task**: `rake timeframe_demo` to run the demo

### Changed
- **`recall` method** now accepts all new timeframe input types
- **`validate_timeframe!`** uses `HTM::Timeframe.valid?` for validation
- **`LongTermMemory` search methods** support `nil` and `Array<Range>` timeframes
  - `apply_timeframe_scope` handles OR conditions for multiple ranges

### Dependencies
- Added `chronic` gem for natural language date parsing

## [0.0.5] - 2025-11-28

### Added
- **Semantic tag matching for queries** - Query tags are now extracted using LLM
  - Uses same `TagService.extract()` process as node storage
  - 3-step search strategy: exact match → prefix match → component match
  - Component matching searches right-to-left (most specific first)
  - Replaces naive keyword substring matching
- **New rake tasks for database maintenance**:
  - `htm:db:stats` - Show record counts for all HTM tables with breakdowns
  - `htm:db:rebuild:embeddings` - Clear and regenerate all embeddings with progress bar
  - `htm:tags:rebuild` - Clear and regenerate all tags with progress bar
- **Progress bar support** - Added `ruby-progressbar` gem for long-running rake tasks
- **CLI demo enhancements** (`examples/cli_app/htm_cli.rb`):
  - Shows extracted tags, searched tags, and matched tags during recall
  - Generates context-aware responses using RubyLLM with Ollama
  - Stores LLM responses in long-term memory for learning

### Changed
- **Improved tag extraction prompt** with CRITICAL CONSTRAINTS to prevent:
  - Circular references (concept at both root and leaf)
  - Self-containment (parent containing itself as descendant)
  - Duplicate segments in hierarchy path
  - Redundant duplicates across branches
- **TagService validation** now programmatically enforces:
  - Self-containment detection (root == leaf)
  - Duplicate segment detection in hierarchy path
  - Maximum depth reduced from 5 to 4 levels
- **`find_query_matching_tags` method** completely rewritten:
  - Now uses LLM-based semantic extraction instead of keyword matching
  - Returns both extracted and matched tags via `include_extracted: true` option

### Fixed
- Tag search no longer matches unrelated tags via substring (e.g., "man" matching "management")

## [0.0.4] - 2025-11-28

### Added
- **Markdown file loader** - Load markdown files into long-term memory
  - `FileSource` model to track loaded files with metadata and sync status
  - `MarkdownLoader` with YAML frontmatter extraction
  - `ParagraphChunker` for splitting content into semantic chunks
  - DELTA_TIME tolerance (5 seconds) for reliable file change detection
- **New HTM API methods** for file operations:
  - `htm.load_file(path, force: false)` - Load single markdown file
  - `htm.load_directory(path, pattern: '**/*.md', force: false)` - Load directory
  - `htm.nodes_from_file(path)` - Query nodes from a loaded file
  - `htm.unload_file(path)` - Unload file and soft-delete its chunks
- **File loading rake tasks**:
  - `htm:files:load[path]` - Load a markdown file
  - `htm:files:load_dir[path,pattern]` - Load directory with glob pattern
  - `htm:files:list` - List all loaded file sources
  - `htm:files:info[path]` - Show details for a loaded file
  - `htm:files:unload[path]` - Unload a file from memory
  - `htm:files:sync` - Re-sync all loaded files (reload changed files)
  - `htm:files:stats` - Show file loading statistics
- **FileSource model features**:
  - `needs_sync?(mtime)` with DELTA_TIME tolerance for mtime comparison
  - `frontmatter_tags`, `title`, `author` accessors for frontmatter data
  - `soft_delete_chunks!` for bulk soft-delete of associated nodes
  - `by_path` scope for path-based lookups
- **New example**: `examples/file_loader_usage.rb` demonstrating all file operations
- **New tests**: FileSource model tests (19) and MarkdownLoader tests (18)

### Changed
- Node model now has optional `source_id` foreign key to FileSource
- Node model has `chunk_position` column for ordering chunks within a file

## [0.0.2] - 2025-11-28

### Added
- **Soft delete for memory nodes** - `forget()` now soft deletes by default (recoverable)
  - `restore(node_id)` to recover soft-deleted nodes
  - `purge_deleted(older_than:, confirm:)` to permanently remove old deleted nodes
  - Permanent delete requires `soft: false, confirm: :confirmed`
  - `deleted_at` column and scopes: `Node.deleted`, `Node.with_deleted`
- **Tag hierarchy visualization** - Export tag trees in multiple formats
  - `Tag.all.tree` returns nested hash structure
  - `Tag.all.tree_string` returns directory-style text tree
  - `Tag.all.tree_mermaid` generates Mermaid flowchart syntax
  - `Tag.all.tree_svg` generates SVG with dark theme, transparent background
  - Rake tasks: `htm:tags:tree`, `htm:tags:mermaid`, `htm:tags:svg`, `htm:tags:export`
  - All rake tasks accept optional prefix filter parameter
- **Per-robot working memory persistence** - Optional database-backed working memory
  - New `working_memories` table for state restoration after process restart
  - `WorkingMemoryEntry` model with `sync`, `load`, `clear` methods
  - Enables cross-robot observability in hive mind architecture
- **Temporal filtering in recall** - Parse timeframe strings (seconds/minutes/hours)
- **Integration tests** for embeddings, vector search, and recall options
- **Multi-provider LLM support via RubyLLM** - HTM now supports 9 LLM providers:
  - OpenAI (`text-embedding-3-small`, `gpt-4o-mini`)
  - Anthropic (`claude-3-haiku-20240307`)
  - Google Gemini (`text-embedding-004`)
  - Azure OpenAI
  - Ollama (default, local-first)
  - HuggingFace Inference API
  - OpenRouter
  - AWS Bedrock
  - DeepSeek
- Provider-specific configuration attributes for all supported providers
- `HTM::Configuration#configure_ruby_llm` method for provider credential setup
- `SUPPORTED_PROVIDERS` constant listing all available providers
- `DEFAULT_DIMENSIONS` hash with typical embedding dimensions per provider
- Architecture documentation using ai-software-architect framework
- Comprehensive ADRs (Architecture Decision Records) for all major design decisions

### Changed
- **Embedding generator now uses `RubyLLM.embed()`** instead of raw HTTP calls to Ollama
- **Tag extractor now uses `RubyLLM.chat()`** instead of raw HTTP calls to Ollama
- **Sinatra integration moved** to `lib/htm/integrations/sinatra.rb` (require path changed)
- **Hybrid search includes nodes without embeddings** using 0.5 default similarity
- Configuration validation now checks provider is in `SUPPORTED_PROVIDERS`
- MkDocs documentation reorganized with tbls schema docs integration
- Updated CLAUDE.md with multi-provider documentation and examples

### Removed
- Unused `nodes.in_working_memory` column (was never set to true)
- Unused `robots.metadata` column (never referenced in codebase)
- One-off test scripts replaced with proper Minitest integration tests

### Fixed
- Sinatra session secret error (Rack requires 64+ bytes)
- Thread-safe database connection in Sinatra integration
- tbls database documentation rake task configuration

## [0.0.1] - 2025-10-25

### Added
- Initial release of HTM (Hierarchical Temporary Memory)
- Two-tier memory system:
  - Working memory: Token-limited, in-memory active context
  - Long-term memory: Durable PostgreSQL/TimescaleDB storage
- Core memory operations:
  - `add_node`: Store memories with metadata, embeddings, and relationships
  - `recall`: RAG-based retrieval with temporal and semantic search
  - `retrieve`: Direct memory lookup by key
  - `forget`: Explicit deletion with confirmation requirement
  - `create_context`: Assemble LLM context from working memory
- Multi-robot "hive mind" architecture:
  - Shared global memory database
  - Robot attribution tracking
  - Robot registry and activity monitoring
  - Cross-robot knowledge sharing
- Search strategies:
  - Vector search: Semantic similarity using pgvector
  - Full-text search: Keyword matching with PostgreSQL full-text search
  - Hybrid search: Combined pre-filter + vector reranking
  - Temporal filtering: Time-range queries with TimescaleDB
- Context assembly strategies:
  - Recent: Most recently accessed memories first
  - Important: Highest importance score first
  - Balanced: Hybrid with time-decay function (default)
- Working memory management:
  - Configurable token limits (default: 128,000)
  - Hybrid eviction strategy (importance + recency)
  - LRU access tracking
  - Automatic eviction to long-term storage
- Long-term memory features:
  - PostgreSQL 17+ with TimescaleDB 2.22.1
  - Vector embeddings with pgvector 0.8.1 (HNSW indexing)
  - Full-text search with pg_trgm
  - Relationship graphs between memories
  - Tag system for categorization
  - Operations logging and audit trail
  - Memory statistics and analytics
- Embedding service:
  - Default: Ollama with gpt-oss model (local-first)
  - Support for multiple providers (OpenAI, Cohere, local)
  - Configurable models and endpoints
  - Accurate token counting with tiktoken_ruby
- Database schema:
  - `nodes`: Core memory storage with embeddings
  - `relationships`: Graph connections between memories
  - `tags`: Flexible categorization system
  - `robots`: Robot registry and activity tracking
  - `operations_log`: Audit trail for all operations
  - TimescaleDB hypertables for time-series optimization
  - PostgreSQL views for statistics
- Memory types:
  - `:fact`: Factual information
  - `:context`: Contextual information
  - `:code`: Code snippets and technical content
  - `:preference`: User preferences
  - `:decision`: Architectural and strategic decisions
  - `:question`: Questions and queries
- Memory metadata:
  - Importance scoring (0.0-10.0)
  - Token counting
  - Timestamps (created_at, last_accessed)
  - Robot attribution
  - Categories and tags
  - Relationships to other memories
- Robot identification:
  - UUID-based robot_id (auto-generated)
  - Optional human-readable robot_name
  - Robot registry with activity tracking
  - Memory attribution by robot
- Never-forget philosophy:
  - Memories never automatically deleted
  - Eviction moves to long-term storage (no data loss)
  - Explicit confirmation required for deletion (`:confirmed` symbol)
  - All deletions logged for audit trail
- Database utilities:
  - Schema creation and migration scripts
  - Extension installation (TimescaleDB, pgvector, pg_trgm)
  - Hypertable configuration
  - Compression policies
  - Index creation for performance
- Development tools:
  - Comprehensive test suite (Minitest)
  - Example scripts and usage patterns
  - Rakefile with common tasks
  - Environment configuration with direnv
- Documentation:
  - README with quick start guide
  - SETUP.md with detailed installation instructions
  - CLAUDE.md for AI assistant context
  - Architecture documentation in `.architecture/`
  - Inline code documentation

### Dependencies
- Ruby 3.0+
- PostgreSQL 17+
- TimescaleDB 2.22.1
- pgvector 0.8.1
- pg gem (~> 1.5)
- pgvector gem (~> 0.8)
- connection_pool gem (~> 2.4)
- tiktoken_ruby gem (~> 0.0.9)
- ruby-llm gem (~> 0.7.1)

### Database Requirements
- PostgreSQL 17+ with extensions:
  - timescaledb (2.22.1+)
  - vector (0.8.1+)
  - pg_trgm (1.6+)
- Recommended: TimescaleDB Cloud or local TimescaleDB installation

### Environment Variables
- `HTM_DBURL`: PostgreSQL connection string (required)
- `OLLAMA_URL`: Ollama API endpoint (default: http://localhost:11434)

### Notes
- This is an initial release focused on core functionality
- Database schema is stable but may evolve in future versions
- Embedding models and providers are configurable
- Working memory size is user-configurable
- See ADRs for detailed architectural decisions and rationale

[Unreleased]: https://github.com/madbomber/htm/compare/v0.0.6...HEAD
[0.0.6]: https://github.com/madbomber/htm/compare/v0.0.5...v0.0.6
[0.0.5]: https://github.com/madbomber/htm/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/madbomber/htm/compare/v0.0.2...v0.0.4
[0.0.2]: https://github.com/madbomber/htm/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/madbomber/htm/releases/tag/v0.0.1
