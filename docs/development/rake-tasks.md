# HTM Rake Tasks Reference

Complete reference for all HTM rake tasks. HTM provides 46+ rake tasks organized into five namespaces for managing the database, documentation, file loading, background jobs, and tag management.

## Quick Reference

```bash
# List all HTM tasks
rake -T htm

# Most common tasks
rake htm:db:setup              # First-time database setup
rake htm:db:migrate            # Run pending migrations
rake test                      # Run all tests
rake htm:doc:all               # Generate all documentation
```

## Integrating Tasks into Your Application

Add HTM rake tasks to any Ruby application with a single line:

```ruby
# Your application's Rakefile
require 'htm/tasks'
```

All HTM tasks will now be available. See [Using Rake Tasks in Your Application](../using_rake_tasks_in_your_app.md) for complete integration examples.

---

## Database Tasks (`htm:db:*`)

Database management tasks for setup, migrations, maintenance, and inspection.

### Setup and Schema

#### `rake htm:db:setup`

Sets up the HTM database schema and runs all migrations. Use for first-time setup or after dropping the database.

```bash
$ rake htm:db:setup
Connecting to database...
  Host: localhost:5432
  Database: htm_development
Verifying extensions...
  ✓ pgvector 0.8.1
  ✓ pg_trgm 1.6
Running migrations...
  ✓ 00001_create_robots.rb
  ✓ 00002_create_file_sources.rb
  ✓ 00003_create_nodes.rb
  ...
✓ HTM database setup complete
```

**What it does:**

- Connects to PostgreSQL using `HTM_DATABASE__URL`
- Verifies required extensions (pgvector, pg_trgm)
- Creates all HTM tables (robots, nodes, tags, file_sources, etc.)
- Runs all pending ActiveRecord migrations
- Creates database views and indexes

---

#### `rake htm:db:create`

Creates the database if it doesn't exist. Useful for CI/CD pipelines where the database may not be pre-created.

```bash
$ rake htm:db:create
Creating database htm_development...
✓ Database created
```

---

#### `rake htm:db:migrate`

Runs pending database migrations only. Use after pulling new code with migrations.

```bash
$ rake htm:db:migrate
Running migrations...
  ✓ 00008_add_content_hash_index.rb
✓ 1 migration applied
```

---

#### `rake htm:db:schema:dump`

Exports the current database schema to `db/schema.sql`. Run after migrations to keep the schema file in sync.

```bash
$ rake htm:db:schema:dump
Dumping schema to db/schema.sql...
✓ Schema dumped successfully
```

---

### Status and Information

#### `rake htm:db:status`

Shows which migrations have been applied and which are pending.

```bash
$ rake htm:db:status

Migration Status
================================================================================
✓ 00001_create_robots.rb (applied: 2025-01-15 10:30:00)
✓ 00002_create_file_sources.rb (applied: 2025-01-15 10:30:01)
✓ 00003_create_nodes.rb (applied: 2025-01-15 10:30:02)
  00009_add_new_column.rb (pending)

Summary: 8 applied, 1 pending
================================================================================
```

---

#### `rake htm:db:info`

Shows comprehensive database information including connection details, extensions, table row counts, and database size.

```bash
$ rake htm:db:info

HTM Database Information
================================================================================

Connection:
  Host: localhost
  Port: 5432
  Database: htm_development
  User: dewayne

PostgreSQL Version:
  PostgreSQL 17.2 on darwin24.0.0

Extensions:
  pg_trgm (1.6)
  pgvector (0.8.1)
  plpgsql (1.0)

HTM Tables:
  robots: 3 rows
  nodes: 1,542 rows
  tags: 287 rows
  file_sources: 12 rows
  node_tags: 4,891 rows
  robot_nodes: 892 rows
  schema_migrations: 8 rows

Database Size: 48 MB
================================================================================
```

---

#### `rake htm:db:verify`

Verifies database connection and required extensions are installed.

```bash
$ rake htm:db:verify
Verifying HTM database...
  ✓ Connection successful
  ✓ pgvector extension installed (0.8.1)
  ✓ pg_trgm extension installed (1.6)
✓ Database verification complete
```

---

#### `rake htm:db:stats`

Shows detailed statistics about HTM data including node counts, tag usage, and embedding coverage.

