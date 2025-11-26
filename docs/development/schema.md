# Database Schema Documentation

This document provides a comprehensive reference for HTM's PostgreSQL database schema, including all tables, indexes, and relationships.

## Schema Overview

HTM uses PostgreSQL 17 with pgvector and pg_trgm extensions to provide:

- **Vector similarity search** via pgvector for semantic memory retrieval
- **Full-text search** with PostgreSQL's built-in tsvector capabilities
- **Fuzzy matching** using pg_trgm for flexible text search
- **Many-to-many relationships** for flexible tagging and categorization

### Required Extensions

HTM requires these PostgreSQL extensions:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
```

## Entity-Relationship Diagram

Here's the complete database structure:

![HTM Entity-Relationship Diagram](../images/htm-er-diagram.svg)

## Table Definitions

### robots

The robots table stores registration and metadata for all LLM agents using the HTM system.

**Purpose**: Registry of all robots (LLM agents) with their configuration and activity tracking.

```sql
CREATE TABLE public.robots (
    id bigint NOT NULL,
    name text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    last_active timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    metadata jsonb
);

ALTER TABLE ONLY public.robots ALTER COLUMN id SET DEFAULT nextval('public.robots_id_seq'::regclass);
ALTER TABLE ONLY public.robots ADD CONSTRAINT robots_pkey PRIMARY KEY (id);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `name` | TEXT | YES | NULL | Human-readable name for the robot |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When the robot was first registered |
| `last_active` | TIMESTAMPTZ | YES | NOW() | Last time the robot accessed the system |
| `metadata` | JSONB | YES | NULL | Robot-specific configuration and metadata |

**Indexes**:
- `PRIMARY KEY` on `id`

**Relationships**:
- Many robots have many nodes through robot_nodes (N:M)

---

### nodes

The core table storing all memory nodes with vector embeddings for semantic search.

**Purpose**: Stores all memories (conversation messages, facts, etc.) with full-text and vector search capabilities. Nodes are shared across robots via the `robot_nodes` join table, enabling a "hive mind" architecture where identical content is stored once and referenced by multiple robots.

