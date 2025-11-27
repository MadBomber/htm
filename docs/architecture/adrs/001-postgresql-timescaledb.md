# ADR-001: PostgreSQL with TimescaleDB for Storage

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM uses **PostgreSQL with TimescaleDB** as its primary storage backend, providing time-series optimization, vector embeddings (pgvector), full-text search, and ACID compliance in a single, production-proven database system.

**Why**: Consolidates time-series data, vector search, and full-text capabilities in one system rather than maintaining multiple specialized databases.

**Impact**: Production-ready storage with excellent tooling, at the cost of some operational complexity compared to simpler alternatives.

---

## Context

HTM requires a persistent storage solution that can handle:

- Time-series data with efficient time-range queries
- Vector embeddings for semantic search
- Full-text search capabilities
- ACID compliance for data integrity
- Scalability for growing memory databases
- Production-grade reliability

### Alternative Options Considered

1. **Pure PostgreSQL**: Solid relational database, pgvector support
2. **TimescaleDB**: PostgreSQL extension optimized for time-series
3. **Elasticsearch**: Strong full-text search, vector support added
4. **Pinecone/Weaviate**: Specialized vector databases
5. **SQLite + extensions**: Simple, embedded option

---

## Decision

We will use **PostgreSQL with TimescaleDB** as the primary storage backend for HTM.

---

## Rationale

### Why PostgreSQL?

**Production-proven**:
- Decades of reliability in demanding environments
- ACID compliance guarantees data integrity for memory operations
- Rich ecosystem with extensive tooling, monitoring, and support

**Search capabilities**:
- **pgvector extension**: Native vector similarity search with HNSW indexing
- **Full-text search**: Built-in tsvector with GIN indexing
- **pg_trgm extension**: Trigram-based fuzzy matching

**Developer experience**:
- Strong typing with schema enforcement prevents data corruption
- Wide adoption means well-understood by developers
- Standard SQL with PostgreSQL-specific enhancements

### Why TimescaleDB?

**Time-series optimization**:
- **Hypertable partitioning**: Automatic chunk-based time partitioning
- **Compression policies**: Automatic compression of old data (70-90% reduction)
- **Time-range optimization**: Fast queries on temporal data via chunk exclusion

**PostgreSQL compatibility**:
- Drop-in extension, not a fork
- All PostgreSQL features remain available
- Standard PostgreSQL tools work seamlessly

**Operational features**:
- **Continuous aggregates**: Pre-computed summaries for analytics
- **Retention policies**: Automatic data lifecycle management
- **Cloud offering**: Managed service available (TimescaleDB Cloud)

### Why Not Alternatives?

!!! warning "Elasticsearch"
    - High operational complexity (JVM tuning, cluster management)
    - Higher resource usage
    - Vector support more recent, less mature
    - Superior full-text search not critical for our use case

!!! info "Specialized Vector DBs (Pinecone, Weaviate, Qdrant)"
    - Additional service dependency increases complexity
    - Limited relational capabilities
    - Vendor lock-in concerns
    - Cost considerations for managed services
    - Excellent vector search performance
    - Purpose-built for embeddings

!!! note "SQLite"
    - Limited concurrency (write locks)
    - No native vector search (extensions experimental)
    - Not suitable for multi-robot scenarios
    - Simple deployment
    - Zero configuration

---

## Implementation Details

### Schema Design

```sql
-- Nodes table as TimescaleDB hypertable
CREATE TABLE nodes (
  id SERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  embedding vector(1536),
  robot_id TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  importance FLOAT DEFAULT 1.0,
  type TEXT,
  metadata JSONB
);

-- Convert to hypertable (TimescaleDB)
SELECT create_hypertable('nodes', 'created_at');

-- Vector indexing (HNSW for approximate nearest neighbor)
CREATE INDEX nodes_embedding_idx ON nodes
USING hnsw (embedding vector_cosine_ops);

-- Full-text indexing
CREATE INDEX nodes_fts_idx ON nodes
USING GIN (to_tsvector('english', value));

-- Additional indexes
CREATE INDEX nodes_robot_id_idx ON nodes (robot_id);
CREATE INDEX nodes_created_at_idx ON nodes (created_at DESC);
CREATE INDEX nodes_type_idx ON nodes (type);
```

### Connection Configuration

```ruby
# Via environment variable (preferred)
ENV['HTM_DBURL'] = "postgresql://user:pass@host:port/dbname?sslmode=require"

# Parsed into connection hash
{
  host: 'host',
  port: 5432,
  dbname: 'tsdb',
  user: 'tsdbadmin',
  password: 'secret',
  sslmode: 'require'
}
```

