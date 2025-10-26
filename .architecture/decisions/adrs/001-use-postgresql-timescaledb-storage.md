# ADR-001: Use PostgreSQL with TimescaleDB for Storage

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

## Context

HTM requires a persistent storage solution that can handle:

- Time-series data with efficient time-range queries
- Vector embeddings for semantic search
- Full-text search capabilities
- ACID compliance for data integrity
- Scalability for growing memory databases
- Production-grade reliability

Alternative options considered:

1. **Pure PostgreSQL**: Solid relational database, pgvector support
2. **TimescaleDB**: PostgreSQL extension optimized for time-series
3. **Elasticsearch**: Strong full-text search, vector support added
4. **Pinecone/Weaviate**: Specialized vector databases
5. **SQLite + extensions**: Simple, embedded option

## Decision

We will use **PostgreSQL with TimescaleDB** as the primary storage backend for HTM.

## Rationale

### Why PostgreSQL?

- **Production-proven**: Decades of reliability in demanding environments
- **ACID compliance**: Guarantees data integrity for memory operations
- **Rich ecosystem**: Extensive tooling, monitoring, and support
- **pgvector extension**: Native vector similarity search with HNSW indexing
- **Full-text search**: Built-in tsvector with GIN indexing
- **pg_trgm extension**: Trigram-based fuzzy matching
- **Strong typing**: Schema enforcement prevents data corruption
- **Wide adoption**: Well-understood by developers

### Why TimescaleDB?

- **Hypertable partitioning**: Automatic chunk-based time partitioning
- **Compression policies**: Automatic compression of old data (70-90% reduction)
- **Time-range optimization**: Fast queries on temporal data
- **PostgreSQL compatibility**: Drop-in extension, not a fork
- **Continuous aggregates**: Pre-computed summaries for analytics
- **Retention policies**: Automatic data lifecycle management
- **Cloud offering**: Managed service available (TimescaleDB Cloud)

### Why Not Alternatives?

**Elasticsearch**:

- ❌ Operational complexity (JVM tuning, cluster management)
- ❌ Higher resource usage
- ❌ Vector support more recent, less mature
- ✅ Superior full-text search (not critical for our use case)

**Specialized Vector DBs** (Pinecone, Weaviate, Qdrant):

- ❌ Additional service dependency
- ❌ Limited relational capabilities
- ❌ Vendor lock-in concerns
- ❌ Cost considerations for managed services
- ✅ Excellent vector search performance
- ✅ Purpose-built for embeddings

**SQLite**:

- ❌ Limited concurrency (write locks)
- ❌ No native vector search (extensions experimental)
- ❌ Not suitable for multi-robot scenarios
- ✅ Simple deployment
- ✅ Zero configuration

## Implementation Details

### Schema Design

- **nodes table**: TimescaleDB hypertable partitioned by `created_at`
- **operations_log**: TimescaleDB hypertable for audit trail
- **Vector indexing**: HNSW algorithm for approximate nearest neighbor
- **Full-text indexing**: GIN indexes on tsvector columns
- **Compression**: Automatic after 30 days, segmented by robot_id and type

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

- Vector similarity search with `<=>` operator (cosine distance)
- Full-text search with `to_tsvector()` and `@@` operator
- Trigram fuzzy matching with `pg_trgm`
- Time-range queries optimized by chunk exclusion
- Automatic compression of old chunks

## Consequences

### Positive

✅ **Production-ready**: Battle-tested database with proven reliability
✅ **Multi-modal search**: Vector, full-text, and hybrid strategies
✅ **Time-series optimization**: Efficient temporal queries
✅ **Cost-effective storage**: Compression reduces cloud storage costs
✅ **Familiar tooling**: Standard PostgreSQL tools and practices apply
✅ **Flexible querying**: Full SQL power for complex operations
✅ **ACID guarantees**: Data integrity for critical memory operations

### Negative

❌ **Operational complexity**: Requires database management (mitigated by managed service)
❌ **Scaling limits**: Vertical scaling limits (mitigated by partitioning)
❌ **Connection overhead**: PostgreSQL connections are relatively heavy
❌ **Vector search performance**: Slower than specialized vector DBs at massive scale

### Neutral

➡️ **Learning curve**: Developers need PostgreSQL + TimescaleDB knowledge
➡️ **Cloud dependency**: Currently using TimescaleDB Cloud (could self-host)
➡️ **Extension management**: Requires extensions (timescaledb, pgvector, pg_trgm)

## Risks and Mitigations

### Risk: Extension Availability

- **Risk**: Extensions not available in all PostgreSQL environments
- **Likelihood**: Low (extensions widely available)
- **Impact**: High (breaks core functionality)
- **Mitigation**: Document requirements clearly, verify in setup process

### Risk: Connection Exhaustion

- **Risk**: PostgreSQL connections limited (default ~100)
- **Likelihood**: Medium (with many robots)
- **Impact**: Medium (service degradation)
- **Mitigation**: Implement connection pooling (ConnectionPool gem)

### Risk: Storage Costs

- **Risk**: Vector data storage can be expensive at scale
- **Likelihood**: Medium (depends on usage)
- **Impact**: Medium (operational cost)
- **Mitigation**: Compression policies, retention policies, archival strategies

### Risk: Query Performance at Scale

- **Risk**: Complex hybrid searches may slow down with millions of nodes
- **Likelihood**: Low (with proper indexing)
- **Impact**: Medium (user experience)
- **Mitigation**: Query optimization, read replicas, caching layer

## Alternatives Considered

| Solution | Pros | Cons | Decision |
|----------|------|------|----------|
| Pure PostgreSQL | Simple, reliable, pgvector | No time-series optimization | ❌ Rejected |
| PostgreSQL + TimescaleDB | Best of both worlds | Slight complexity increase | ✅ **Accepted** |
| Elasticsearch | Excellent full-text search | High resource usage, complexity | ❌ Rejected |
| Pinecone | Purpose-built vectors | Vendor lock-in, cost, limited relational | ❌ Rejected |
| SQLite | Simple, embedded | Limited concurrency, no vectors | ❌ Rejected |

## Future Considerations

- **Read replicas**: For query scaling when needed
- **Partitioning strategies**: By robot_id for tenant isolation
- **Caching layer**: Redis for hot nodes
- **Archive tier**: S3/Glacier for very old memories
- **Multi-region**: For global deployment

## References

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [HTM Planning Document](../../htm_teamwork.md)

## Review Notes

**Systems Architect**: ✅ Solid choice for time-series + vector workload. Consider read replicas for scaling.

**Database Architect**: ✅ Excellent indexing strategy. Monitor query performance as data grows.

**Performance Specialist**: ✅ TimescaleDB compression will help with costs. Add connection pooling soon.

**Maintainability Expert**: ✅ PostgreSQL tooling is mature and well-documented. Good choice for long-term maintenance.
