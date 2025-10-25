# HTM Initial System Analysis

**Generated**: 2025-10-25
**Version**: 0.1.0 (Initial Development)
**Status**: Active Development

## Executive Summary

HTM (Hierarchical Temporary Memory) is a Ruby gem providing intelligent memory management for LLM-based applications ("robots"). The system implements a two-tier memory architecture combining durable PostgreSQL/TimescaleDB storage with token-limited working memory, enabling contextual recall through RAG (Retrieval-Augmented Generation) techniques.

### Key Strengths
- **Never-forget architecture**: Explicit deletion model prevents accidental data loss
- **Multi-robot "hive mind"**: Shared memory enables cross-robot context awareness
- **Time-series optimization**: TimescaleDB hypertables with automatic compression
- **Flexible search**: Vector, full-text, and hybrid search strategies
- **Production-grade storage**: PostgreSQL with pgvector for semantic search

### Key Challenges
- **Embedding service dependency**: Requires Ollama or external API for vector generation
- **Early development stage**: Some features are stubs (OpenAI, Cohere providers)
- **Schema evolution**: No migration framework currently in place
- **Connection management**: Single connection model may not scale

## System Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         HTM API                              │
│  (Main interface - lib/htm.rb)                              │
│  • add_node, recall, retrieve, forget                       │
│  • create_context, memory_stats                             │
│  • which_robot_said, conversation_timeline                  │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             ▼                            ▼
┌──────────────────────┐      ┌──────────────────────┐
│   WorkingMemory      │      │  LongTermMemory      │
│   (In-memory)        │◄────►│  (PostgreSQL)        │
│                      │      │                      │
│  • Token tracking    │      │  • Persistent nodes  │
│  • LRU eviction      │      │  • Relationships     │
│  • Context assembly  │      │  • Tags              │
└──────────────────────┘      │  • Vector search     │
                              │  • Full-text search  │
                              └──────────┬───────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │  EmbeddingService    │
                              │  (via RubyLLM)       │
                              │                      │
                              │  • Ollama (default)  │
                              │  • OpenAI (stub)     │
                              │  • Token counting    │
                              └──────────────────────┘