```bash
$ rake htm:db:stats

HTM Database Statistics
================================================================================

Nodes:
  Total: 1,542
  With embeddings: 1,538 (99.7%)
  With tags: 1,421 (92.2%)
  Soft-deleted: 23

Tags:
  Total: 287
  Hierarchical depth: max 4 levels
  Most used: "database:postgresql" (127 nodes)

Robots:
  Total: 3
  Most active: "research-bot" (892 nodes)

File Sources:
  Total: 12
  Total chunks: 1,542
================================================================================
```

---

### Console and Testing

#### `rake htm:db:console`

Opens an interactive PostgreSQL console (psql) connected to your HTM database.

```bash
$ rake htm:db:console
psql (17.2)
Type "help" for help.

htm_development=> SELECT COUNT(*) FROM nodes;
 count
-------
  1542
(1 row)

htm_development=> \dt
              List of relations
 Schema |       Name        | Type  |  Owner
--------+-------------------+-------+---------
 public | nodes             | table | dewayne
 public | robots            | table | dewayne
 public | tags              | table | dewayne
 ...

htm_development=> \q
```

---

#### `rake htm:db:test`

Tests database connection by running `test_connection.rb`.

```bash
$ rake htm:db:test
Testing HTM database connection...
  ✓ Connected to PostgreSQL 17.2
  ✓ pgvector extension: 0.8.1
  ✓ pg_trgm extension: 1.6
✓ Connection test passed
```

---

#### `rake htm:db:seed`

Seeds the database with sample data for development and testing.

```bash
$ rake htm:db:seed
Seeding database...
  Creating sample robot...
  Creating sample nodes...
  Creating sample tags...
✓ Seeded 3 robots, 10 nodes, 15 tags
```

---

### Rebuild Tasks

#### `rake htm:db:rebuild:embeddings`

Clears and regenerates all vector embeddings via the configured LLM provider. Use when changing embedding models or dimensions.

!!! warning
    This task can take significant time for large databases and will make API calls to your embedding provider.

```bash
$ rake htm:db:rebuild:embeddings
Rebuilding embeddings for 1,542 nodes...
  Processing: 100% |████████████████████████████████| 1542/1542
✓ Rebuilt embeddings for 1,542 nodes
```

---

#### `rake htm:db:rebuild:propositions`

Extracts atomic propositions from all non-proposition nodes. Creates new proposition nodes with their own embeddings and tags.

```bash
$ rake htm:db:rebuild:propositions
Extracting propositions from 1,542 nodes...
  Processing node 1/1542...
  ...
✓ Created 4,892 proposition nodes
```

---

### Destructive Operations

!!! danger "Warning"
    These tasks delete data and cannot be undone! Use with extreme caution.

#### `rake htm:db:drop`

Drops all HTM tables, functions, triggers, and views. Requires confirmation.

```bash
$ rake htm:db:drop
Are you sure you want to drop all HTM tables? This cannot be undone!
Type 'yes' to confirm: yes
Dropping HTM tables...
  ✓ Dropped nodes
  ✓ Dropped tags
  ✓ Dropped robots
  ...
✓ All HTM tables dropped
```

---

#### `rake htm:db:reset`

Drops and recreates the entire database. Equivalent to `drop` + `setup`.

```bash
$ rake htm:db:reset
# Runs drop (with confirmation) then setup
```

---

#### `rake htm:db:purge_all`

Permanently removes all soft-deleted records from all tables, including orphaned join table entries, orphaned propositions, and orphaned robots.

!!! danger "Warning"
    This task permanently deletes data and cannot be undone!

```bash
$ rake htm:db:purge_all

HTM Purge All Soft-Deleted Records
============================================================

Records to permanently delete:
--------------------------------------------------------------
Soft-deleted nodes:              23
Soft-deleted node_tags:          45
Soft-deleted robot_nodes:        12
Orphaned node_tags:              3
Orphaned robot_nodes:            1
Orphaned propositions:           5
Orphaned robots (no nodes):      2
--------------------------------------------------------------
Total records to delete:         91

Proceed with permanent deletion? (yes/no): yes

Deleting records...
  Deleted 45 soft-deleted node_tags entries
  Deleted 3 orphaned node_tags entries
  Deleted 12 soft-deleted robot_nodes entries
  Deleted 1 orphaned robot_nodes entries
  Deleted 5 orphaned propositions
  Deleted 23 soft-deleted nodes
  Deleted 2 orphaned robots

✓ Purge complete!
```

