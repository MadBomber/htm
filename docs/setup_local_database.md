# Setting Up Local PostgreSQL Database for HTM

This guide walks through setting up a local PostgreSQL database with all required extensions for HTM development.

## Prerequisites

- macOS with Homebrew installed
- PostgreSQL 14+ (PostgreSQL 17.6 recommended)
- Ollama running locally at `http://localhost:11434`

## Why Local Database?

HTM uses PostgreSQL database triggers (via pgai) to automatically generate embeddings when nodes are inserted. These triggers run **on the database server** and need to connect to Ollama.

**TimescaleDB Cloud cannot reach your localhost Ollama instance**, so you need a local database for development.

## Step 1: Install PostgreSQL

If you don't have PostgreSQL installed:

```bash
brew install postgresql@17
brew services start postgresql@17
```

Verify installation:

```bash
psql --version
# Should show: psql (PostgreSQL) 17.x (Homebrew)
```

## Step 2: Install Required Extensions

### 2.1 Install pgvector (Vector Similarity Search)

```bash
brew install pgvector
```

### 2.2 Install TimescaleDB (Time-Series Database)

```bash
# Add TimescaleDB tap
brew tap timescale/tap

# Install TimescaleDB
brew install timescaledb

# Configure PostgreSQL for TimescaleDB
# This updates your postgresql.conf with TimescaleDB settings
timescaledb-tune --quiet --yes

# Restart PostgreSQL to load TimescaleDB
brew services restart postgresql@17
```

### 2.3 Install pgai (AI/Embedding Generation)

pgai may not be available via Homebrew yet. You have two options:

#### Option A: Install from source (Recommended)

```bash
# Clone pgai repository
cd /tmp
git clone https://github.com/timescale/pgai.git
cd pgai

# Install pgai extension
make
make install

# Note: You may need to specify PG_CONFIG if you have multiple PostgreSQL versions
# make PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
# make install PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
```

#### Option B: Use TimescaleDB Cloud for production

For production use, consider using TimescaleDB Cloud with a publicly accessible Ollama endpoint, or use client-side embedding generation.

### 2.4 pg_trgm (Trigram Matching)

This extension is included with PostgreSQL, no installation needed.

## Step 3: Configure Environment

Update your `.envrc` file (already done):

```bash
# Database connection - Localhost PostgreSQL
export HTM_DBHOST=localhost
export HTM_DBPORT=5432
export HTM_DBNAME=htm_development
export HTM_DBUSER=${USER}
export HTM_DBPASS=
export HTM_DBURL="postgresql://${HTM_DBUSER}@${HTM_DBHOST}:${HTM_DBPORT}/${HTM_DBNAME}?sslmode=prefer"

# Embedding generation (via pgai)
export HTM_EMBEDDINGS_PROVIDER=ollama
export HTM_EMBEDDINGS_MODEL=embeddinggemma
export HTM_EMBEDDINGS_BASE_URL=http://localhost:11434
export HTM_EMBEDDINGS_DIMENSION=768

# Topic extraction (via pgai)
export HTM_TOPIC_PROVIDER=ollama
export HTM_TOPIC_MODEL=phi4
export HTM_TOPIC_BASE_URL=http://localhost:11434
```

Reload environment:

```bash
cd /path/to/htm
direnv allow
```

## Step 4: Create Database

```bash
createdb htm_development
```

## Step 5: Enable Extensions

```bash
# Enable pgvector
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Enable TimescaleDB
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

# Enable pg_trgm (trigram matching)
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Enable pgai (if installed)
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS ai CASCADE;"
```

## Step 6: Run HTM Database Setup

```bash
be rake htm:db:setup
```

This will:
1. Verify extensions are available
2. Create HTM schema (tables, indexes, triggers)
3. Set up TimescaleDB hypertables
4. Run any pending migrations

Expected output:

```
✓ TimescaleDB version: X.X.X
✓ pgvector version: X.X.X
✓ pg_trgm version: X.X.X
Creating HTM schema...
✓ Schema created
✓ Created hypertable for operations_log
✓ Created hypertable for nodes
✓ Enabled compression for nodes older than 30 days
✓ HTM database schema created successfully
```

## Step 7: Test with Sample Data

