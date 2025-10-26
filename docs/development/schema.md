# Database Schema Documentation

This document provides a comprehensive reference for HTM's PostgreSQL/TimescaleDB database schema, including all tables, indexes, views, functions, and optimization strategies.

## Schema Overview

HTM uses PostgreSQL 17 with TimescaleDB extensions to provide:

- **Time-series optimization** for memory operations
- **Vector similarity search** via pgvector
- **Full-text search** with PostgreSQL's built-in capabilities
- **Fuzzy matching** using pg_trgm
- **Automatic compression** for old data
- **Audit logging** for all operations

### Required Extensions

HTM requires these PostgreSQL extensions:

```sql
CREATE EXTENSION IF NOT EXISTS pgvector;      -- Vector similarity search
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- Trigram fuzzy matching
CREATE EXTENSION IF NOT EXISTS timescaledb;   -- Time-series optimization (implicit)
```

## Entity-Relationship Diagram

Here's the complete database structure:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800" style="background: transparent;">
  <defs>
    <style>
      .table-box { fill: #1e1e1e; stroke: #4a9eff; stroke-width: 2; }
      .table-header { fill: #2d5a8e; }
      .text-header { fill: #ffffff; font-family: monospace; font-size: 14px; font-weight: bold; }
      .text-field { fill: #d4d4d4; font-family: monospace; font-size: 11px; }
      .text-type { fill: #8cb4e8; font-family: monospace; font-size: 10px; }
      .relation-line { stroke: #4a9eff; stroke-width: 1.5; fill: none; }
      .arrow { fill: #4a9eff; }
    </style>
  </defs>

  <!-- Nodes Table -->
  <rect class="table-box" x="50" y="50" width="280" height="320" rx="5"/>
  <rect class="table-header" x="50" y="50" width="280" height="35" rx="5"/>
  <text class="text-header" x="190" y="73" text-anchor="middle">nodes</text>

  <text class="text-field" x="60" y="100">id</text>
  <text class="text-type" x="280" y="100" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="60" y="120">key</text>
  <text class="text-type" x="280" y="120" text-anchor="end">TEXT UNIQUE</text>

  <text class="text-field" x="60" y="140">value</text>
  <text class="text-type" x="280" y="140" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="160">type</text>
  <text class="text-type" x="280" y="160" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="180">category</text>
  <text class="text-type" x="280" y="180" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="200">importance</text>
  <text class="text-type" x="280" y="200" text-anchor="end">REAL</text>

  <text class="text-field" x="60" y="220">created_at</text>
  <text class="text-type" x="280" y="220" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="240">updated_at</text>
  <text class="text-type" x="280" y="240" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="260">last_accessed</text>
  <text class="text-type" x="280" y="260" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="280">token_count</text>
  <text class="text-type" x="280" y="280" text-anchor="end">INTEGER</text>

  <text class="text-field" x="60" y="300">in_working_memory</text>
  <text class="text-type" x="280" y="300" text-anchor="end">BOOLEAN</text>

  <text class="text-field" x="60" y="320">robot_id</text>
  <text class="text-type" x="280" y="320" text-anchor="end">TEXT FK</text>

  <text class="text-field" x="60" y="340">embedding</text>
  <text class="text-type" x="280" y="340" text-anchor="end">vector(1536)</text>

  <!-- Relationships Table -->
  <rect class="table-box" x="420" y="50" width="280" height="180" rx="5"/>
  <rect class="table-header" x="420" y="50" width="280" height="35" rx="5"/>
  <text class="text-header" x="560" y="73" text-anchor="middle">relationships</text>

  <text class="text-field" x="430" y="100">id</text>
  <text class="text-type" x="690" y="100" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="430" y="120">from_node_id</text>
  <text class="text-type" x="690" y="120" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="430" y="140">to_node_id</text>
  <text class="text-type" x="690" y="140" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="430" y="160">relationship_type</text>
  <text class="text-type" x="690" y="160" text-anchor="end">TEXT</text>

  <text class="text-field" x="430" y="180">strength</text>
  <text class="text-type" x="690" y="180" text-anchor="end">REAL</text>

  <text class="text-field" x="430" y="200">created_at</text>
  <text class="text-type" x="690" y="200" text-anchor="end">TIMESTAMPTZ</text>

  <!-- Tags Table -->
  <rect class="table-box" x="790" y="50" width="280" height="140" rx="5"/>
  <rect class="table-header" x="790" y="50" width="280" height="35" rx="5"/>
  <text class="text-header" x="930" y="73" text-anchor="middle">tags</text>

  <text class="text-field" x="800" y="100">id</text>
  <text class="text-type" x="1060" y="100" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="800" y="120">node_id</text>
  <text class="text-type" x="1060" y="120" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="800" y="140">tag</text>
  <text class="text-type" x="1060" y="140" text-anchor="end">TEXT</text>

  <text class="text-field" x="800" y="160">created_at</text>
  <text class="text-type" x="1060" y="160" text-anchor="end">TIMESTAMPTZ</text>

  <!-- Robots Table -->
  <rect class="table-box" x="50" y="430" width="280" height="160" rx="5"/>
  <rect class="table-header" x="50" y="430" width="280" height="35" rx="5"/>
  <text class="text-header" x="190" y="453" text-anchor="middle">robots</text>

  <text class="text-field" x="60" y="480">id</text>
  <text class="text-type" x="320" y="480" text-anchor="end">TEXT PK</text>

  <text class="text-field" x="60" y="500">name</text>
  <text class="text-type" x="320" y="500" text-anchor="end">TEXT</text>

  <text class="text-field" x="60" y="520">created_at</text>
  <text class="text-type" x="320" y="520" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="540">last_active</text>
  <text class="text-type" x="320" y="540" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="60" y="560">metadata</text>
  <text class="text-type" x="320" y="560" text-anchor="end">JSONB</text>

  <!-- Operations Log Table (Hypertable) -->
  <rect class="table-box" x="420" y="430" width="280" height="180" rx="5"/>
  <rect class="table-header" x="420" y="430" width="280" height="35" rx="5"/>
  <text class="text-header" x="560" y="453" text-anchor="middle">operations_log 🕐</text>

  <text class="text-field" x="430" y="480">id</text>
  <text class="text-type" x="690" y="480" text-anchor="end">BIGSERIAL PK</text>

  <text class="text-field" x="430" y="500">timestamp</text>
  <text class="text-type" x="690" y="500" text-anchor="end">TIMESTAMPTZ</text>

  <text class="text-field" x="430" y="520">operation</text>
  <text class="text-type" x="690" y="520" text-anchor="end">TEXT</text>

  <text class="text-field" x="430" y="540">node_id</text>
  <text class="text-type" x="690" y="540" text-anchor="end">BIGINT FK</text>

  <text class="text-field" x="430" y="560">robot_id</text>
  <text class="text-type" x="690" y="560" text-anchor="end">TEXT FK</text>

  <text class="text-field" x="430" y="580">details</text>
  <text class="text-type" x="690" y="580" text-anchor="end">JSONB</text>

  <!-- Relationships: nodes -> relationships -->
  <path class="relation-line" d="M 330 120 L 420 120"/>
  <polygon class="arrow" points="420,120 410,115 410,125"/>

  <path class="relation-line" d="M 330 140 L 380 140 L 380 140 L 420 140"/>
  <polygon class="arrow" points="420,140 410,135 410,145"/>

  <!-- Relationships: nodes -> tags -->
  <path class="relation-line" d="M 330 160 L 750 160 L 750 120 L 790 120"/>
  <polygon class="arrow" points="790,120 780,115 780,125"/>

  <!-- Relationships: robots -> nodes -->
  <path class="relation-line" d="M 190 430 L 190 370"/>
  <polygon class="arrow" points="190,370 185,380 195,380"/>

  <!-- Relationships: robots -> operations_log -->
  <path class="relation-line" d="M 330 520 L 420 520"/>
  <polygon class="arrow" points="420,520 410,515 410,525"/>

  <!-- Relationships: nodes -> operations_log -->
  <path class="relation-line" d="M 190 370 L 190 400 L 560 400 L 560 430"/>
  <polygon class="arrow" points="560,430 555,420 565,420"/>

  <!-- Legend -->
  <text class="text-field" x="50" y="720" font-weight="bold">Legend:</text>
  <text class="text-field" x="50" y="740">PK = Primary Key</text>
  <text class="text-field" x="200" y="740">FK = Foreign Key</text>
  <text class="text-field" x="350" y="740">🕐 = TimescaleDB Hypertable</text>
</svg>
```

## Table Definitions

### nodes

The core table storing all memory nodes with vector embeddings.

**Purpose**: Stores all memories (facts, decisions, code, etc.) with full-text and vector search capabilities.

```sql
CREATE TABLE IF NOT EXISTS nodes (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  type TEXT,
  category TEXT,
  importance REAL DEFAULT 1.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  token_count INTEGER,
  in_working_memory BOOLEAN DEFAULT FALSE,
  robot_id TEXT NOT NULL,
  embedding vector(1536)
);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | AUTO | Unique identifier (primary key) |
| `key` | TEXT | NO | - | Unique string key for retrieval |
| `value` | TEXT | NO | - | The actual memory content |
| `type` | TEXT | YES | NULL | Memory type: fact, context, code, preference, decision, question |
| `category` | TEXT | YES | NULL | Custom categorization |
| `importance` | REAL | YES | 1.0 | Importance score (0-10) |
| `created_at` | TIMESTAMPTZ | NO | NOW() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | Last update timestamp (auto-updated) |
| `last_accessed` | TIMESTAMPTZ | NO | NOW() | Last retrieval timestamp |
| `token_count` | INTEGER | YES | NULL | Number of tokens (for working memory) |
| `in_working_memory` | BOOLEAN | NO | FALSE | Currently in working memory? |
| `robot_id` | TEXT | NO | - | Robot that created this memory |
| `embedding` | vector(1536) | YES | NULL | Vector embedding for semantic search |

**Indexes**:

- `PRIMARY KEY` on `id`
- `UNIQUE` constraint on `key`
- B-tree indexes on: `created_at`, `updated_at`, `last_accessed`, `type`, `category`, `robot_id`, `in_working_memory`
- HNSW index on `embedding` for vector similarity search
- GIN indexes on `value` and `key` for full-text search
- GIN trigram index on `value` for fuzzy matching

**Triggers**:

- `update_nodes_updated_at`: Automatically updates `updated_at` on row modification

### relationships

Tracks relationships between memory nodes for knowledge graph functionality.

**Purpose**: Enables building a knowledge graph by connecting related memories.

```sql
CREATE TABLE IF NOT EXISTS relationships (
  id BIGSERIAL PRIMARY KEY,
  from_node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  to_node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  relationship_type TEXT,
  strength REAL DEFAULT 1.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(from_node_id, to_node_id, relationship_type)
);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | AUTO | Unique identifier |
| `from_node_id` | BIGINT | NO | - | Source node (foreign key to nodes.id) |
| `to_node_id` | BIGINT | NO | - | Target node (foreign key to nodes.id) |
| `relationship_type` | TEXT | YES | NULL | Type of relationship (e.g., "related_to", "depends_on") |
| `strength` | REAL | YES | 1.0 | Relationship strength (0-1) |
| `created_at` | TIMESTAMPTZ | NO | NOW() | When relationship was created |

**Indexes**:

- `PRIMARY KEY` on `id`
- `UNIQUE` constraint on `(from_node_id, to_node_id, relationship_type)`
- B-tree index on `from_node_id`
- B-tree index on `to_node_id`

**Foreign Keys**:

- `from_node_id` references `nodes(id)` with `ON DELETE CASCADE`
- `to_node_id` references `nodes(id)` with `ON DELETE CASCADE`

### tags

Flexible tagging system for categorizing memories.

**Purpose**: Allows multiple tags per memory for flexible categorization and filtering.

```sql
CREATE TABLE IF NOT EXISTS tags (
  id BIGSERIAL PRIMARY KEY,
  node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(node_id, tag)
);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | AUTO | Unique identifier |
| `node_id` | BIGINT | NO | - | Node being tagged (foreign key to nodes.id) |
| `tag` | TEXT | NO | - | Tag value (e.g., "architecture", "important") |
| `created_at` | TIMESTAMPTZ | NO | NOW() | When tag was added |

**Indexes**:

- `PRIMARY KEY` on `id`
- `UNIQUE` constraint on `(node_id, tag)`
- B-tree index on `node_id`
- B-tree index on `tag`

**Foreign Keys**:

- `node_id` references `nodes(id)` with `ON DELETE CASCADE`

### robots

Registry of all robots using the HTM system.

**Purpose**: Tracks robot metadata for the "hive mind" multi-robot functionality.

```sql
CREATE TABLE IF NOT EXISTS robots (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_active TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB
);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | TEXT | NO | - | Unique robot identifier (primary key) |
| `name` | TEXT | YES | NULL | Human-readable robot name |
| `created_at` | TIMESTAMPTZ | NO | NOW() | When robot was first registered |
| `last_active` | TIMESTAMPTZ | NO | NOW() | Last activity timestamp |
| `metadata` | JSONB | YES | NULL | Robot-specific configuration (JSON) |

**Indexes**:

- `PRIMARY KEY` on `id`

### operations_log (TimescaleDB Hypertable)

Audit log of all memory operations for debugging and replay.

**Purpose**: Provides complete audit trail and enables debugging and operation replay.

```sql
CREATE TABLE IF NOT EXISTS operations_log (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  operation TEXT NOT NULL,
  node_id BIGINT REFERENCES nodes(id) ON DELETE SET NULL,
  robot_id TEXT NOT NULL,
  details JSONB
);

-- Convert to hypertable (TimescaleDB)
SELECT create_hypertable('operations_log', 'timestamp', if_not_exists => TRUE);
```

**Columns**:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | AUTO | Unique identifier |
| `timestamp` | TIMESTAMPTZ | NO | NOW() | Operation timestamp (partitioning key) |
| `operation` | TEXT | NO | - | Operation type: add, retrieve, remove, evict, recall |
| `node_id` | BIGINT | YES | NULL | Related node (foreign key, nullable) |
| `robot_id` | TEXT | NO | - | Robot performing operation |
| `details` | JSONB | YES | NULL | Additional operation metadata |

**Indexes**:

- `PRIMARY KEY` on `id`
- B-tree index on `timestamp` (automatically created by TimescaleDB)
- B-tree index on `robot_id`
- B-tree index on `operation`

**Foreign Keys**:

- `node_id` references `nodes(id)` with `ON DELETE SET NULL`

**TimescaleDB Optimization**:

This table is converted to a hypertable, automatically partitioning data by time for efficient queries and compression.

## Indexes and Constraints

### Primary Keys

| Table | Column | Type |
|-------|--------|------|
| `nodes` | `id` | BIGSERIAL |
| `relationships` | `id` | BIGSERIAL |
| `tags` | `id` | BIGSERIAL |
| `robots` | `id` | TEXT |
| `operations_log` | `id` | BIGSERIAL |

### Unique Constraints

| Table | Columns | Purpose |
|-------|---------|---------|
| `nodes` | `key` | Ensure unique memory keys |
| `relationships` | `(from_node_id, to_node_id, relationship_type)` | Prevent duplicate relationships |
| `tags` | `(node_id, tag)` | Prevent duplicate tags per node |

### Foreign Keys

| Table | Column | References | On Delete |
|-------|--------|------------|-----------|
| `relationships` | `from_node_id` | `nodes(id)` | CASCADE |
| `relationships` | `to_node_id` | `nodes(id)` | CASCADE |
| `tags` | `node_id` | `nodes(id)` | CASCADE |
| `operations_log` | `node_id` | `nodes(id)` | SET NULL |

### Vector Similarity Index (HNSW)

High-performance vector similarity search:

```sql
CREATE INDEX IF NOT EXISTS idx_nodes_embedding ON nodes
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

**Parameters**:

- `m = 16`: Controls index size/quality tradeoff (higher = more accurate, larger index)
- `ef_construction = 64`: Build-time search depth (higher = better index quality, slower build)
- `vector_cosine_ops`: Use cosine similarity for comparisons

### Full-Text Search Indexes (GIN)

PostgreSQL full-text search:

```sql
CREATE INDEX IF NOT EXISTS idx_nodes_value_gin
  ON nodes USING gin(to_tsvector('english', value));

CREATE INDEX IF NOT EXISTS idx_nodes_key_gin
  ON nodes USING gin(to_tsvector('english', key));
```

These enable fast keyword searches on memory content.

### Trigram Fuzzy Search (GIN)

Fuzzy/similarity matching:

```sql
CREATE INDEX IF NOT EXISTS idx_nodes_value_trgm
  ON nodes USING gin(value gin_trgm_ops);
```

Enables queries like:

```sql
SELECT * FROM nodes WHERE value % 'search term';  -- Similarity search
SELECT * FROM nodes WHERE value ILIKE '%fuzzy%';  -- Fast ILIKE
```

## Views

### node_stats

Aggregated statistics by memory type.

```sql
CREATE OR REPLACE VIEW node_stats AS
SELECT
  type,
  COUNT(*) as count,
  AVG(importance) as avg_importance,
  SUM(token_count) as total_tokens,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM nodes
GROUP BY type;
```

**Usage**:

```sql
SELECT * FROM node_stats;
```

**Returns**:

| Column | Type | Description |
|--------|------|-------------|
| `type` | TEXT | Memory type |
| `count` | BIGINT | Number of memories of this type |
| `avg_importance` | REAL | Average importance score |
| `total_tokens` | BIGINT | Total tokens across all memories |
| `oldest` | TIMESTAMPTZ | Oldest memory creation time |
| `newest` | TIMESTAMPTZ | Newest memory creation time |

### robot_activity

Per-robot activity summary.

```sql
CREATE OR REPLACE VIEW robot_activity AS
SELECT
  r.id,
  r.name,
  COUNT(n.id) as total_nodes,
  MAX(n.created_at) as last_node_created
FROM robots r
LEFT JOIN nodes n ON n.robot_id = r.id
GROUP BY r.id, r.name;
```

**Usage**:

```sql
SELECT * FROM robot_activity ORDER BY total_nodes DESC;
```

**Returns**:

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Robot ID |
| `name` | TEXT | Robot name |
| `total_nodes` | BIGINT | Total memories created by robot |
| `last_node_created` | TIMESTAMPTZ | Most recent memory creation |

## Functions and Triggers

### update_updated_at_column()

Automatically updates the `updated_at` timestamp when a row is modified.

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';
```

**Trigger**:

```sql
DROP TRIGGER IF EXISTS update_nodes_updated_at ON nodes;
CREATE TRIGGER update_nodes_updated_at
  BEFORE UPDATE ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

This ensures `nodes.updated_at` is always current without application code.

## TimescaleDB Hypertables

### operations_log Hypertable

The `operations_log` table is converted to a TimescaleDB hypertable for time-series optimization.

**Creation**:

```sql
SELECT create_hypertable('operations_log', 'timestamp', if_not_exists => TRUE);
```

**Benefits**:

- Automatic time-based partitioning (chunks)
- Fast time-range queries
- Automatic compression for old data
- Efficient retention policies

**Chunk Size**: Default ~7 days per chunk (adjustable)

### Compression Policy (Future)

Compress old operation logs to save space:

```sql
-- Enable compression
ALTER TABLE operations_log SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'robot_id',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- Automatically compress chunks older than 30 days
SELECT add_compression_policy('operations_log', INTERVAL '30 days');
```

### Retention Policy (Future)

Automatically drop very old operation logs:

```sql
-- Drop chunks older than 1 year
SELECT add_retention_policy('operations_log', INTERVAL '1 year');
```

## Query Examples

### Vector Similarity Search

Find semantically similar memories:

```sql
SELECT
  key,
  value,
  importance,
  embedding <=> $1 AS distance
FROM nodes
WHERE embedding IS NOT NULL
ORDER BY embedding <=> $1
LIMIT 10;
```

**Note**: `$1` is the query embedding vector. `<=>` is cosine distance operator.

### Full-Text Search

Find memories matching keywords:

```sql
SELECT
  key,
  value,
  ts_rank(to_tsvector('english', value), query) AS rank
FROM nodes,
     to_tsquery('english', 'database & architecture') AS query
WHERE to_tsvector('english', value) @@ query
ORDER BY rank DESC
LIMIT 10;
```

### Hybrid Search

Combine vector and full-text search:

```sql
WITH vector_results AS (
  SELECT
    id,
    embedding <=> $1 AS vector_score
  FROM nodes
  WHERE embedding IS NOT NULL
  ORDER BY embedding <=> $1
  LIMIT 50
),
fulltext_results AS (
  SELECT
    id,
    ts_rank(to_tsvector('english', value), query) AS text_score
  FROM nodes,
       to_tsquery('english', $2) AS query
  WHERE to_tsvector('english', value) @@ query
  ORDER BY text_score DESC
  LIMIT 50
)
SELECT
  n.*,
  COALESCE(v.vector_score, 1.0) * 0.6 +
  COALESCE(f.text_score, 0.0) * 0.4 AS combined_score
FROM nodes n
LEFT JOIN vector_results v ON v.id = n.id
LEFT JOIN fulltext_results f ON f.id = n.id
WHERE v.id IS NOT NULL OR f.id IS NOT NULL
ORDER BY combined_score DESC
LIMIT 10;
```

### Time-Range Query

Find memories from specific time period:

```sql
SELECT *
FROM nodes
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND created_at <= NOW()
ORDER BY created_at DESC;
```

### Robot Activity

Which robot created the most memories?

```sql
SELECT
  robot_id,
  COUNT(*) as memory_count,
  AVG(importance) as avg_importance
FROM nodes
GROUP BY robot_id
ORDER BY memory_count DESC;
```

### Knowledge Graph Traversal

Find all nodes related to a specific node:

```sql
WITH RECURSIVE related AS (
  -- Start node
  SELECT id, key, value, 1 as depth
  FROM nodes
  WHERE key = 'decision_001'

  UNION

  -- Traverse relationships
  SELECT n.id, n.key, n.value, r.depth + 1
  FROM nodes n
  JOIN relationships rel ON (rel.to_node_id = n.id)
  JOIN related r ON (rel.from_node_id = r.id)
  WHERE r.depth < 3  -- Max depth
)
SELECT * FROM related;
```

## Schema Migration Strategy

### Initial Setup

Run the complete schema once:

```sql
-- Load from file
psql $HTM_DBURL -f sql/schema.sql

-- Or via Ruby
ruby -r ./lib/htm -e "HTM::Database.setup"
```

### Adding Columns

When adding new columns, use `ALTER TABLE`:

```sql
-- Add new column with default
ALTER TABLE nodes
  ADD COLUMN access_count INTEGER DEFAULT 0;

-- Add index if needed
CREATE INDEX idx_nodes_access_count ON nodes(access_count);
```

### Changing Columns

Be careful with type changes on large tables:

```sql
-- Safe: Add new column, migrate data, drop old
ALTER TABLE nodes ADD COLUMN new_importance NUMERIC(5,2);
UPDATE nodes SET new_importance = importance::NUMERIC(5,2);
ALTER TABLE nodes DROP COLUMN importance;
ALTER TABLE nodes RENAME COLUMN new_importance TO importance;
```

### Dropping Columns

```sql
-- Drop column (cascades to dependencies)
ALTER TABLE nodes DROP COLUMN old_column CASCADE;
```

### Version Control

Track schema changes in `sql/migrations/`:

```
sql/
├── schema.sql              # Current complete schema
└── migrations/
    ├── 001_initial.sql
    ├── 002_add_access_count.sql
    └── 003_add_compression.sql
```

Each migration file should be idempotent and include:

```sql
-- Migration: Add access_count column
-- Date: 2024-10-25
-- Description: Track how many times each node is accessed

-- Check if column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='nodes' AND column_name='access_count'
  ) THEN
    ALTER TABLE nodes ADD COLUMN access_count INTEGER DEFAULT 0;
    CREATE INDEX idx_nodes_access_count ON nodes(access_count);
  END IF;
END $$;
```

## Performance Optimization

### Analyze and Vacuum

Keep statistics up-to-date:

```sql
-- Update statistics for query planner
ANALYZE nodes;

-- Reclaim space and update statistics
VACUUM ANALYZE nodes;

-- Full vacuum (locks table)
VACUUM FULL nodes;
```

### Index Maintenance

Monitor index usage:

```sql
-- Check index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'nodes'
ORDER BY idx_scan DESC;
```

Drop unused indexes:

```sql
-- Indexes with zero scans are unused
DROP INDEX IF EXISTS unused_index_name;
```

### Query Performance

Use `EXPLAIN ANALYZE` to understand query performance:

```sql
EXPLAIN ANALYZE
SELECT * FROM nodes
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY importance DESC
LIMIT 10;
```

### Connection Pooling

HTM uses `connection_pool` gem for efficient connection management:

```ruby
pool = ConnectionPool.new(size: 5, timeout: 5) do
  PG.connect(ENV['HTM_DBURL'])
end
```

## Security Considerations

### SQL Injection Prevention

Always use parameterized queries:

```ruby
# Good: Parameterized query
conn.exec_params(
  "SELECT * FROM nodes WHERE key = $1",
  [user_input]
)

# Bad: String interpolation
conn.exec("SELECT * FROM nodes WHERE key = '#{user_input}'")
```

### Access Control

Use PostgreSQL roles for access control:

```sql
-- Read-only role
CREATE ROLE htm_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO htm_readonly;

-- Application role
CREATE ROLE htm_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO htm_app;
```

### Encryption

- Use SSL/TLS for connections (`sslmode=require`)
- Consider column-level encryption for sensitive data
- TimescaleDB Cloud provides encryption at rest

## Monitoring and Maintenance

### Database Size

```sql
SELECT
  pg_size_pretty(pg_database_size(current_database())) AS db_size,
  pg_size_pretty(pg_total_relation_size('nodes')) AS nodes_size,
  pg_size_pretty(pg_total_relation_size('operations_log')) AS log_size;
```

### Table Statistics

```sql
SELECT
  schemaname,
  tablename,
  n_tup_ins AS inserts,
  n_tup_upd AS updates,
  n_tup_del AS deletes,
  n_live_tup AS live_rows,
  n_dead_tup AS dead_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

### Long-Running Queries

```sql
SELECT
  pid,
  now() - query_start AS duration,
  state,
  query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;
```

## Troubleshooting

### Slow Queries

1. Run `EXPLAIN ANALYZE` on the query
2. Check if indexes are being used
3. Update statistics with `ANALYZE`
4. Consider adding indexes
5. Check for bloat with `VACUUM`

### High Disk Usage

1. Check database size (query above)
2. Run `VACUUM FULL` to reclaim space
3. Enable compression for `operations_log`
4. Add retention policies for old data

### Connection Issues

1. Check connection pool size
2. Monitor active connections
3. Increase pool size if needed
4. Check for connection leaks

## Resources

### PostgreSQL Documentation

- **PostgreSQL 17 Docs**: [https://www.postgresql.org/docs/17/](https://www.postgresql.org/docs/17/)
- **pgvector**: [https://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)
- **pg_trgm**: [https://www.postgresql.org/docs/17/pgtrgm.html](https://www.postgresql.org/docs/17/pgtrgm.html)

### TimescaleDB Documentation

- **TimescaleDB Docs**: [https://docs.timescale.com/](https://docs.timescale.com/)
- **Hypertables**: [https://docs.timescale.com/use-timescale/latest/hypertables/](https://docs.timescale.com/use-timescale/latest/hypertables/)
- **Compression**: [https://docs.timescale.com/use-timescale/latest/compression/](https://docs.timescale.com/use-timescale/latest/compression/)

### Vector Search

- **HNSW Algorithm**: [https://arxiv.org/abs/1603.09320](https://arxiv.org/abs/1603.09320)
- **pgvector Performance**: [https://github.com/pgvector/pgvector#performance](https://github.com/pgvector/pgvector#performance)

## Next Steps

- **[Setup Guide](setup.md)**: Initialize the database
- **[Testing Guide](testing.md)**: Write database tests
- **[Contributing Guide](contributing.md)**: Submit schema improvements
- **[Architecture Overview](../architecture/overview.md)**: Understand the system design

---

**Schema Version**: 1.0.0 (Initial Release)

**Last Updated**: 2024-10-25
