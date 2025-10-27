# HTM Database Rake Tasks Reference

Complete reference for HTM database management tasks.

## Quick Start

```bash
# First time setup
cd /path/to/htm
direnv allow                  # Load environment variables from .envrc
rake htm:db:setup            # Create schema and run migrations
```

## Available Tasks

### Setup and Schema

#### `rake htm:db:setup`
Sets up the HTM database schema and runs all migrations.

**What it does:**
- Verifies required extensions (timescaledb, pgvector, pg_trgm)
- Creates all HTM tables (nodes, tags, robots, operations_log)
- Runs all pending migrations
- Sets up hypertables for time-series optimization

**When to use:** First-time setup or after dropping the database

```bash
$ rake htm:db:setup
✓ TimescaleDB version: 2.22.1
✓ pgvector version: 0.8.1
Creating HTM schema...
✓ Schema created
Running migration: 001_support_variable_dimensions
  ✓ Migration 001_support_variable_dimensions applied
Running migration: 002_ontology_topic_extraction
  ✓ Migration 002_ontology_topic_extraction applied
✓ Created hypertable for operations_log
✓ HTM database schema created successfully
```

---

### Migrations

#### `rake htm:db:migrate`
Runs pending database migrations only.

**What it does:**
- Checks which migrations have been applied
- Runs any new migrations in `sql/migrations/`
- Updates the `schema_migrations` table

**When to use:** After pulling new code with migrations

```bash
$ rake htm:db:migrate
Running migration: 002_ontology_topic_extraction
  ✓ Migration 002_ontology_topic_extraction applied
✓ Database migrations completed
```

#### `rake htm:db:status`
Shows which migrations have been applied and which are pending.

**Example output:**
```bash
$ rake htm:db:status

Migration Status
================================================================================
✓ 001_support_variable_dimensions (applied: 2025-10-26 04:27:15.428951+00)
✓ 002_ontology_topic_extraction (applied: 2025-10-27 03:44:15.012345+00)

Summary: 2 applied, 0 pending
================================================================================
```

---

### Information

#### `rake htm:db:info`
Shows comprehensive database information.

**Example output:**
```bash
$ rake htm:db:info

HTM Database Information
================================================================================

Connection:
  Host: cw7rxj91bm.srbbwwxn56.tsdb.cloud.timescale.com
  Port: 37807
  Database: tsdb
  User: tsdbadmin

PostgreSQL Version:
  PostgreSQL 17.6 (Ubuntu 17.6-2.pgdg22.04+1) on aarch64-unknown-linux-gnu

Extensions:
  ai (0.11.2)
  pg_stat_statements (1.11)
  pg_trgm (1.6)
  plpgsql (1.0)
  timescaledb (2.22.1)
  timescaledb_toolkit (1.21.0)
  vector (0.8.1)
  vectorscale (0.8.0)

HTM Tables:
  nodes: 42 rows
  tags: 156 rows
  robots: 3 rows
  operations_log: 289 rows
  schema_migrations: 2 rows

Database Size: 14 MB
================================================================================
```

#### `rake htm:db:test`
Tests database connection by running `test_connection.rb`.

**Example output:**
```bash
$ rake htm:db:test
Connecting to TimescaleDB...
✓ Connected successfully!
✓ TimescaleDB Extension: Version 2.22.1
✓ pgvector Extension: Version 0.8.1
✓ pg_trgm Extension: Version 1.6
```

---

### Utilities

#### `rake htm:db:console`
Opens an interactive PostgreSQL console (psql).

**What it does:**
- Launches `psql` connected to your HTM database
- Uses connection parameters from `HTM_DBURL` or `.envrc`
- Allows you to run SQL queries directly

**Example:**
```bash
$ rake htm:db:console
psql (17.6)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

tsdb=> SELECT COUNT(*) FROM nodes;
 count
-------
    42
(1 row)

tsdb=> \d nodes
tsdb=> \q
```

#### `rake htm:db:seed`
Seeds the database with sample data.

**What it does:**
- Creates a sample robot
- Adds 3 sample nodes with different topics
- Useful for testing or demos

**Example:**
```bash
$ rake htm:db:seed
Seeding database with sample data...
  Creating sample nodes...
✓ Database seeded with 3 sample nodes
```

---

### Destructive Operations

⚠️ **WARNING**: These tasks delete data and cannot be undone!

#### `rake htm:db:drop`
Drops all HTM tables, functions, triggers, and views.

**What it does:**
- Drops tables: nodes, tags, robots, operations_log, schema_migrations
- Drops ontology functions and triggers
- Drops views: ontology_structure, topic_relationships

**Safety:** Prompts for confirmation ("yes" must be typed)

```bash
$ rake htm:db:drop
Are you sure you want to drop all tables? This cannot be undone! (yes/no): yes
Dropping HTM tables...
  ✓ Dropped nodes
  ✓ Dropped tags
  ✓ Dropped robots
  ✓ Dropped operations_log
  ✓ Dropped schema_migrations
  ✓ Dropped ontology functions and triggers
  ✓ Dropped ontology views
✓ All HTM tables dropped
```

#### `rake htm:db:reset`
Drops and recreates the entire database (equivalent to `drop` + `setup`).

**When to use:** Development only, to start fresh

```bash
$ rake htm:db:reset
# Runs drop (with confirmation) then setup
```

---

## Environment Variables

All tasks require database configuration via environment variables. Use one of these methods:

### Method 1: direnv (Recommended)
```bash
# One-time setup
cd /path/to/htm
direnv allow

# Variables are automatically loaded from .envrc
rake htm:db:info
```

### Method 2: Manual Export
```bash
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"
rake htm:db:info
```

### Method 3: Source Tiger Credentials
```bash
source ~/.bashrc__tiger    # If using TimescaleDB Cloud
rake htm:db:info
```

---

## Common Workflows

### Initial Project Setup
```bash
cd /path/to/htm
direnv allow
bundle install
rake htm:db:setup
rake htm:db:seed          # Optional: add sample data
rake htm:db:info          # Verify setup
```

### After Pulling New Code
```bash
git pull
rake htm:db:status        # Check for new migrations
rake htm:db:migrate       # Run pending migrations
```

### Development Reset
```bash
rake htm:db:reset         # Drop and recreate (type 'yes' to confirm)
rake htm:db:seed          # Re-add sample data
```

### Debugging
```bash
rake htm:db:info          # Check database state
rake htm:db:status        # Check migration status
rake htm:db:console       # Open psql for SQL queries
```

### Production Deployment
```bash
# NEVER use reset or drop in production!
rake htm:db:migrate       # Run new migrations only
```

---

## Troubleshooting

### "Database configuration not found"
- Run `direnv allow` in the project directory
- Or manually export `HTM_DBURL`
- Verify: `echo $HTM_DBURL`

### "Connection refused"
- Check database is running
- Verify host/port in `HTM_DBURL`
- Test: `rake htm:db:test`

### "Extension not found"
- Ensure TimescaleDB Cloud instance has required extensions
- Check with: `rake htm:db:info`
- Extensions needed: timescaledb, pgvector, pg_trgm

### Migrations not running
- Check migration files exist: `ls -la sql/migrations/`
- Verify migrations table: `rake htm:db:console` then `SELECT * FROM schema_migrations;`
- Force re-run: `rake htm:db:drop` then `rake htm:db:setup`

---

## Legacy Tasks (Deprecated)

These tasks still work but will be removed in a future version:

- `rake db_setup` → Use `rake htm:db:setup`
- `rake db_test` → Use `rake htm:db:test`

