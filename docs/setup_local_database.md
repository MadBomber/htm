# Setting Up Local PostgreSQL Database for HTM

This guide walks through setting up a local PostgreSQL database with all required extensions for HTM development.

## Prerequisites

- macOS with Homebrew installed
- PostgreSQL 14+ (PostgreSQL 17.6 recommended)
- Ollama running locally at `http://localhost:11434`

## Why Local Database?

For local development, you'll want a PostgreSQL database on your machine for faster development and testing. HTM generates embeddings client-side using Ollama before inserting into the database.

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

### 2.3 pg_trgm (Trigram Matching)

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

# Client-side embedding generation
export HTM_EMBEDDINGS_PROVIDER=ollama
export HTM_EMBEDDINGS_MODEL=embeddinggemma
export HTM_EMBEDDINGS_BASE_URL=http://localhost:11434
export HTM_EMBEDDINGS_DIMENSION=768
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
2. Create 6 sample conversation messages
3. Generate embeddings client-side using your local Ollama

Expected output:

```
Seeding database with sample data...
Note: This requires Ollama to be running locally for embedding generation.

  Creating sample conversation...
✓ Database seeded with 6 conversation messages (3 exchanges)
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
3. Embeddings will be generated client-side using Ollama
4. Check operations_log table to see all HTM operations

## Architecture Notes

With this setup:

- **PostgreSQL** runs on your localhost
- **Ollama** runs on your localhost at port 11434
- **HTM Ruby client** connects to both PostgreSQL and Ollama
- **Embeddings** are generated client-side before database insertion
- **Simple, reliable architecture** that works on all platforms

This is the ideal development environment for HTM.
