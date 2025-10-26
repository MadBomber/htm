# Database Class

Database schema setup and configuration utilities for HTM.

## Overview

`HTM::Database` provides class methods for setting up the HTM database schema, managing PostgreSQL connections, and configuring TimescaleDB hypertables.

**Key Features:**

- Schema creation and migration
- TimescaleDB hypertable setup
- Extension verification (TimescaleDB, pgvector, pg_trgm)
- Connection configuration parsing
- Automatic compression policies

## Class Definition

```ruby
class HTM::Database
  # All methods are class methods
end
```

---

## Class Methods

### `setup(db_url = nil)` {: #setup }

Set up the HTM database schema and TimescaleDB hypertables.

```ruby
HTM::Database.setup(db_url = nil)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `db_url` | String, nil | `ENV['HTM_DBURL']` | Database connection URL |

#### Returns

- `void`

#### Raises

- `RuntimeError` - If database configuration not found
- `PG::Error` - If database connection or schema creation fails

#### Side Effects

- Connects to PostgreSQL database
- Verifies required extensions (TimescaleDB, pgvector, pg_trgm)
- Creates schema (tables, indexes, views)
- Converts tables to hypertables
- Sets up compression policies
- Prints status messages to stdout

#### Examples

```ruby
# Use default configuration from environment
HTM::Database.setup

# Use specific database URL
HTM::Database.setup('postgresql://user:pass@host:5432/dbname')

# Use TimescaleDB Cloud
url = 'postgresql://tsdbadmin:pass@xxx.tsdb.cloud.timescale.com:37807/tsdb?sslmode=require'
HTM::Database.setup(url)
```

#### Output

```
✓ TimescaleDB version: 2.13.0
✓ pgvector version: 0.5.1
✓ pg_trgm version: 1.6
Creating HTM schema...
✓ Schema created
✓ Created hypertable for operations_log
✓ Created hypertable for nodes
✓ Enabled compression for nodes older than 30 days
✓ HTM database schema created successfully
```

---

### `parse_connection_url(url)` {: #parse_connection_url }

Parse a PostgreSQL connection URL into a configuration hash.

```ruby
HTM::Database.parse_connection_url(url)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | String | PostgreSQL connection URL |

#### Returns

- `Hash` - Connection configuration
- `nil` - If url is nil

#### Hash Structure

```ruby
{
  host: "hostname",
  port: 5432,
  dbname: "database_name",
  user: "username",
  password: "password",
  sslmode: "require"  # or from URL params, default "prefer"
}
```

#### Examples

```ruby
# Standard PostgreSQL URL
url = 'postgresql://user:pass@localhost:5432/mydb'
config = HTM::Database.parse_connection_url(url)
# => {
#   host: "localhost",
#   port: 5432,
#   dbname: "mydb",
#   user: "user",
#   password: "pass",
#   sslmode: "prefer"
# }

# With SSL mode
url = 'postgresql://user:pass@host:5432/db?sslmode=require'
config = HTM::Database.parse_connection_url(url)
# => { ..., sslmode: "require" }

# TimescaleDB Cloud URL
url = 'postgresql://tsdbadmin:secret@xxx.tsdb.cloud.timescale.com:37807/tsdb?sslmode=require'
config = HTM::Database.parse_connection_url(url)
# => {
#   host: "xxx.tsdb.cloud.timescale.com",
#   port: 37807,
#   dbname: "tsdb",
#   user: "tsdbadmin",
#   password: "secret",
#   sslmode: "require"
# }

# Nil handling
config = HTM::Database.parse_connection_url(nil)
# => nil
```

---

### `parse_connection_params()` {: #parse_connection_params }

Build configuration from individual environment variables.

```ruby
HTM::Database.parse_connection_params()
```

#### Returns

- `Hash` - Connection configuration
- `nil` - If `ENV['HTM_DBNAME']` not set

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_DBHOST` | Database hostname | `'cw7rxj91bm.srbbwwxn56.tsdb.cloud.timescale.com'` |
| `HTM_DBPORT` | Database port | `37807` |
| `HTM_DBNAME` | Database name | *required* |
| `HTM_DBUSER` | Database user | *required* |
| `HTM_DBPASS` | Database password | *required* |

#### Examples

```ruby
# Set environment variables
ENV['HTM_DBNAME'] = 'tsdb'
ENV['HTM_DBUSER'] = 'tsdbadmin'
ENV['HTM_DBPASS'] = 'secret'

