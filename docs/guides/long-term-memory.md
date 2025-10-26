# Long-term Memory

Long-term memory is HTM's durable PostgreSQL/TimescaleDB storage layer. This guide covers database operations, maintenance, performance optimization, and advanced queries.

## Architecture Overview

Long-term memory provides:

- **Permanent storage** for all memories
- **Vector embeddings** via pgvector
- **Full-text search** via PostgreSQL's ts_vector
- **Time-series optimization** via TimescaleDB hypertables
- **Relationship graphs** for knowledge connections
- **Audit logging** for all operations

```
┌─────────────────────────────────────────┐
│         Long-term Memory                │
├─────────────────────────────────────────┤
│  Tables:                                │
│  • nodes (memories + embeddings)        │
│  • relationships (knowledge graph)      │
│  • tags (categorization)                │
│  • operations_log (audit trail)         │
│  • robots (identity registry)           │
│                                         │
│  Indexes:                               │
│  • Vector similarity (HNSW)             │
│  • Full-text search (GIN)               │
│  • Time-range (hypertable chunks)       │
└─────────────────────────────────────────┘
```

## Database Schema

### Nodes Table

The primary storage for memories:

```sql
CREATE TABLE nodes (
  id BIGSERIAL PRIMARY KEY,
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  type TEXT,
  category TEXT,
  importance FLOAT DEFAULT 1.0,
  token_count INTEGER DEFAULT 0,
  robot_id TEXT NOT NULL,
  embedding vector(1536),  -- pgvector type
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  in_working_memory BOOLEAN DEFAULT TRUE
);

-- Indexes
CREATE INDEX idx_nodes_robot_id ON nodes(robot_id);
CREATE INDEX idx_nodes_type ON nodes(type);
CREATE INDEX idx_nodes_created_at ON nodes(created_at);
CREATE INDEX idx_nodes_embedding ON nodes USING hnsw(embedding vector_cosine_ops);
CREATE INDEX idx_nodes_fulltext ON nodes USING gin(to_tsvector('english', value));
```

### Relationships Table

Tracks connections between nodes:

```sql
CREATE TABLE relationships (
  id BIGSERIAL PRIMARY KEY,
  from_node_id BIGINT REFERENCES nodes(id) ON DELETE CASCADE,
  to_node_id BIGINT REFERENCES nodes(id) ON DELETE CASCADE,
  relationship_type TEXT,
  strength FLOAT DEFAULT 1.0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(from_node_id, to_node_id, relationship_type)
);
```

### Tags Table

Flexible categorization:

```sql
CREATE TABLE tags (
  id BIGSERIAL PRIMARY KEY,
  node_id BIGINT REFERENCES nodes(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(node_id, tag)
);

CREATE INDEX idx_tags_tag ON tags(tag);
```

### Operations Log Table (Hypertable)

Audit trail with time-series optimization:

```sql
CREATE TABLE operations_log (
  time TIMESTAMPTZ NOT NULL,
  operation TEXT NOT NULL,
  node_id BIGINT,
  robot_id TEXT NOT NULL,
  details JSONB,
  PRIMARY KEY (time, operation, robot_id)
);

-- Convert to hypertable
SELECT create_hypertable('operations_log', 'time');
```

### Robots Table

Robot registry:

```sql
CREATE TABLE robots (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  last_active TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

## Database Operations

### Direct Database Queries

While HTM provides a high-level API, you can query the database directly:

```ruby
require 'pg'

# Get connection config
config = HTM::Database.default_config

# Execute raw queries
conn = PG.connect(config)

# Query nodes
result = conn.exec("SELECT * FROM nodes WHERE type = 'decision' LIMIT 10")
result.each do |row|
  puts "#{row['key']}: #{row['value']}"
end

# Query with parameters
result = conn.exec_params(
  "SELECT * FROM nodes WHERE robot_id = $1 AND importance >= $2",
  ["your-robot-id", 8.0]
)

conn.close
```

### Using LongTermMemory Directly

Access the long-term memory layer:

```ruby
ltm = HTM::LongTermMemory.new(HTM::Database.default_config)

# Add a node
node_id = ltm.add(
  key: "test_001",
  value: "Test memory",
  type: :fact,
  importance: 7.0,
  token_count: 10,
  robot_id: "test-robot",
  embedding: Array.new(1536) { rand }
)