**What it removes:**

- **Soft-deleted records**: Nodes, node_tags, and robot_nodes with `deleted_at` set
- **Orphaned join entries**: node_tags and robot_nodes pointing to non-existent nodes
- **Orphaned propositions**: Proposition nodes whose `source_node_id` no longer exists
- **Orphaned robots**: Robots with no associated memory nodes

**Deletion order** (for referential integrity):

1. Soft-deleted node_tags
2. Orphaned node_tags
3. Soft-deleted robot_nodes
4. Orphaned robot_nodes
5. Orphaned propositions
6. Soft-deleted nodes
7. Orphaned robots

---

## Documentation Tasks (`htm:doc:*`)

Tasks for generating API documentation, database diagrams, and building the documentation site.

### All-in-One

#### `rake htm:doc:all`

Generates all documentation (database docs, YARD API docs), builds the MkDocs site, and starts the local preview server.

```bash
$ rake htm:doc:all
Generating database documentation...
  ✓ Created docs/database/public.nodes.md
  ✓ Created docs/database/schema.svg
  ...
Generating YARD documentation...
  ✓ Created docs/api/yard/
Running mkdocs build...
  ✓ Site built in site/
Starting preview server at http://127.0.0.1:8000/
```

---

### Individual Documentation Tasks

#### `rake htm:doc:db`

Generates database documentation including table markdown files and ERD diagrams.

```bash
$ rake htm:doc:db
Generating database documentation...
  Connecting to htm_development...
  Generating table documentation...
    ✓ public.nodes.md
    ✓ public.robots.md
    ✓ public.tags.md
    ✓ public.file_sources.md
    ✓ public.node_tags.md
    ✓ public.robot_nodes.md
  Generating diagrams...
    ✓ schema.svg (full ERD)
    ✓ public.nodes.svg
    ✓ public.robots.svg
    ...
✓ Database documentation generated in docs/database/
```

---

#### `rake htm:doc:yard`

Generates YARD API documentation from Ruby source code.

```bash
$ rake htm:doc:yard
Generating YARD documentation...
  Parsing lib/**/*.rb...
  Generating HTML...
✓ YARD documentation generated in docs/api/yard/
```

---

#### `rake htm:doc:site`

Builds the MkDocs documentation site.

```bash
$ rake htm:doc:site
Running mkdocs build...
  INFO - Cleaning site directory
  INFO - Building documentation to directory: site
  INFO - Documentation built in 2.34 seconds
✓ Site built in site/
```

---

#### `rake htm:doc:serve`

Starts the MkDocs development server for live preview.

```bash
$ rake htm:doc:serve
Starting MkDocs server...
INFO - Building documentation...
INFO - Serving on http://127.0.0.1:8000/
# Press Ctrl+C to stop
```

---

#### `rake htm:doc:clean`

Removes generated documentation files.

```bash
$ rake htm:doc:clean
Cleaning generated documentation...
  ✓ Removed site/
  ✓ Removed docs/api/yard/
✓ Documentation cleaned
```

---

#### `rake htm:doc:deploy`

Deploys documentation to GitHub Pages.

```bash
$ rake htm:doc:deploy
Deploying to GitHub Pages...
  Building site...
  Pushing to gh-pages branch...
✓ Documentation deployed to https://madbomber.github.io/htm/
```

---

#### `rake htm:doc:validate`

Validates documentation for broken links and formatting issues.

```bash
$ rake htm:doc:validate
Validating documentation...
  Checking internal links...
  Checking code blocks...
  Checking images...
✓ All 127 pages validated
```

---

#### `rake htm:doc:changelog`

Generates changelog from git history.

```bash
$ rake htm:doc:changelog
Generating changelog...
  Analyzing commits since v0.5.0...
✓ CHANGELOG.md updated
```

---

## File Loading Tasks (`htm:files:*`)

Tasks for loading text files into HTM long-term memory with automatic chunking and source tracking.

### Loading Files

#### `rake htm:files:load[path]`

Loads a single file into HTM memory. Supports markdown files with YAML frontmatter.