config = HTM::Database.parse_connection_params()
# => {
#   host: "cw7rxj91bm.srbbwwxn56.tsdb.cloud.timescale.com",
#   port: 37807,
#   dbname: "tsdb",
#   user: "tsdbadmin",
#   password: "secret",
#   sslmode: "require"
# }

# Custom host and port
ENV['HTM_DBHOST'] = 'localhost'
ENV['HTM_DBPORT'] = '5432'

config = HTM::Database.parse_connection_params()
# => { host: "localhost", port: 5432, ... }

# Without HTM_DBNAME
ENV.delete('HTM_DBNAME')
config = HTM::Database.parse_connection_params()
# => nil
```

---

### `default_config()` {: #default_config }

Get default database configuration from environment.

```ruby
HTM::Database.default_config()
```

#### Returns

- `Hash` - Connection configuration
- `nil` - If no configuration found

#### Priority Order

1. `ENV['HTM_DBURL']` - Parse connection URL
2. `ENV['HTM_DBNAME']` - Parse individual params
3. `nil` - No configuration available

#### Examples

```ruby
# Using HTM_DBURL
ENV['HTM_DBURL'] = 'postgresql://user:pass@host/db'
config = HTM::Database.default_config
# => Parsed from URL

# Using HTM_DBNAME
ENV.delete('HTM_DBURL')
ENV['HTM_DBNAME'] = 'mydb'
ENV['HTM_DBUSER'] = 'user'
ENV['HTM_DBPASS'] = 'pass'
config = HTM::Database.default_config
# => Parsed from params

# No configuration
ENV.delete('HTM_DBURL')
ENV.delete('HTM_DBNAME')
config = HTM::Database.default_config
# => nil

# Use in HTM initialization
htm = HTM.new(db_config: HTM::Database.default_config)
```

---

## Database Schema

### Tables

#### `nodes`

Primary memory storage table (hypertable partitioned by `created_at`).

```sql
CREATE TABLE nodes (
  id SERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  type TEXT,
  category TEXT,
  importance REAL DEFAULT 1.0,
  token_count INTEGER DEFAULT 0,
  robot_id TEXT NOT NULL REFERENCES robots(id),
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  in_working_memory BOOLEAN DEFAULT TRUE,
  evicted_at TIMESTAMPTZ
);

-- Indexes
CREATE UNIQUE INDEX idx_nodes_key ON nodes(key);
CREATE INDEX idx_nodes_created_at ON nodes(created_at DESC);
CREATE INDEX idx_nodes_robot_id ON nodes(robot_id);
CREATE INDEX idx_nodes_type ON nodes(type);
CREATE INDEX idx_nodes_embedding ON nodes USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_nodes_value_fts ON nodes USING GIN (to_tsvector('english', value));
```

#### `relationships`

Node relationship graph.

```sql
CREATE TABLE relationships (
  id SERIAL PRIMARY KEY,
  from_node_id INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  to_node_id INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  relationship_type TEXT,
  strength REAL DEFAULT 1.0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(from_node_id, to_node_id, relationship_type)
);

-- Indexes
CREATE INDEX idx_relationships_from ON relationships(from_node_id);
CREATE INDEX idx_relationships_to ON relationships(to_node_id);
```

#### `tags`

Flexible tagging system.

```sql
CREATE TABLE tags (
  id SERIAL PRIMARY KEY,
  node_id INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(node_id, tag)
);

