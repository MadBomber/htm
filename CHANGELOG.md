# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/madbomber/htm/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/madbomber/htm/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/madbomber/htm/releases/tag/v0.1.0