```bash
$ rake 'htm:files:load[docs/guide.md]'
Loading docs/guide.md...
  Extracting frontmatter...
  Chunking content (1024 chars, 64 overlap)...
  Creating nodes...
✓ Created 5 chunks from docs/guide.md

# Force reload even if unchanged
$ FORCE=true rake 'htm:files:load[docs/guide.md]'
```

---

#### `rake htm:files:load_dir[path,pattern]`

Loads all matching files from a directory recursively.

```bash
$ rake 'htm:files:load_dir[docs/]'
Loading files from docs/...
  ✓ docs/guide.md (5 chunks)
  ✓ docs/api/reference.md (12 chunks)
  ✓ docs/examples/basic.md (3 chunks)
✓ Loaded 3 files, 20 total chunks

# Custom glob pattern
$ rake 'htm:files:load_dir[content/,**/*.txt]'
```

---

### File Management

#### `rake htm:files:list`

Lists all file sources loaded into HTM.

```bash
$ rake htm:files:list

Loaded File Sources
================================================================================
ID | Path                      | Chunks | Last Synced         | Needs Sync?
---|---------------------------|--------|---------------------|------------
1  | docs/guide.md             | 5      | 2025-01-15 10:30:00 | No
2  | docs/api/reference.md     | 12     | 2025-01-15 10:30:01 | No
3  | docs/examples/basic.md    | 3      | 2025-01-14 09:00:00 | Yes

Total: 3 files, 20 chunks
================================================================================
```

---

#### `rake htm:files:info[path]`

Shows detailed information about a loaded file.

```bash
$ rake 'htm:files:info[docs/guide.md]'

File Source: docs/guide.md
================================================================================
ID: 1
Path: docs/guide.md
Last Modified: 2025-01-15 10:29:45
Last Synced: 2025-01-15 10:30:00
Needs Sync: No

Frontmatter:
  title: Getting Started Guide
  author: Dewayne VanHoozer
  tags: [guide, tutorial]

Chunks: 5
  ID 101: "# Getting Started\n\nWelcome to HTM..." (1024 chars)
  ID 102: "## Installation\n\nAdd HTM to your..." (987 chars)
  ID 103: "## Basic Usage\n\nHere's how to..." (1024 chars)
  ID 104: "### Adding Memories\n\nUse the..." (856 chars)
  ID 105: "## Next Steps\n\nNow that you..." (432 chars)
================================================================================
```

---

#### `rake htm:files:unload[path]`

Removes a file from HTM memory (soft-deletes all chunks and removes file source).

```bash
$ rake 'htm:files:unload[docs/old-guide.md]'
Unloading docs/old-guide.md...
  Soft-deleting 5 chunks...
  Removing file source...
✓ File unloaded
```

---

#### `rake htm:files:sync`

Syncs all loaded files, reloading any that have changed on disk.

```bash
$ rake htm:files:sync
Syncing loaded files...
  docs/guide.md - unchanged
  docs/api/reference.md - unchanged
  docs/examples/basic.md - CHANGED, reloading...
    ✓ Reloaded (3 chunks updated)
✓ Sync complete: 1 file updated
```

---

#### `rake htm:files:stats`

Shows file loading statistics.

```bash
$ rake htm:files:stats

File Loading Statistics
================================================================================
Total Files: 12
Total Chunks: 1,542
Average Chunks per File: 128.5

Chunk Size Distribution:
  < 256 chars: 23 (1.5%)
  256-512 chars: 156 (10.1%)
  512-1024 chars: 1,363 (88.4%)

File Types:
  .md: 12 files (100%)

Sync Status:
  Up to date: 11 files
  Needs sync: 1 file
================================================================================
```

---

## Job Tasks (`htm:jobs:*`)

Tasks for managing HTM background jobs (embedding generation, tag extraction, proposition extraction). All processing tasks include progress bars with ETA display for visual feedback during long-running operations.

### Processing Jobs

#### `rake htm:jobs:process_all`

Processes all pending background jobs in sequence: embeddings, then tags, then propositions.

```bash
$ rake htm:jobs:process_all
# Runs process_embeddings, process_tags, process_propositions in sequence
```

---

#### `rake htm:jobs:process_embeddings`

Processes nodes without embeddings, generating vector embeddings via the configured LLM provider. Shows a progress bar with ETA for visual feedback.