-- Indexes
CREATE INDEX idx_tags_node_id ON tags(node_id);
CREATE INDEX idx_tags_tag ON tags(tag);
```

#### `robots`

Robot registry for multi-robot tracking.

```sql
CREATE TABLE robots (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  last_active TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

#### `operations_log`

Audit log for all operations (hypertable partitioned by `timestamp`).

```sql
CREATE TABLE operations_log (
  id SERIAL,
  operation TEXT NOT NULL,
  node_id INTEGER REFERENCES nodes(id) ON DELETE SET NULL,
  robot_id TEXT NOT NULL REFERENCES robots(id),
  timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  details JSONB
);

-- Indexes
CREATE INDEX idx_operations_log_timestamp ON operations_log(timestamp DESC);
CREATE INDEX idx_operations_log_robot_id ON operations_log(robot_id);
CREATE INDEX idx_operations_log_operation ON operations_log(operation);
```

### Views

#### `node_stats`

Aggregate statistics by node type.

```sql
CREATE VIEW node_stats AS
SELECT
  type,
  COUNT(*) as count,
  AVG(importance) as avg_importance,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM nodes
GROUP BY type;
```

#### `robot_activity`

Robot activity summary.

```sql
CREATE VIEW robot_activity AS
SELECT
  id,
  name,
  last_active,
  (SELECT COUNT(*) FROM nodes WHERE robot_id = robots.id) as node_count
FROM robots
ORDER BY last_active DESC;
```

---

## TimescaleDB Hypertables

### `nodes` Hypertable

```sql
SELECT create_hypertable('nodes', 'created_at',
  if_not_exists => TRUE,
  migrate_data => TRUE
);
```

**Partitioning**: By `created_at` timestamp

**Chunk Interval**: 7 days (default)

**Compression**:

```sql
ALTER TABLE nodes SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'robot_id,type'
);

SELECT add_compression_policy('nodes', INTERVAL '30 days',
  if_not_exists => TRUE
);
```

- Automatically compresses chunks older than 30 days
- Segments by `robot_id` and `type` for efficient queries
- Reduces storage by ~90% for old data

### `operations_log` Hypertable

```sql
SELECT create_hypertable('operations_log', 'timestamp',
  if_not_exists => TRUE,
  migrate_data => TRUE
);
```

**Partitioning**: By `timestamp`

**Chunk Interval**: 1 day (default)

**Benefits**:

- Fast time-range queries
- Automatic data retention policies (can be added)
- Optimized for append-only workload

---

## Required PostgreSQL Extensions

### TimescaleDB

Time-series database extension.

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

**Features Used**:

- Hypertables for time-series optimization
- Automatic chunking and partitioning
- Compression policies
- Continuous aggregates (planned)

### pgvector

Vector similarity search.

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

**Features Used**:

- `vector(1536)` data type for embeddings
- Cosine similarity operator `<=>`
- IVFFlat index for approximate nearest neighbor

### pg_trgm

Trigram-based text search.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

**Features Used**:

- Full-text search with fuzzy matching
- GIN indexes for fast text queries
- Similarity ranking

---

## Setup Process

### 1. Verify Extensions

```ruby
# Check TimescaleDB
timescale = conn.exec("SELECT extversion FROM pg_extension WHERE extname='timescaledb'").first
# => {"extversion"=>"2.13.0"}

# Check pgvector
pgvector = conn.exec("SELECT extversion FROM pg_extension WHERE extname='vector'").first
# => {"extversion"=>"0.5.1"}

# Check pg_trgm
pg_trgm = conn.exec("SELECT extversion FROM pg_extension WHERE extname='pg_trgm'").first
# => {"extversion"=>"1.6"}
```

### 2. Run Schema

Reads and executes `sql/schema.sql` from the repository:

- Creates tables
- Creates indexes
- Creates views
- Sets up constraints

Note: `CREATE EXTENSION` lines are filtered out (extensions must be pre-installed).

### 3. Setup Hypertables

Converts tables to hypertables:

```ruby
# operations_log
conn.exec("SELECT create_hypertable('operations_log', 'timestamp', if_not_exists => TRUE, migrate_data => TRUE)")

# nodes (with compression)
conn.exec("SELECT create_hypertable('nodes', 'created_at', if_not_exists => TRUE, migrate_data => TRUE)")
conn.exec("ALTER TABLE nodes SET (timescaledb.compress, timescaledb.compress_segmentby = 'robot_id,type')")
conn.exec("SELECT add_compression_policy('nodes', INTERVAL '30 days', if_not_exists => TRUE)")
```

---

## Environment Configuration

### TimescaleDB Cloud

Using URL (recommended):

```bash
# In ~/.bashrc__tiger
export HTM_DBURL='postgresql://tsdbadmin:PASSWORD@SERVICE.tsdb.cloud.timescale.com:37807/tsdb?sslmode=require'
```

Using individual variables:

```bash
# In ~/.bashrc__tiger
export HTM_DBHOST='xxx.tsdb.cloud.timescale.com'
export HTM_DBPORT=37807
export HTM_DBNAME='tsdb'
export HTM_DBUSER='tsdbadmin'
export HTM_DBPASS='your_password'
```

### Local PostgreSQL

```bash
export HTM_DBURL='postgresql://localhost/htm_dev'

# Or with auth
export HTM_DBURL='postgresql://user:pass@localhost:5432/htm_dev'
```

### Docker PostgreSQL

```bash
export HTM_DBURL='postgresql://postgres:postgres@localhost:5432/htm'
```

---

## Usage Examples

### Initial Setup

```ruby
# First time setup
require 'htm'

HTM::Database.setup
# Creates all tables, indexes, hypertables

# Verify
config = HTM::Database.default_config
conn = PG.connect(config)
result = conn.exec("SELECT COUNT(*) FROM nodes")
conn.close
```

### Configuration Management

```ruby
# Get current config
config = HTM::Database.default_config

if config
  puts "Database: #{config[:dbname]}"
  puts "Host: #{config[:host]}"
  puts "Port: #{config[:port]}"
else
  puts "No database configuration found"
  puts "Please set HTM_DBURL or HTM_DBNAME environment variables"
end

# Test connection
begin
  conn = PG.connect(config)
  version = conn.exec("SELECT version()").first['version']
  puts "Connected: #{version}"
  conn.close
rescue PG::Error => e
  puts "Connection failed: #{e.message}"
end
```

### Schema Migration

```ruby
# Check if schema exists
config = HTM::Database.default_config
conn = PG.connect(config)

tables = conn.exec(<<~SQL).to_a
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name IN ('nodes', 'robots', 'relationships', 'tags', 'operations_log')
SQL

if tables.empty?
  puts "Schema not found, running setup..."
  HTM::Database.setup
else
  puts "Schema already exists:"
  tables.each { |t| puts "  - #{t['table_name']}" }
end

conn.close
```

### Custom Database

```ruby
# Use non-standard database
custom_url = 'postgresql://app:secret@db.example.com:5432/production'

HTM::Database.setup(custom_url)

# Use with HTM
config = HTM::Database.parse_connection_url(custom_url)
htm = HTM.new(db_config: config)
```

---

## Troubleshooting

### Extensions Not Available

```
⚠ Warning: TimescaleDB extension not found
⚠ Warning: pgvector extension not found
```

**Solution**: Install required extensions:

```bash
# Ubuntu/Debian
sudo apt install postgresql-15-timescaledb postgresql-15-pgvector

# macOS with Homebrew
brew install timescaledb pgvector

# Or use TimescaleDB Cloud (extensions pre-installed)
```

### Connection Refused

```
PG::ConnectionBad: could not connect to server: Connection refused
```

**Solution**: Verify PostgreSQL is running and connection details:

```bash
# Check PostgreSQL status
pg_isready -h localhost -p 5432

# Test connection
psql -h localhost -U user -d dbname

# Verify environment
echo $HTM_DBURL
```

### Permission Denied

```
PG::InsufficientPrivilege: ERROR:  permission denied for schema public
```

**Solution**: Grant necessary permissions:

```sql
GRANT ALL ON SCHEMA public TO your_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO your_user;
```

### Hypertable Already Exists

```
Note: nodes hypertable: table "nodes" is already a hypertable
```

This is **not an error** - the schema setup is idempotent. Safe to ignore.

---

## Best Practices

### 1. Use Environment Variables

```ruby
# Good: Use environment variables
HTM::Database.setup

# Avoid: Hardcoded credentials
HTM::Database.setup('postgresql://user:password@host/db')
```

### 2. Verify Extensions First

```ruby
# Check extensions before setup
config = HTM::Database.default_config
conn = PG.connect(config)

required = ['timescaledb', 'vector', 'pg_trgm']
missing = required.reject do |ext|
  !conn.exec("SELECT 1 FROM pg_extension WHERE extname='#{ext}'").first
end

if missing.any?
  puts "Missing extensions: #{missing.join(', ')}"
  puts "Please install before running setup"
  exit 1
end

conn.close
HTM::Database.setup
```

### 3. Run Setup Once

```ruby
# Run setup in a migration or initial deployment
# Not on every application start

# Bad:
def initialize
  HTM::Database.setup  # Don't do this
  @htm = HTM.new
end

# Good:
# Run once during deployment:
# rake db:setup -> HTM::Database.setup
```

### 4. Handle Missing Configuration

```ruby
config = HTM::Database.default_config

unless config
  raise "Database not configured. Please set HTM_DBURL environment variable. " \
        "See README.md for configuration instructions."
end
```

---

## See Also

- [HTM API](htm.md) - Main class that uses Database config
- [LongTermMemory API](long-term-memory.md) - Uses database for storage
- [Database Schema](../development/schema.md) - Complete schema documentation
- [TimescaleDB Documentation](https://docs.timescale.com/) - Hypertable features
- [pgvector Documentation](https://github.com/pgvector/pgvector) - Vector search