# Retrieve a node
node = ltm.retrieve("test_001")

# Update last accessed
ltm.update_last_accessed("test_001")

# Delete a node
ltm.delete("test_001")
```

## Memory Statistics

Get comprehensive statistics:

```ruby
stats = htm.memory_stats

# Total nodes
puts "Total nodes: #{stats[:total_nodes]}"

# Nodes by robot
stats[:nodes_by_robot].each do |robot_id, count|
  puts "#{robot_id}: #{count} nodes"
end

# Nodes by type
stats[:nodes_by_type].each do |row|
  puts "Type #{row['type']}: #{row['count']} nodes"
end

# Relationships
puts "Total relationships: #{stats[:total_relationships]}"

# Tags
puts "Total tags: #{stats[:total_tags]}"

# Time range
puts "Oldest memory: #{stats[:oldest_memory]}"
puts "Newest memory: #{stats[:newest_memory]}"

# Database size
size_mb = stats[:database_size] / (1024.0 * 1024.0)
puts "Database size: #{size_mb.round(2)} MB"

# Active robots
puts "Active robots: #{stats[:active_robots]}"
stats[:robot_activity].each do |robot|
  puts "  #{robot['name']}: last active #{robot['last_active']}"
end
```

## Advanced Queries

### Query by Date Range

```ruby
# Get all memories from a specific month
start_date = Time.new(2024, 1, 1)
end_date = Time.new(2024, 1, 31, 23, 59, 59)

config = HTM::Database.default_config
conn = PG.connect(config)

result = conn.exec_params(
  <<~SQL,
    SELECT key, value, type, importance, created_at
    FROM nodes
    WHERE created_at BETWEEN $1 AND $2
    ORDER BY created_at DESC
  SQL
  [start_date, end_date]
)

result.each do |row|
  puts "#{row['created_at']}: #{row['value'][0..50]}..."
end

conn.close
```

### Query by Type and Importance

```ruby
# Find critical decisions
conn = PG.connect(HTM::Database.default_config)

result = conn.exec_params(
  <<~SQL,
    SELECT key, value, importance, created_at
    FROM nodes
    WHERE type = $1 AND importance >= $2
    ORDER BY importance DESC, created_at DESC
  SQL
  ['decision', 8.0]
)

puts "Critical decisions:"
result.each do |row|
  puts "- [#{row['importance']}] #{row['value'][0..100]}..."
end

conn.close
```

### Query Relationships

```ruby
# Find all nodes related to a specific node
conn = PG.connect(HTM::Database.default_config)

result = conn.exec_params(
  <<~SQL,
    SELECT n.key, n.value, n.type, r.relationship_type
    FROM nodes n
    JOIN relationships r ON n.id = r.to_node_id
    JOIN nodes source ON r.from_node_id = source.id
    WHERE source.key = $1
  SQL
  ['decision_001']
)

puts "Related nodes:"
result.each do |row|
  puts "- [#{row['type']}] #{row['value'][0..50]}... (#{row['relationship_type']})"
end

conn.close
```

### Query by Tags

```ruby
# Find all nodes with specific tag
conn = PG.connect(HTM::Database.default_config)

result = conn.exec_params(
  <<~SQL,
    SELECT DISTINCT n.key, n.value, n.type, n.importance
    FROM nodes n
    JOIN tags t ON n.id = t.node_id
    WHERE t.tag = $1
    ORDER BY n.importance DESC
  SQL
  ['architecture']
)

puts "Architecture-related memories:"
result.each do |row|
  puts "- [#{row['importance']}] #{row['value'][0..80]}..."
end

conn.close
```

### Most Active Robots

```ruby
# Find robots with most contributions
conn = PG.connect(HTM::Database.default_config)

result = conn.exec(
  <<~SQL
    SELECT r.name, r.id, COUNT(n.id) as memory_count
    FROM robots r
    LEFT JOIN nodes n ON r.id = n.robot_id
    GROUP BY r.id, r.name
    ORDER BY memory_count DESC
  SQL
)

puts "Robot contributions:"
result.each do |row|
  puts "#{row['name']}: #{row['memory_count']} memories"
end

conn.close
```

### Time-Based Activity

```ruby
# Get activity by day
conn = PG.connect(HTM::Database.default_config)