### Key Features Enabled

**Vector similarity search**:
```sql
-- Find semantically similar nodes
SELECT *, 1 - (embedding <=> $1::vector) as similarity
FROM nodes
WHERE created_at > NOW() - INTERVAL '30 days'
ORDER BY embedding <=> $1::vector
LIMIT 10;
```

**Full-text search**:
```sql
-- Find nodes containing keywords
SELECT *, ts_rank(to_tsvector('english', value),
                  plainto_tsquery('english', $1)) as rank
FROM nodes
WHERE to_tsvector('english', value) @@ plainto_tsquery('english', $1)
ORDER BY rank DESC
LIMIT 10;
```

**Time-range queries** (optimized by chunk exclusion):
```sql
-- Fast time-range query (TimescaleDB prunes chunks)
SELECT * FROM nodes
WHERE created_at BETWEEN '2025-10-01' AND '2025-10-25'
AND robot_id = 'robot-123'
ORDER BY created_at DESC;
```

**Automatic compression**:
```sql
-- Compress chunks older than 30 days
SELECT add_compression_policy('nodes', INTERVAL '30 days');

-- Segment by robot_id and type for better compression
ALTER TABLE nodes SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'robot_id, type'
);
```

---

## Consequences

### Positive

- Production-ready with battle-tested reliability
- Multi-modal search: vector, full-text, and hybrid strategies
- Time-series optimization for efficient temporal queries
- Cost-effective storage with compression reducing cloud costs
- Familiar tooling: standard PostgreSQL tools and practices
- Flexible querying: full SQL power for complex operations
- ACID guarantees for critical memory operations

### Negative

- Operational complexity requires database management (mitigated by managed service)
- Vertical scaling limits (mitigated by partitioning)
- Connection overhead: PostgreSQL connections relatively heavy
- Vector search performance slower than specialized vector DBs at massive scale

### Neutral

- Learning curve: developers need PostgreSQL + TimescaleDB knowledge
- Cloud dependency: currently using TimescaleDB Cloud (could self-host)
- Extension management requires extensions (timescaledb, pgvector, pg_trgm)

---

## Risks and Mitigations

### Risk: Extension Availability

!!! danger "Risk"
    Extensions not available in all PostgreSQL environments

**Likelihood**: Low (extensions widely available)
**Impact**: High (breaks core functionality)
**Mitigation**: Document requirements clearly, verify in setup process

### Risk: Connection Exhaustion

!!! warning "Risk"
    PostgreSQL connections limited (default ~100)

**Likelihood**: Medium (with many robots)
**Impact**: Medium (service degradation)
**Mitigation**: Implement connection pooling (ConnectionPool gem)

### Risk: Storage Costs

!!! info "Risk"
    Vector data storage can be expensive at scale

**Likelihood**: Medium (depends on usage)
**Impact**: Medium (operational cost)
**Mitigation**: Compression policies, retention policies, archival strategies

### Risk: Query Performance at Scale

!!! warning "Risk"
    Complex hybrid searches may slow with millions of nodes

**Likelihood**: Low (with proper indexing)
**Impact**: Medium (user experience)
**Mitigation**: Query optimization, read replicas, caching layer

---

## Alternatives Comparison

| Solution | Pros | Cons | Decision |
|----------|------|------|----------|
| Pure PostgreSQL | Simple, reliable, pgvector | No time-series optimization | Rejected |
| **PostgreSQL + TimescaleDB** | **Best of both worlds** | **Slight complexity** | **ACCEPTED** |
| Elasticsearch | Excellent full-text search | High resource usage, complexity | Rejected |
| Pinecone | Purpose-built vectors | Vendor lock-in, cost, limited relational | Rejected |
| SQLite | Simple, embedded | Limited concurrency, no vectors | Rejected |

---

## Future Considerations

- **Read replicas**: For query scaling when needed
- **Partitioning strategies**: By robot_id for tenant isolation
- **Caching layer**: Redis for hot nodes
- **Archive tier**: S3/Glacier for very old memories
- **Multi-region**: For global deployment

---

## References

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [HTM Database Schema Guide](../../development/schema.md)
- [HTM Configuration Guide](../../getting-started/installation.md)

---

## Review Notes

**Systems Architect**: Solid choice for time-series + vector workload. Consider read replicas for scaling.

**Database Architect**: Excellent indexing strategy. Monitor query performance as data grows.

**Performance Specialist**: TimescaleDB compression will help with costs. Add connection pooling soon.

**Maintainability Expert**: PostgreSQL tooling is mature and well-documented. Good choice for long-term maintenance.