```bash
be rake htm:db:seed
```

This will:
1. Initialize HTM with real EmbeddingService
2. Create 3 sample nodes
3. Generate embeddings via pgai triggers calling your local Ollama

Expected output:

```
Seeding database with sample data...
Note: This requires Ollama to be accessible from your database server.
      For cloud databases, ensure Ollama endpoint is publicly reachable.

  Creating sample nodes...
✓ Database seeded with 3 sample nodes
```

## Available Rake Tasks

```bash
rake htm:db:setup      # Set up database schema and run migrations
rake htm:db:migrate    # Run pending migrations
rake htm:db:status     # Show migration status
rake htm:db:drop       # Drop all HTM tables (WARNING: destructive!)
rake htm:db:reset      # Drop and recreate database
rake htm:db:test       # Test database connection
rake htm:db:console    # Open PostgreSQL console
rake htm:db:seed       # Seed database with sample data
rake htm:db:info       # Show database info (size, tables, extensions)
```

## Troubleshooting

### Error: "type 'vector' does not exist"

**Problem:** pgvector extension not installed or not enabled.

**Solution:**
```bash
brew install pgvector
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Error: "TimescaleDB extension not found"

**Problem:** TimescaleDB not installed or not enabled.

**Solution:**
```bash
brew tap timescale/tap
brew install timescaledb
timescaledb-tune --quiet --yes
brew services restart postgresql@17
psql -d htm_development -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

### Error: "extension 'ai' is not available"

**Problem:** pgai not installed.

**Solution:** Install pgai from source (see Step 2.3 Option A) or modify the schema to skip pgai triggers.

### Error: "Connection refused" to Ollama

**Problem:** Ollama not running or not accessible.

**Solution:**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama if not running
ollama serve
```

### Error: "Database configuration not found"

**Problem:** Environment variables not loaded.

**Solution:**
```bash
direnv allow
echo $HTM_DBURL  # Verify it's set
```

## Switching Back to TimescaleDB Cloud

To switch back to TimescaleDB Cloud (production), edit `.envrc`:

```bash
# Comment out localhost config
# export HTM_DBHOST=localhost
# export HTM_DBPORT=5432
# export HTM_DBNAME=htm_development
# export HTM_DBUSER=${USER}
# export HTM_DBPASS=
# export HTM_DBURL="postgresql://${HTM_DBUSER}@${HTM_DBHOST}:${HTM_DBPORT}/${HTM_DBNAME}?sslmode=prefer"

# Uncomment TimescaleDB Cloud config
export HTM_SERVICE_NAME=$TIGER_SERVICE_NAME
export HTM_DBURL=$TIGER_DBURL
export HTM_DBNAME=$TIGER_DBNAME
export HTM_DBUSER=$TIGER_DBUSER
export HTM_DBPASS=$TIGER_DBPASS
export HTM_DBHOST=$TIGER_DBHOST
export HTM_DBPORT=$TIGER_DBPORT
```

Then reload:
```bash
direnv allow
```

## Verifying Setup

Check database info:

```bash
be rake htm:db:info
```

Should show:

```
HTM Database Information
================================================================================

Connection:
  Host: localhost
  Port: 5432
  Database: htm_development
  User: dewayne

PostgreSQL Version:
  PostgreSQL 17.6

Extensions:
  ai (X.X.X)
  pg_trgm (X.X.X)
  plpgsql (X.X.X)
  timescaledb (X.X.X)
  vector (X.X.X)

HTM Tables:
  nodes: X rows
  tags: X rows
  robots: X rows
  operations_log: X rows
  schema_migrations: X rows

Database Size: XX MB
================================================================================
```

## Next Steps

Once your local database is set up:

1. Run tests: `rake test`
2. Start using HTM in your application
3. All embeddings will be generated automatically via pgai triggers
4. Check operations_log table to see all HTM operations

## Architecture Notes

With this setup:

- **PostgreSQL** runs on your localhost
- **Ollama** runs on your localhost at port 11434
- **pgai triggers** in PostgreSQL can reach Ollama directly
- **Embeddings** are generated automatically on INSERT/UPDATE
- **No application-side embedding generation needed**

This is the ideal development environment for HTM.