result = conn.exec(
  <<~SQL
    SELECT DATE(created_at) as date, COUNT(*) as count
    FROM nodes
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(created_at)
    ORDER BY date DESC
  SQL
)

puts "Activity last 30 days:"
result.each do |row|
  puts "#{row['date']}: #{row['count']} memories"
end

conn.close
```

## Database Maintenance

### Vacuuming

PostgreSQL requires periodic vacuuming:

```ruby
# Manual vacuum
conn = PG.connect(HTM::Database.default_config)
conn.exec("VACUUM ANALYZE nodes")
conn.exec("VACUUM ANALYZE relationships")
conn.exec("VACUUM ANALYZE tags")
conn.close

puts "Vacuum completed"
```

### Reindexing

Rebuild indexes for optimal performance:

```ruby
conn = PG.connect(HTM::Database.default_config)

# Reindex vector index
conn.exec("REINDEX INDEX idx_nodes_embedding")

# Reindex full-text
conn.exec("REINDEX INDEX idx_nodes_fulltext")

conn.close

puts "Reindexing completed"
```

### Compression (TimescaleDB)

TimescaleDB can compress old data:

```ruby
# Enable compression on operations_log hypertable
conn = PG.connect(HTM::Database.default_config)

conn.exec(
  <<~SQL
    ALTER TABLE operations_log SET (
      timescaledb.compress,
      timescaledb.compress_segmentby = 'robot_id'
    )
  SQL
)

# Add compression policy (compress data older than 7 days)
conn.exec(
  <<~SQL
    SELECT add_compression_policy('operations_log', INTERVAL '7 days')
  SQL
)

conn.close

puts "Compression policy enabled"
```

### Cleanup Old Logs

```ruby
# Delete operations logs older than 90 days
conn = PG.connect(HTM::Database.default_config)

result = conn.exec_params(
  "DELETE FROM operations_log WHERE time < $1",
  [Time.now - (90 * 24 * 3600)]
)

puts "Deleted #{result.cmd_tuples} old log entries"
conn.close
```

## Performance Optimization

### Analyzing Query Performance

```ruby
# Explain query plan
conn = PG.connect(HTM::Database.default_config)

query = <<~SQL
  SELECT * FROM nodes
  WHERE type = 'decision'
  AND importance >= 8.0
  ORDER BY created_at DESC
  LIMIT 10
SQL

# Get query plan
result = conn.exec("EXPLAIN ANALYZE #{query}")
puts result.values.flatten
conn.close
```

### Index Usage Statistics

```ruby
# Check index usage
conn = PG.connect(HTM::Database.default_config)

result = conn.exec(
  <<~SQL
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_scan as scans,
      idx_tup_read as tuples_read,
      idx_tup_fetch as tuples_fetched
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan DESC
  SQL
)

puts "Index usage statistics:"
result.each do |row|
  puts "#{row['indexname']}: #{row['scans']} scans, #{row['tuples_read']} tuples"
end

conn.close
```

### Table Size Analysis

```ruby
# Check table sizes
conn = PG.connect(HTM::Database.default_config)

result = conn.exec(
  <<~SQL
    SELECT
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  SQL
)

puts "Table sizes:"
result.each do |row|
  puts "#{row['tablename']}: #{row['size']}"
end

conn.close
```

### Optimizing Vector Searches

```ruby
# HNSW index parameters can be tuned
# (This is done during index creation, shown for reference)

# m: max connections per layer (default: 16)
# ef_construction: construction time/accuracy tradeoff (default: 64)

# Example (run during schema setup):
# CREATE INDEX idx_nodes_embedding ON nodes
#   USING hnsw(embedding vector_cosine_ops)
#   WITH (m = 16, ef_construction = 64);

# For queries, you can adjust ef_search:
conn = PG.connect(HTM::Database.default_config)

# Higher ef_search = more accurate but slower
conn.exec("SET hnsw.ef_search = 100")

# Now run vector searches...

conn.close
```

## Backup and Restore

### Backup Database

```bash
# Full database backup
pg_dump -h localhost -U user -d database -F c -f htm_backup.dump

# Backup just the schema
pg_dump -h localhost -U user -d database -s -f htm_schema.sql

# Backup just the data
pg_dump -h localhost -U user -d database -a -f htm_data.sql
```

### Restore Database

```bash
# Restore from custom format
pg_restore -h localhost -U user -d database htm_backup.dump

