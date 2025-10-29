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

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 900" style="background: transparent;">
  <defs>
    <style>
      .table-box { fill: #1e1e1e; stroke: #4a9eff; stroke-width: 2; }
      .table-header { fill: #2d5a8e; }
      .text-header { fill: #ffffff; font-family: monospace; font-size: 14px; font-weight: bold; }
      .text-field { fill: #d4d4d4; font-family: monospace; font-size: 11px; }
      .text-type { fill: #8cb4e8; font-family: monospace; font-size: 10px; }
      .relation-line { stroke: #4a9eff; stroke-width: 1.5; fill: none; }
      .arrow { fill: #4a9eff; }
      .join-table { fill: #1e3a1e; stroke: #4a9eff; stroke-width: 2; }
    </style>
  </defs>

  <!-- Robots Table -->
  <rect class="table-box" x="50" y="50" width="280" height="140" rx="5"/>
  <rect class="table-header" x="50" y="50" width="280" height="35" rx="5"/>
  <text class="text-header" x="190" y="73" text-anchor="middle">robots</text>

  <text class="text-field" x="60" y="100">id</text>
  <text class="text-type" x="320" y="100" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="60" y="120">name</text>
  <text class="text-type" x="320" y="120" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="140">created_at</text>
  <text class="text-type" x="320" y="140" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="160">last_active</text>
  <text class="text-type" x="320" y="160" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="180">metadata</text>
  <text class="text-type" x="320" y="180" text-anchor="end">JSONB</text>

  <!-- Nodes Table -->
  <rect class="table-box" x="50" y="250" width="280" height="400" rx="5"/>
  <rect class="table-header" x="50" y="250" width="280" height="35" rx="5"/>
  <text class="text-header" x="190" y="273" text-anchor="middle">nodes</text>

  <text class="text-field" x="60" y="300">id</text>
  <text class="text-type" x="320" y="300" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="60" y="320">content</text>
  <text class="text-type" x="320" y="320" text-anchor="end">TEXT NOT NULL</text>

  <text class="text-field" x="60" y="340">speaker</text>
  <text class="text-type" x="320" y="340" text-anchor="end">TEXT NOT NULL</text>

  <text class="text-field" x="60" y="360">type</text>
  <text class="text-type" x="320" y="360" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="380">category</text>
  <text class="text-type" x="320" y="380" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="400">importance</text>
  <text class="text-type" x="320" y="400" text-anchor="end">DOUBLE PRECISION</text>

  <text class="text-field" x="60" y="420">created_at</text>
  <text class="text-type" x="320" y="420" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="440">updated_at</text>
  <text class="text-type" x="320" y="440" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="460">last_accessed</text>
  <text class="text-type" x="320" y="460" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="480">token_count</text>
  <text class="text-type" x="320" y="480" text-anchor="end">INTEGER</text>

  <text class="text-field" x="60" y="500">in_working_memory</text>
  <text class="text-type" x="320" y="500" text-anchor="end">BOOLEAN</text>

  <text class="text-field" x="60" y="520">robot_id</text>
  <text class="text-type" x="320" y="520" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="60" y="540">embedding</text>
  <text class="text-type" x="320" y="540" text-anchor="end">vector(2000)</text>

  <text class="text-field" x="60" y="560">embedding_dimension</text>
  <text class="text-type" x="320" y="560" text-anchor="end">INTEGER</text>

  <!-- Tags Table -->
  <rect class="table-box" x="850" y="250" width="280" height="120" rx="5"/>
  <rect class="table-header" x="850" y="250" width="280" height="35" rx="5"/>
  <text class="text-header" x="990" y="273" text-anchor="middle">tags</text>

  <text class="text-field" x="860" y="300">id</text>
  <text class="text-type" x="1120" y="300" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="860" y="320">name</text>
  <text class="text-type" x="1120" y="320" text-anchor="end">TEXT UNIQUE</text>

  <text class="text-field" x="860" y="340">created_at</text>
  <text class="text-type" x="1120" y="340" text-anchor="end">TIMESTAMPTZ</text>

  <!-- nodes_tags Join Table -->
  <rect class="join-table" x="450" y="420" width="280" height="140" rx="5"/>
  <rect class="table-header" x="450" y="420" width="280" height="35" rx="5"/>
  <text class="text-header" x="590" y="443" text-anchor="middle">nodes_tags</text>

  <text class="text-field" x="460" y="470">id</text>
  <text class="text-type" x="720" y="470" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="460" y="490">node_id</text>
  <text class="text-type" x="720" y="490" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="460" y="510">tag_id</text>
  <text class="text-type" x="720" y="510" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="460" y="530">created_at</text>
  <text class="text-type" x="720" y="530" text-anchor="end">TIMESTAMPTZ</text>

  <!-- Relationships: robots -> nodes -->
  <path class="relation-line" d="M 190 190 L 190 250"/>
  <polygon class="arrow" points="190,250 185,240 195,240"/>

  <!-- Relationships: nodes -> nodes_tags -->
  <path class="relation-line" d="M 330 490 L 450 490"/>
  <polygon class="arrow" points="450,490 440,485 440,495"/>

  <!-- Relationships: tags -> nodes_tags -->
  <path class="relation-line" d="M 850 310 L 730 310 L 730 510 L 730 510"/>
  <polygon class="arrow" points="730,510 725,500 735,500"/>

  <!-- Legend -->
  <text class="text-field" x="50" y="720" font-weight="bold">Legend:</text>
  <text class="text-field" x="50" y="740">PK = Primary Key</text>
  <text class="text-field" x="200" y="740">FK = Foreign Key</text>
  <text class="text-field" x="50" y="760">Green box = Join table (many-to-many)</text>

  <!-- Annotations -->
  <text class="text-field" x="400" y="370" font-style="italic">1:N</text>
  <text class="text-field" x="380" y="480" font-style="italic">N:M</text>
  <text class="text-field" x="770" y="480" font-style="italic">N:M</text>
</svg>
```

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
- One robot has many nodes (1:N)

---

### nodes

The core table storing all memory nodes with vector embeddings for semantic search.

**Purpose**: Stores all memories (conversation messages, facts, decisions, code, etc.) with full-text and vector search capabilities.

```sql
CREATE TABLE public.nodes (
    id bigint NOT NULL,
    content text NOT NULL,
    speaker text NOT NULL,
    type text,
    category text,
    importance double precision DEFAULT 1.0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    last_accessed timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    token_count integer,
    in_working_memory boolean DEFAULT false,
    robot_id bigint NOT NULL,
    embedding public.vector(2000),
    embedding_dimension integer,
    CONSTRAINT check_embedding_dimension CHECK (((embedding_dimension IS NULL) OR ((embedding_dimension > 0) AND (embedding_dimension <= 2000))))
);

ALTER TABLE ONLY public.nodes ALTER COLUMN id SET DEFAULT nextval('public.nodes_id_seq'::regclass);
ALTER TABLE ONLY public.nodes ADD CONSTRAINT nodes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.nodes
    ADD CONSTRAINT fk_rails_60162e9d3a FOREIGN KEY (robot_id) REFERENCES public.robots(id) ON DELETE CASCADE;
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGINT | NO | AUTO | Unique identifier (primary key) |
| `content` | TEXT | NO | - | The conversation message/utterance content |
| `speaker` | TEXT | NO | - | Who said it: user or robot name |
| `type` | TEXT | YES | NULL | Memory type: fact, context, code, preference, decision, question |
| `category` | TEXT | YES | NULL | Optional category for organizing memories |
| `importance` | DOUBLE PRECISION | YES | 1.0 | Importance score (0.0-1.0) for prioritizing recall |
| `created_at` | TIMESTAMPTZ | YES | NOW() | When this memory was created |
| `updated_at` | TIMESTAMPTZ | YES | NOW() | When this memory was last modified |
| `last_accessed` | TIMESTAMPTZ | YES | NOW() | When this memory was last accessed |
| `token_count` | INTEGER | YES | NULL | Number of tokens in the content (for context budget management) |
| `in_working_memory` | BOOLEAN | YES | FALSE | Whether this memory is currently in working memory |
| `robot_id` | BIGINT | NO | - | ID of the robot that owns this memory |
| `embedding` | vector(2000) | YES | NULL | Vector embedding (max 2000 dimensions) for semantic search |
| `embedding_dimension` | INTEGER | YES | NULL | Actual number of dimensions used in the embedding vector (max 2000) |

**Indexes**:

- `PRIMARY KEY` on `id`
- `idx_nodes_robot_id` BTREE on `robot_id`
- `idx_nodes_speaker` BTREE on `speaker`
- `idx_nodes_type` BTREE on `type`
- `idx_nodes_category` BTREE on `category`
- `idx_nodes_created_at` BTREE on `created_at`
- `idx_nodes_updated_at` BTREE on `updated_at`
- `idx_nodes_last_accessed` BTREE on `last_accessed`
- `idx_nodes_in_working_memory` BTREE on `in_working_memory`
- `idx_nodes_embedding` HNSW on `embedding` using `vector_cosine_ops` (m=16, ef_construction=64)
- `idx_nodes_content_gin` GIN on `to_tsvector('english', content)` for full-text search
- `idx_nodes_content_trgm` GIN on `content` using `gin_trgm_ops` for fuzzy matching

**Foreign Keys**:
- `robot_id` references `robots(id)` ON DELETE CASCADE

**Relationships**:
- Many nodes belong to one robot (N:1)
- Many nodes have many tags through nodes_tags (N:M)

**Check Constraints**:
- `check_embedding_dimension`: Ensures embedding_dimension is NULL or between 1 and 2000

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

### nodes_tags

The nodes_tags join table implements the many-to-many relationship between nodes and tags.

**Purpose**: Links nodes to tags, allowing each node to have multiple tags and each tag to be applied to multiple nodes.

```sql
CREATE TABLE public.nodes_tags (
    id bigint NOT NULL,
    node_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE ONLY public.nodes_tags ALTER COLUMN id SET DEFAULT nextval('public.node_tags_id_seq'::regclass);
ALTER TABLE ONLY public.nodes_tags ADD CONSTRAINT node_tags_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.nodes_tags
    ADD CONSTRAINT fk_rails_b0b726ecf8 FOREIGN KEY (node_id) REFERENCES public.nodes(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.nodes_tags
    ADD CONSTRAINT fk_rails_eccc99cec5 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;
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

### Finding Tags for a Node

```sql
SELECT t.name
FROM tags t
JOIN nodes_tags nt ON t.id = nt.tag_id
WHERE nt.node_id = $1
ORDER BY t.name;
```

### Finding Nodes with a Specific Tag

```sql
SELECT n.*
FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name = 'database:postgresql'
ORDER BY n.created_at DESC;
```

### Finding Nodes with Hierarchical Tag Prefix

```sql
SELECT n.*
FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
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
JOIN nodes_tags nt1 ON t1.id = nt1.tag_id
JOIN nodes_tags nt2 ON nt1.node_id = nt2.node_id
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
JOIN nodes_tags nt ON n.id = nt.node_id
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
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id,
     to_tsquery('english', 'database & optimization') query
WHERE to_tsvector('english', n.content) @@ query
  AND t.name LIKE 'database:%'
ORDER BY rank DESC
LIMIT 20;
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