```

### Data Flow

**Adding a Memory:**
1. HTM.add_node() receives content and metadata
2. EmbeddingService generates vector embedding (via Ollama)
3. Token count calculated using Tiktoken
4. LongTermMemory persists to PostgreSQL with embedding
5. WorkingMemory adds to active context (with eviction if needed)
6. Relationships and tags created
7. Operation logged to audit trail

**Recalling Memories:**
1. HTM.recall() with timeframe and topic
2. Natural language timeframe parsed ("last week" → date range)
3. Search strategy selected (vector/fulltext/hybrid)
4. EmbeddingService generates query embedding (for vector search)
5. LongTermMemory executes search with time filter
6. Results added to WorkingMemory (evicting if needed)
7. Operation logged
8. Nodes returned to caller

**Context Assembly:**
1. HTM.create_context() with strategy
2. WorkingMemory sorts nodes by strategy (recent/important/balanced)
3. Assembles text within token budget
4. Returns context string for LLM

## Technology Stack

### Core Dependencies
- **PostgreSQL 17+**: Primary data store
- **TimescaleDB**: Time-series optimization, hypertables, compression
- **pgvector**: Vector similarity search (cosine distance, HNSW indexing)
- **pg_trgm**: Trigram-based fuzzy text matching
- **Ruby 3.0+**: Implementation language
- **Ollama**: Local embedding generation (default via RubyLLM)
- **Tiktoken**: Token counting for context management

### Development Tools
- **Minitest**: Testing framework
- **Rake**: Task automation
- **debug_me**: Debugging utility (project standard)

## Database Schema

### Core Tables

**nodes** (TimescaleDB hypertable on `created_at`):
- Primary memory storage
- Vector embeddings (1536 dimensions)
- Token counts, importance scores
- Robot ownership tracking
- Compression after 30 days

**relationships**:
- Knowledge graph edges
- From/to node references
- Relationship types and strength

**tags**:
- Flexible categorization
- Many-to-many with nodes

**operations_log** (TimescaleDB hypertable):
- Audit trail for all operations
- Partitioned by timestamp

**robots**:
- Robot registry
- Activity tracking

### Indexing Strategy
- **HNSW** on vector embeddings (cosine distance)
- **GIN** on full-text search vectors
- **GIN** with trigram ops for fuzzy matching
- **B-tree** on temporal columns, robot_id, types

## Current Implementation Status

### Completed (Phase 1)
- ✅ Core two-tier memory architecture
- ✅ PostgreSQL/TimescaleDB schema
- ✅ Ollama embedding integration
- ✅ Token counting and budget management
- ✅ Database connection and setup
- ✅ Hypertable configuration
- ✅ Basic testing framework

### In Progress
- 🔄 RAG retrieval implementation
- 🔄 Working memory eviction strategies
- 🔄 Relationship graph queries
- 🔄 Tag-based filtering

### Planned
- 📋 Additional embedding providers (OpenAI, Cohere)
- 📋 Connection pooling
- 📋 Advanced context assembly
- 📋 Memory consolidation
- 📋 Observability and metrics
- 📋 Migration framework
- 📋 Production hardening

## Design Patterns & Principles

### Architecture Patterns
- **Two-tier memory**: Separates hot (working) from cold (long-term) storage
- **RAG (Retrieval-Augmented Generation)**: Semantic + temporal search
- **Repository pattern**: Database abstraction in LongTermMemory
- **Strategy pattern**: Multiple search and context assembly strategies
- **Adapter pattern**: EmbeddingService abstracts provider differences

### Design Principles Applied
- **Explicit deletion**: Never delete without confirmation
- **Fail-safe defaults**: Falls back to random embeddings if Ollama unavailable
- **Separation of concerns**: Clear component boundaries
- **Testability**: Components designed for isolation testing
- **Documentation as code**: Inline documentation with examples

## Key Architectural Decisions

See ADRs for detailed decision records:

1. **PostgreSQL + TimescaleDB for storage** (ADR-001)
   - Time-series optimization
   - Native vector search with pgvector
   - Production-grade reliability

2. **Two-tier memory architecture** (ADR-002)
   - Token budget management
   - LRU eviction to long-term storage
   - Never-delete philosophy

3. **Ollama as default embedding provider** (ADR-003)
   - Local-first approach
   - No API costs
   - Privacy-preserving

4. **Multi-robot shared memory (hive mind)** (ADR-004)
   - Cross-robot context sharing
   - Conversation attribution
   - Timeline reconstruction

5. **Hybrid search strategy** (ADR-005)
   - Vector similarity for semantics
   - Full-text for keywords
   - Temporal filtering
   - Weighted combination

## Risk Assessment

### Technical Risks

**High Priority:**
- **Ollama dependency**: Embedding generation fails if Ollama unavailable
  - *Mitigation*: Fallback to stub embeddings, multi-provider support

- **Schema evolution**: No migration framework
  - *Mitigation*: Implement Rails-like migration system

**Medium Priority:**
- **Connection management**: Single connection per instance
  - *Mitigation*: Implement connection pooling (ConnectionPool gem already included)

- **Memory growth**: Working memory could grow unbounded
  - *Mitigation*: Implement aggressive eviction strategies

**Low Priority:**
- **Embedding dimension mismatch**: Hardcoded 1536 dimensions
  - *Mitigation*: Make configurable per provider

### Operational Risks

**Medium Priority:**
- **Database costs**: TimescaleDB Cloud usage-based pricing
  - *Mitigation*: Compression policies, retention policies

- **Token counting accuracy**: Tiktoken approximation may differ from LLM
  - *Mitigation*: Add safety margins, LLM-specific counters

## Performance Considerations

### Strengths
- TimescaleDB chunk-based partitioning for time-range queries
- HNSW indexing for fast vector similarity search
- Compression for old data reduces storage costs
- Token pre-calculation avoids runtime overhead

### Optimization Opportunities
- Connection pooling for concurrent access
- Batch embedding generation
- Caching frequently accessed nodes
- Lazy loading of relationships
- Prepared statements for common queries

## Security Considerations

### Current State
- SSL required for TimescaleDB Cloud connection
- Database credentials via environment variables
- No encryption at rest (relies on database)
- No access control beyond robot_id tracking

### Recommendations
- Implement row-level security for multi-tenant scenarios
- Encrypt embeddings if sensitive
- Add audit logging for forget() operations
- Consider API key rotation for embedding providers
- Validate and sanitize all user inputs

## Scalability Analysis

### Current Limitations
- Single database connection per HTM instance
- In-memory working memory (per-process)
- No horizontal scaling strategy
- Limited to single TimescaleDB instance

### Growth Path
- Add connection pooling
- Consider Redis for shared working memory
- Implement read replicas for query scaling
- Partition by robot_id for tenant isolation
- Add caching layer (Redis/Memcached)

## Maintainability Assessment

### Strengths
- Clear component separation
- Comprehensive inline documentation
- Test framework in place
- Debugging with debug_me standard
- Frozen string literals enabled

### Areas for Improvement
- Increase test coverage (integration tests needed)
- Add API documentation (YARD/RDoc)
- Implement CI/CD pipeline
- Add code quality metrics (RuboCop, SimpleCov)
- Create migration framework

## Next Steps

### Immediate (Current Sprint)
1. Complete RAG retrieval implementation
2. Finalize working memory eviction
3. Add comprehensive integration tests
4. Document API with YARD

### Short-term (Next 2-4 weeks)
1. Implement connection pooling
2. Add OpenAI embedding provider
3. Create migration framework
4. Add observability (logging, metrics)
5. Performance profiling and optimization

### Long-term (Next Quarter)
1. Production hardening
2. Horizontal scaling strategy
3. Advanced RAG features (re-ranking, filtering)
4. Memory consolidation algorithms
5. Web UI for memory exploration
6. Publish gem to RubyGems

## Conclusion

HTM demonstrates a solid architectural foundation with clear separation of concerns and production-grade technology choices. The two-tier memory model with RAG-based retrieval is well-suited for LLM applications requiring contextual awareness across conversations.

Key strengths include the never-forget philosophy, multi-robot hive mind, and TimescaleDB time-series optimization. Primary areas for improvement are connection management, schema evolution, and comprehensive testing.

The project is positioned well for growth from prototype to production-ready gem with focused attention on connection pooling, additional embedding providers, and operational tooling.