# Restore from SQL format
psql -h localhost -U user -d database -f htm_schema.sql
psql -h localhost -U user -d database -f htm_data.sql
```

### Backup Ruby Script

```ruby
require 'open3'

def backup_database
  config = HTM::Database.default_config
  uri = URI.parse(config[:host])

  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  backup_file = "htm_backup_#{timestamp}.dump"

  cmd = [
    "pg_dump",
    "-h", uri.host,
    "-p", uri.port.to_s,
    "-U", config[:user],
    "-d", config[:dbname],
    "-F", "c",  # Custom format
    "-f", backup_file
  ].join(" ")

  # Set password via environment
  env = { "PGPASSWORD" => config[:password] }

  stdout, stderr, status = Open3.capture3(env, cmd)

  if status.success?
    puts "Backup created: #{backup_file}"
    backup_file
  else
    raise "Backup failed: #{stderr}"
  end
end

# Usage
backup_database
```

## Monitoring and Observability

### Connection Pooling

HTM uses connection pooling internally, but you can monitor it:

```ruby
# Check active connections
conn = PG.connect(HTM::Database.default_config)

result = conn.exec(
  <<~SQL
    SELECT
      count(*) as total,
      count(*) FILTER (WHERE state = 'active') as active,
      count(*) FILTER (WHERE state = 'idle') as idle
    FROM pg_stat_activity
    WHERE datname = current_database()
  SQL
)

puts "Connections: #{result.first['total']}"
puts "  Active: #{result.first['active']}"
puts "  Idle: #{result.first['idle']}"

conn.close
```

### Slow Query Log

Enable slow query logging in PostgreSQL:

```sql
-- In postgresql.conf or via SQL
ALTER DATABASE your_database SET log_min_duration_statement = 1000;  -- Log queries > 1s
```

### Custom Monitoring

```ruby
class DatabaseMonitor
  def initialize(htm)
    @htm = htm
    @config = HTM::Database.default_config
  end

  def health_check
    conn = PG.connect(@config)

    # Check connectivity
    result = conn.exec("SELECT 1")

    # Check table accessibility
    conn.exec("SELECT COUNT(*) FROM nodes")
    conn.exec("SELECT COUNT(*) FROM relationships")

    conn.close

    { status: :healthy, message: "All checks passed" }
  rescue => e
    { status: :error, message: e.message }
  end

  def performance_report
    conn = PG.connect(@config)

    report = {}

    # Query counts
    result = conn.exec("SELECT COUNT(*) FROM nodes")
    report[:total_nodes] = result.first['count'].to_i

    # Table sizes
    result = conn.exec(
      <<~SQL
        SELECT pg_size_pretty(pg_total_relation_size('nodes')) as size
      SQL
    )
    report[:nodes_size] = result.first['size']

    # Cache hit ratio
    result = conn.exec(
      <<~SQL
        SELECT
          sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
        FROM pg_statio_user_tables
        WHERE schemaname = 'public'
      SQL
    )
    report[:cache_hit_ratio] = result.first['ratio'].to_f

    conn.close
    report
  end

  def alert_if_unhealthy
    health = health_check

    if health[:status] != :healthy
      # Send alert (email, Slack, etc.)
      warn "Database unhealthy: #{health[:message]}"
    end
  end
end

monitor = DatabaseMonitor.new(htm)
puts monitor.health_check
puts monitor.performance_report
```

## Best Practices

### 1. Use Prepared Statements

```ruby
# Good: Use parameterized queries
conn.exec_params(
  "SELECT * FROM nodes WHERE robot_id = $1 AND type = $2",
  [robot_id, type]
)

# Avoid: String interpolation (SQL injection risk)
# conn.exec("SELECT * FROM nodes WHERE robot_id = '#{robot_id}'")
```

### 2. Connection Management

```ruby
# Good: Use HTM's internal connection handling
htm.add_node(...)  # Manages connections automatically

# Advanced: Manual connections, always close
conn = PG.connect(config)
begin
  # Do work
ensure
  conn.close
end
```

### 3. Batch Operations

```ruby
# Good: Use transactions for multiple operations
conn = PG.connect(config)
conn.transaction do |c|
  100.times do |i|
    c.exec_params("INSERT INTO nodes (...) VALUES ($1, $2)", [key, value])
  end
end
conn.close
```

### 4. Regular Maintenance

```ruby
# Schedule regular maintenance
require 'whenever'  # gem for cron jobs