```bash
$ rake htm:jobs:process_embeddings
Processing 50 nodes without embeddings...
Embeddings: |████████████████████████████████| 50/50 (100%) Time: 00:01:45
✓ Generated embeddings for 50 nodes
```

**Progress bar format:** `Title: |████████████| count/total (percent%) ETA: mm:ss`

---

#### `rake htm:jobs:process_tags`

Processes nodes without tags, extracting hierarchical tags via the configured LLM provider. Shows a progress bar with ETA for visual feedback.

```bash
$ rake htm:jobs:process_tags
Processing 50 nodes without tags...
Tags: |████████████████████████████████| 50/50 (100%) Time: 00:02:30
✓ Extracted tags for 50 nodes
```

---

#### `rake htm:jobs:process_propositions`

Extracts atomic propositions from nodes that haven't been processed yet. Tracks processed nodes via `source_node_id` metadata on proposition nodes. Shows a progress bar with ETA.

```bash
$ rake htm:jobs:process_propositions
Processing 25 nodes for proposition extraction...
Propositions: |████████████████████████████████| 25/25 (100%) Time: 00:03:15
✓ Extracted propositions from 25 nodes, created 89 proposition nodes
```

**Note:** Only nodes that don't already have propositions extracted will be processed. The task tracks this by checking for proposition nodes with matching `source_node_id` in metadata.

---

### Job Status

#### `rake htm:jobs:status`

Shows status of background job queues.

```bash
$ rake htm:jobs:status

HTM Job Queue Status
================================================================================
Queue           | Pending | Processing | Completed | Failed
----------------|---------|------------|-----------|-------
Embeddings      | 5       | 0          | 1,537     | 0
Tags            | 8       | 0          | 1,421     | 2
Propositions    | 0       | 0          | 4,892     | 0

Last processed: 2025-01-15 10:30:00
================================================================================
```

---

#### `rake htm:jobs:retry_failed`

Retries all failed jobs.

```bash
$ rake htm:jobs:retry_failed
Retrying failed jobs...
  2 failed jobs found
  Retrying...
    ✓ Tag job for node 892 - success
    ✓ Tag job for node 1023 - success
✓ Retried 2 jobs (2 successful)
```

---

#### `rake htm:jobs:clear`

Clears all pending jobs from queues. Requires confirmation.

```bash
$ rake htm:jobs:clear
Are you sure you want to clear all pending jobs? (yes/no): yes
Clearing job queues...
  ✓ Cleared 5 embedding jobs
  ✓ Cleared 8 tag jobs
  ✓ Cleared 0 proposition jobs
✓ All queues cleared
```

---

## Tag Tasks (`htm:tags:*`)

Tasks for managing and visualizing the hierarchical tag system.

### Visualization

#### `rake htm:tags:tree`

Displays the tag hierarchy as a text tree.

```bash
$ rake htm:tags:tree
Tag Hierarchy
================================================================================
database
├── postgresql
│   ├── extensions
│   │   ├── pgvector
│   │   └── pg_trgm
│   └── performance
└── redis
    └── caching
ai
├── embeddings
│   └── ollama
├── llm
│   ├── anthropic
│   └── openai
└── rag
================================================================================

# Filter by prefix
$ rake 'htm:tags:tree[database]'
database
├── postgresql
│   ├── extensions
│   │   ├── pgvector
│   │   └── pg_trgm
│   └── performance
└── redis
    └── caching
```

---

#### `rake htm:tags:mermaid`

Exports tag hierarchy to Mermaid flowchart format in `tags.md`.

```bash
$ rake htm:tags:mermaid
Exporting tag hierarchy to Mermaid format...
✓ Exported to tags.md

# Filter by prefix
$ rake 'htm:tags:mermaid[ai]'
```

**Output (`tags.md`):**
```markdown
```mermaid
graph TD
    database["database"]
    database_postgresql["postgresql"]
    database --> database_postgresql
    database_postgresql_extensions["extensions"]
    database_postgresql --> database_postgresql_extensions
    ...
```

---

#### `rake htm:tags:svg`

Exports tag hierarchy to SVG diagram in `tags.svg`.

```bash
$ rake htm:tags:svg
Exporting tag hierarchy to SVG...
✓ Exported to tags.svg

