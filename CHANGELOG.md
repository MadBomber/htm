# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
- Provider-specific configuration attributes:
  - `openai_api_key`, `openai_organization`, `openai_project`
  - `anthropic_api_key`
  - `gemini_api_key`
  - `azure_api_key`, `azure_endpoint`, `azure_api_version`
  - `ollama_url`
  - `huggingface_api_key`
  - `openrouter_api_key`
  - `bedrock_access_key`, `bedrock_secret_key`, `bedrock_region`
  - `deepseek_api_key`
- `HTM::Configuration#configure_ruby_llm` method for provider credential setup
- `SUPPORTED_PROVIDERS` constant listing all available providers
- `DEFAULT_DIMENSIONS` hash with typical embedding dimensions per provider
- Architecture documentation using ai-software-architect framework
- Comprehensive ADRs (Architecture Decision Records):
  - ADR-001: PostgreSQL with TimescaleDB for storage
  - ADR-002: Two-tier memory architecture (working + long-term)
  - ADR-003: Ollama as default embedding provider
  - ADR-004: Multi-robot shared memory (hive mind)
  - ADR-005: RAG-based retrieval with hybrid search
  - ADR-006: Context assembly strategies (recent, important, balanced)
  - ADR-007: Working memory eviction strategy (hybrid importance + recency)
  - ADR-008: Robot identification system (UUID + name)
  - ADR-009: Never-forget philosophy with explicit deletion
- Architecture review team with 8 specialist perspectives
- Had the robot convert my notss and system analysis documentation into Architectural Decision Records (ADR)

### Changed
- **Embedding generator now uses `RubyLLM.embed()`** instead of raw HTTP calls to Ollama
- **Tag extractor now uses `RubyLLM.chat()`** instead of raw HTTP calls to Ollama
- Configuration validation now checks provider is in `SUPPORTED_PROVIDERS`
- Updated CLAUDE.md with multi-provider documentation and examples
- Environment variables section expanded with all provider API keys

## [0.1.0] - 2025-10-25

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

[Unreleased]: https://github.com/madbomber/htm/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/madbomber/htm/releases/tag/v0.1.0