# In schedule.rb
every 1.day, at: '2:00 am' do
  runner "HTM::Database.vacuum_analyze"
end

every 1.week, at: '3:00 am' do
  runner "HTM::Database.reindex"
end
```

### 5. Monitor Growth

```ruby
# Track database growth over time
class GrowthTracker
  def initialize
    @log_file = "database_growth.log"
  end

  def log_stats
    stats = htm.memory_stats

    entry = {
      timestamp: Time.now,
      total_nodes: stats[:total_nodes],
      database_size: stats[:database_size]
    }

    File.open(@log_file, 'a') do |f|
      f.puts entry.to_json
    end
  end
end

# Run daily
tracker = GrowthTracker.new
tracker.log_stats
```

## Troubleshooting

### Connection Issues

```ruby
# Test connection
begin
  conn = PG.connect(HTM::Database.default_config)
  puts "Connection successful"
  conn.close
rescue PG::Error => e
  puts "Connection failed: #{e.message}"
  puts "Check HTM_DBURL environment variable"
end
```

### Slow Queries

```ruby
# Enable query timing
conn = PG.connect(HTM::Database.default_config)

start = Time.now
result = conn.exec("SELECT * FROM nodes WHERE type = 'decision'")
elapsed = Time.now - start

puts "Query returned #{result.ntuples} rows in #{elapsed}s"

if elapsed > 1.0
  puts "Slow query detected! Consider:"
  puts "- Adding indexes"
  puts "- Using LIMIT"
  puts "- Narrowing date range"
end

conn.close
```

### Disk Space Issues

```ruby
# Check disk usage
conn = PG.connect(HTM::Database.default_config)

result = conn.exec("SELECT pg_database_size(current_database()) as size")
size_gb = result.first['size'].to_i / (1024.0 ** 3)

puts "Database size: #{size_gb.round(2)} GB"

if size_gb > 10
  puts "Large database. Consider:"
  puts "- Archiving old nodes"
  puts "- Enabling compression"
  puts "- Cleaning up operations_log"
end

conn.close
```

## Next Steps

- [**Working Memory**](working-memory.md) - Understand the memory tier above long-term
- [**Adding Memories**](adding-memories.md) - Learn how memories are stored
- [**Search Strategies**](search-strategies.md) - Optimize retrieval from long-term memory

## Complete Example

```ruby
require 'htm'
require 'pg'

# Initialize HTM
htm = HTM.new(robot_name: "Database Admin")

# Add some test data
puts "Adding test data..."
10.times do |i|
  htm.add_node(
    "test_#{i}",
    "Test memory number #{i}",
    type: :fact,
    importance: rand(1.0..10.0),
    tags: ["test", "batch_#{i / 5}"]
  )
end

# Get statistics
puts "\n=== Database Statistics ==="
stats = htm.memory_stats
puts "Total nodes: #{stats[:total_nodes]}"
puts "Database size: #{(stats[:database_size] / 1024.0 / 1024.0).round(2)} MB"
puts "Active robots: #{stats[:active_robots]}"

# Query by tag
puts "\n=== Query by Tag ==="
config = HTM::Database.default_config
conn = PG.connect(config)

result = conn.exec_params(
  <<~SQL,
    SELECT n.key, n.value
    FROM nodes n
    JOIN tags t ON n.id = t.node_id
    WHERE t.tag = $1
  SQL
  ['test']
)

puts "Found #{result.ntuples} nodes with tag 'test'"
result.each do |row|
  puts "- #{row['key']}: #{row['value']}"
end

# Performance check
puts "\n=== Performance Metrics ==="
result = conn.exec(
  <<~SQL
    SELECT
      pg_size_pretty(pg_total_relation_size('nodes')) as nodes_size,
      pg_size_pretty(pg_total_relation_size('relationships')) as rel_size,
      pg_size_pretty(pg_total_relation_size('tags')) as tags_size
  SQL
)

puts "Table sizes:"
puts "  nodes: #{result.first['nodes_size']}"
puts "  relationships: #{result.first['rel_size']}"
puts "  tags: #{result.first['tags_size']}"

conn.close

# Cleanup test data
puts "\n=== Cleanup ==="
10.times do |i|
  htm.forget("test_#{i}", confirm: :confirmed)
end
puts "Test data removed"
```