# Filter by prefix
$ rake 'htm:tags:svg[web]'
```

---

#### `rake htm:tags:export`

Exports tag hierarchy to all formats (text, Mermaid, SVG).

```bash
$ rake htm:tags:export
Exporting tag hierarchy...
  ✓ tags.txt (text tree)
  ✓ tags.md (Mermaid flowchart)
  ✓ tags.svg (SVG diagram)
✓ Exported to 3 formats

# Filter by prefix
$ rake 'htm:tags:export[database]'
```

---

### Tag Management

#### `rake htm:tags:rebuild`

Clears and regenerates all tags via LLM extraction.

!!! warning
    This task clears all existing tags and re-extracts them using your configured LLM provider. It can take significant time for large databases.

```bash
$ rake htm:tags:rebuild
Are you sure you want to rebuild all tags? This will clear existing tags. (yes/no): yes
Rebuilding tags for 1,542 nodes...
  Clearing existing tags...
  Extracting tags...
    Processing: 100% |████████████████████████████████| 1542/1542
✓ Rebuilt tags: 287 unique tags, 4,891 node-tag associations
```

---

## Common Workflows

### First-Time Setup

```bash
# Install dependencies
bundle install

# Set database URL
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"

# Create and setup database
rake htm:db:create
rake htm:db:setup

# Verify setup
rake htm:db:verify
rake htm:db:info

# Optional: seed with sample data
rake htm:db:seed
```

### Daily Development

```bash
# Check for pending migrations
rake htm:db:status

# Run migrations if needed
rake htm:db:migrate

# Run tests
rake test

# Process any pending background jobs
rake htm:jobs:process

# Open database console for debugging
rake htm:db:console
```

### Documentation Updates

```bash
# Generate all documentation
rake htm:doc:all

# Or individually:
rake htm:doc:db      # Database docs
rake htm:doc:yard    # API docs

# Preview documentation locally
rake htm:doc:serve

# Deploy to GitHub Pages
rake htm:doc:deploy
```

### Loading Content

```bash
# Load a single file
rake 'htm:files:load[docs/guide.md]'

# Load a directory
rake 'htm:files:load_dir[content/]'

# Check what's loaded
rake htm:files:list

# Sync changed files
rake htm:files:sync

# Process embeddings and tags
rake htm:jobs:process
```

### Tag Management

```bash
# View tag hierarchy
rake htm:tags:tree

# Export for documentation
rake htm:tags:export

# Rebuild all tags (after changing LLM)
rake htm:tags:rebuild
```

### Production Deployment

```bash
# NEVER use reset or drop in production!

# Run only migrations
rake htm:db:migrate

# Verify database state
rake htm:db:verify
rake htm:db:status

# Process any pending jobs
rake htm:jobs:process
```

---

## Environment Variables

All tasks require database configuration. Set one of these:

| Variable | Description |
|----------|-------------|
| `HTM_DATABASE__URL` | Full PostgreSQL connection URL (preferred) |
| `HTM_DATABASE__HOST` | Database host |
| `HTM_DATABASE__PORT` | Database port |
| `HTM_DATABASE__NAME` | Database name |
| `HTM_DATABASE__USER` | Database username |
| `HTM_DATABASE__PASSWORD` | Database password |

**Example:**

```bash
export HTM_DATABASE__URL="postgresql://user:password@localhost:5432/htm_development"
```

---

## Troubleshooting

### "Database configuration not found"

Set the `HTM_DATABASE__URL` environment variable:

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
```

### "Extension not found"

Install required PostgreSQL extensions:

```bash
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

### Tasks not running

1. Verify HTM gem is installed: `gem list htm`
2. Verify tasks are loaded: `rake -T htm`
3. Check for errors: `bundle exec rake htm:db:verify --trace`

### Slow job processing

- Check LLM provider status (Ollama, OpenAI, etc.)
- Increase batch size in configuration
- Run jobs in parallel: `rake htm:jobs:process WORKERS=4`

---

## See Also

- [Using Rake Tasks in Your Application](../using_rake_tasks_in_your_app.md) - Integration guide
- [Setup Guide](setup.md) - Initial development setup
- [Database Schema](schema.md) - Schema reference
- [Testing Guide](testing.md) - Running tests