```sql
CREATE TABLE public.nodes (
    id bigint NOT NULL,
    content text NOT NULL,
    access_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    last_accessed timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    token_count integer,
    in_working_memory boolean DEFAULT false,
    embedding public.vector(2000),
    embedding_dimension integer,
    content_hash character varying(64),
    CONSTRAINT check_embedding_dimension CHECK (((embedding_dimension IS NULL) OR ((embedding_dimension > 0) AND (embedding_dimension <= 2000))))
);

ALTER TABLE ONLY public.nodes ALTER COLUMN id SET DEFAULT nextval('public.nodes_id_seq'::regclass);
ALTER TABLE ONLY public.nodes ADD CONSTRAINT nodes_pkey PRIMARY KEY (id);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `content` | TEXT | NO | - | The conversation message/utterance content |
| `content_hash` | VARCHAR(64) | YES | NULL | SHA-256 hash of content for deduplication |
| `access_count` | INTEGER | NO | 0 | Number of times this node has been accessed/retrieved |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When this memory was created |
| `updated_at` | TIMESTAMPTZ | YES | NOW() | When this memory was last modified |
| `last_accessed` | TIMESTAMPTZ | YES | NOW() | When this memory was last accessed |
| `token_count` | INTEGER | YES | NULL | Number of tokens in the content (for context budget management) |
| `in_working_memory` | BOOLEAN | YES | FALSE | Whether this memory is currently in working memory |
| `embedding` | vector(2000) | YES | NULL | Vector embedding (max 2000 dimensions) for semantic search |
| `embedding_dimension` | INTEGER | YES | NULL | Actual number of dimensions used in the embedding vector (max 2000) |

**Indexes**:

- `PRIMARY KEY` on `id`
- `idx_nodes_content_hash_unique` UNIQUE BTREE on `content_hash` - Enforces content deduplication
- `idx_nodes_access_count` BTREE on `access_count`
- `idx_nodes_created_at` BTREE on `created_at`
- `idx_nodes_updated_at` BTREE on `updated_at`
- `idx_nodes_last_accessed` BTREE on `last_accessed`
- `idx_nodes_in_working_memory` BTREE on `in_working_memory`
- `idx_nodes_embedding` HNSW on `embedding` using `vector_cosine_ops` (m=16, ef_construction=64)
- `idx_nodes_content_gin` GIN on `to_tsvector('english', content)` for full-text search
- `idx_nodes_content_trgm` GIN on `content` using `gin_trgm_ops` for fuzzy matching

**Relationships**:
- Many nodes have many robots through robot_nodes (N:M)
- Many nodes have many tags through node_tags (N:M)

**Check Constraints**:
- `check_embedding_dimension`: Ensures embedding_dimension is NULL or between 1 and 2000

**Deduplication**:

Content deduplication is enforced via SHA-256 hashing:

1. When `remember()` is called, a SHA-256 hash of the content is computed
2. If a node with the same `content_hash` exists, the existing node is reused
3. A new `robot_nodes` association is created (or updated if it already exists)
4. This ensures identical memories are stored once but can be "remembered" by multiple robots

---

### robot_nodes

The robot_nodes join table implements the many-to-many relationship between robots and nodes, enabling shared memory across robots.

**Purpose**: Links robots to nodes, allowing each node to be remembered by multiple robots and each robot to access multiple nodes. This enables the "hive mind" architecture where robots share memories. Also tracks per-robot remember metadata (when/how often a robot remembered content).

```sql
CREATE TABLE public.robot_nodes (
    id bigint NOT NULL,
    robot_id bigint NOT NULL,
    node_id bigint NOT NULL,
    first_remembered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    last_remembered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    remember_count integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE ONLY public.robot_nodes ALTER COLUMN id SET DEFAULT nextval('public.robot_nodes_id_seq'::regclass);
ALTER TABLE ONLY public.robot_nodes ADD CONSTRAINT robot_nodes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.robot_nodes
    ADD CONSTRAINT fk_rails_9b003078a8 FOREIGN KEY (robot_id) REFERENCES public.robots(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.robot_nodes
    ADD CONSTRAINT fk_rails_f2fc98d49e FOREIGN KEY (node_id) REFERENCES public.nodes(id) ON DELETE CASCADE;
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `robot_id` | BIGINT | NO | - | ID of the robot that remembered this node |
| `node_id` | BIGINT | NO | - | ID of the node being remembered |
| `first_remembered_at` | TIMESTAMPTZ | YES | NOW() | When this robot first remembered this content |
| `last_remembered_at` | TIMESTAMPTZ | YES | NOW() | When this robot last tried to remember this content |
| `remember_count` | INTEGER | NO | 1 | Number of times this robot has tried to remember this content |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When this association was created |
| `updated_at` | TIMESTAMPTZ | YES | NOW() | When this association was last modified |

**Indexes**:
- `PRIMARY KEY` on `id`
- `idx_robot_nodes_unique` UNIQUE BTREE on `(robot_id, node_id)` - Prevents duplicate associations
- `idx_robot_nodes_robot_id` BTREE on `robot_id` - Fast lookups of nodes for a robot
- `idx_robot_nodes_node_id` BTREE on `node_id` - Fast lookups of robots for a node
- `idx_robot_nodes_last_remembered_at` BTREE on `last_remembered_at` - For temporal queries

**Foreign Keys**:
- `robot_id` references `robots(id)` ON DELETE CASCADE
- `node_id` references `nodes(id)` ON DELETE CASCADE

**Cascade Behavior**:
- When a robot is deleted, all its node associations are automatically removed
- When a node is deleted, all associations to that node are automatically removed
- The join table ensures referential integrity between robots and nodes

**Remember Tracking**:

The `robot_nodes` table tracks per-robot remember metadata:

1. `first_remembered_at` - When this robot first encountered this content
2. `last_remembered_at` - Updated each time the robot tries to remember the same content
3. `remember_count` - Incremented each time (useful for identifying frequently reinforced memories)

This allows querying for:
- Recently reinforced memories: `ORDER BY last_remembered_at DESC`
- Frequently remembered content: `ORDER BY remember_count DESC`
- New vs old memories: Compare `first_remembered_at` across robots

---

### tags

The tags table stores unique hierarchical tag names for categorization.

**Purpose**: Provides flexible, hierarchical categorization using colon-separated namespaces (e.g., `database:postgresql:timescaledb`).

```sql
CREATE TABLE public.tags (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);
ALTER TABLE ONLY public.tags ADD CONSTRAINT tags_pkey PRIMARY KEY (id);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `name` | TEXT | NO | - | Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb) |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When this tag was created |

**Indexes**:
- `PRIMARY KEY` on `id`
- `idx_tags_name_unique` UNIQUE BTREE on `name`
- `idx_tags_name_pattern` BTREE on `name` with `text_pattern_ops` for pattern matching

**Relationships**:
- Many tags belong to many nodes through nodes_tags (N:M)

**Tag Hierarchy**:

Tags use colon-separated hierarchies for organization:
- `programming:ruby:gems` - Programming > Ruby > Gems
- `database:postgresql:extensions` - Database > PostgreSQL > Extensions
- `ai:llm:embeddings` - AI > LLM > Embeddings

This allows querying by prefix to find all related tags:
```sql
SELECT * FROM tags WHERE name LIKE 'database:%';  -- All database-related tags
SELECT * FROM tags WHERE name LIKE 'ai:llm:%';    -- All LLM-related tags
```

---

### node_tags

The node_tags join table implements the many-to-many relationship between nodes and tags.

**Purpose**: Links nodes to tags, allowing each node to have multiple tags and each tag to be applied to multiple nodes.

```sql
CREATE TABLE public.node_tags (
    id bigint NOT NULL,
    node_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE ONLY public.node_tags ALTER COLUMN id SET DEFAULT nextval('public.node_tags_id_seq'::regclass);
ALTER TABLE ONLY public.node_tags ADD CONSTRAINT node_tags_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.node_tags
    ADD CONSTRAINT fk_rails_b51cdcc57f FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.node_tags
    ADD CONSTRAINT fk_rails_ebc9aafd9f FOREIGN KEY (node_id) REFERENCES public.nodes(id) ON DELETE CASCADE;
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `node_id` | BIGINT | NO | - | ID of the node being tagged |
| `tag_id` | BIGINT | NO | - | ID of the tag being applied |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When this association was created |

**Indexes**:
- `PRIMARY KEY` on `id`
- `idx_node_tags_unique` UNIQUE BTREE on `(node_id, tag_id)` - Prevents duplicate associations
- `idx_node_tags_node_id` BTREE on `node_id` - Fast lookups of tags for a node
- `idx_node_tags_tag_id` BTREE on `tag_id` - Fast lookups of nodes for a tag

**Foreign Keys**:
- `node_id` references `nodes(id)` ON DELETE CASCADE
- `tag_id` references `tags(id)` ON DELETE CASCADE

**Cascade Behavior**:
- When a node is deleted, all its tag associations are automatically removed
- When a tag is deleted, all associations to that tag are automatically removed
- The join table ensures referential integrity between nodes and tags

---

## Common Query Patterns

### Finding Nodes for a Robot

```sql
SELECT n.*
FROM nodes n
JOIN robot_nodes rn ON n.id = rn.node_id
WHERE rn.robot_id = $1
ORDER BY rn.last_remembered_at DESC;
```

### Finding Robots that Share a Node

```sql
SELECT r.*
FROM robots r
JOIN robot_nodes rn ON r.id = rn.robot_id
WHERE rn.node_id = $1
ORDER BY rn.first_remembered_at;
```

### Finding Frequently Remembered Content

```sql
SELECT n.*, rn.remember_count, rn.first_remembered_at, rn.last_remembered_at
FROM nodes n
JOIN robot_nodes rn ON n.id = rn.node_id
WHERE rn.robot_id = $1
ORDER BY rn.remember_count DESC
LIMIT 10;
```

### Finding Tags for a Node

```sql
SELECT t.name
FROM tags t
JOIN node_tags nt ON t.id = nt.tag_id
WHERE nt.node_id = $1
ORDER BY t.name;
```

### Finding Nodes with a Specific Tag

```sql
SELECT n.*
FROM nodes n
JOIN node_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name = 'database:postgresql'
ORDER BY n.created_at DESC;
```

### Finding Nodes with Hierarchical Tag Prefix

```sql
SELECT n.*
FROM nodes n
JOIN node_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name LIKE 'ai:llm:%'
ORDER BY n.created_at DESC;
```

### Finding Related Topics by Shared Nodes

```sql
SELECT
    t1.name AS topic1,
    t2.name AS topic2,
    COUNT(DISTINCT nt1.node_id) AS shared_nodes
FROM tags t1
JOIN node_tags nt1 ON t1.id = nt1.tag_id
JOIN node_tags nt2 ON nt1.node_id = nt2.node_id
JOIN tags t2 ON nt2.tag_id = t2.id
WHERE t1.name < t2.name
GROUP BY t1.name, t2.name
HAVING COUNT(DISTINCT nt1.node_id) >= 2
ORDER BY shared_nodes DESC;
```

### Vector Similarity Search with Tag Filter

```sql
SELECT n.*, n.embedding <=> $1::vector AS distance
FROM nodes n
JOIN node_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name = 'programming:ruby'
  AND n.embedding IS NOT NULL
ORDER BY distance
LIMIT 10;
```

### Full-Text Search with Tag Filter

```sql
SELECT n.*, ts_rank(to_tsvector('english', n.content), query) AS rank
FROM nodes n
JOIN node_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id,
     to_tsquery('english', 'database & optimization') query
WHERE to_tsvector('english', n.content) @@ query
  AND t.name LIKE 'database:%'
ORDER BY rank DESC
LIMIT 20;
```

### Finding Content Shared by Multiple Robots

```sql
SELECT n.*, COUNT(DISTINCT rn.robot_id) AS robot_count
FROM nodes n
JOIN robot_nodes rn ON n.id = rn.node_id
GROUP BY n.id
HAVING COUNT(DISTINCT rn.robot_id) > 1
ORDER BY robot_count DESC;
```

---

## Database Optimization

### Vector Search Performance

The `idx_nodes_embedding` index uses HNSW (Hierarchical Navigable Small World) algorithm for fast approximate nearest neighbor search:

- **m=16**: Number of bi-directional links per node (higher = better recall, more memory)
- **ef_construction=64**: Size of dynamic candidate list during index construction (higher = better quality, slower build)

For queries, you can adjust `ef_search` (defaults to 40):
```sql
SET hnsw.ef_search = 100;  -- Better recall, slower queries
```

### Full-Text Search Performance

The `idx_nodes_content_gin` index enables fast full-text search using PostgreSQL's tsvector:

```sql
-- Query optimization with explicit tsvector
SELECT * FROM nodes
WHERE to_tsvector('english', content) @@ to_tsquery('english', 'memory & retrieval');
```

### Fuzzy Matching Performance

The `idx_nodes_content_trgm` index enables similarity search and pattern matching:

```sql
-- Similarity search
SELECT * FROM nodes
WHERE content % 'semantic retreval';  -- Handles typos

-- Pattern matching
SELECT * FROM nodes
WHERE content ILIKE '%memry%';  -- Uses trigram index
```

### Index Maintenance

Monitor and maintain indexes for optimal performance:

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Reindex if needed
REINDEX INDEX CONCURRENTLY idx_nodes_embedding;
REINDEX INDEX CONCURRENTLY idx_nodes_content_gin;
```

---

## Schema Migration

The schema is managed through ActiveRecord migrations located in `db/migrate/`:

1. `20250101000001_create_robots.rb` - Creates robots table
2. `20250101000002_create_nodes.rb` - Creates nodes table with all indexes
3. `20250101000005_create_tags.rb` - Creates tags and nodes_tags tables

To apply migrations:
```bash
bundle exec rake htm:db:migrate
```

To generate the current schema dump:
```bash
bundle exec rake htm:db:schema:dump
```

The canonical schema is maintained in `db/schema.sql`.

---

## Database Extensions

### pgvector

Provides vector similarity search capabilities:

```sql
-- Install extension
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- Vector operations
SELECT embedding <=> $1::vector AS cosine_distance FROM nodes;  -- Cosine distance
SELECT embedding <-> $1::vector AS l2_distance FROM nodes;      -- L2 distance
SELECT embedding <#> $1::vector AS inner_product FROM nodes;    -- Inner product
```

### pg_trgm

Provides trigram-based fuzzy text matching:

```sql
-- Install extension
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

-- Trigram operations
SELECT content % 'search term' FROM nodes;           -- Similarity operator
SELECT similarity(content, 'search term') FROM nodes; -- Similarity score
SELECT content ILIKE '%pattern%' FROM nodes;          -- Pattern matching (uses trigram index)
```

---

## Best Practices

### Tagging Strategy

1. **Use hierarchical namespaces**: `category:subcategory:detail`
2. **Be consistent with naming**: Use lowercase, singular nouns
3. **Limit depth**: 2-3 levels is optimal (e.g., `ai:llm:embeddings`)
4. **Avoid redundancy**: Don't duplicate information already in node fields

### Node Management

1. **Set appropriate importance**: Use 0.0-1.0 scale for priority-based retrieval
2. **Update last_accessed**: Touch timestamp when retrieving for LRU eviction
3. **Manage token_count**: Update when content changes for working memory budget
4. **Use appropriate types**: fact, context, code, preference, decision, question

### Search Strategy

1. **Vector search**: Best for semantic similarity ("concepts like X")
2. **Full-text search**: Best for keyword matching ("documents containing Y")
3. **Fuzzy search**: Best for typo tolerance and pattern matching
4. **Hybrid search**: Combine vector + full-text with weighted scores

### Performance Tuning

1. **Monitor index usage**: Use pg_stat_user_indexes
2. **Vacuum regularly**: Especially after bulk deletes
3. **Adjust HNSW parameters**: Balance recall vs speed based on dataset size
4. **Use connection pooling**: Managed by HTM::LongTermMemory
