# HTM Memory Explorer

A full-stack Rails application demonstrating HTM integration with a compelling UI/UX for exploring and managing semantic memories.

## Features

- **Dashboard** - Overview of memory statistics, recent memories, top tags, and active robots
- **Memories Browser** - Full CRUD for memories with search, filtering, soft delete, and restore
- **Tag Visualization** - View tags as a list, text tree, or SVG hierarchy diagram
- **Robots Management** - Manage LLM agents in the hive mind architecture
- **Semantic Search** - Compare vector, full-text, and hybrid search strategies
- **File Loading** - Load markdown files with automatic chunking and re-sync

## Tech Stack

- Rails 7.1 with Hotwire (Turbo via CDN)
- Tailwind CSS via CDN (no build step required)
- PostgreSQL with pgvector
- HTM gem for semantic memory management
- Propshaft for asset pipeline

## Prerequisites

- PostgreSQL 17+ with pgvector and pg_trgm extensions
- Ollama running locally (for embeddings and tag extraction)
- direnv (for automatic environment setup)

## Setup

### Environment Variables (via direnv)

This project uses [direnv](https://direnv.net/) to automatically configure environment variables. When you `cd` into this directory, direnv loads settings from `examples/.envrc` (which inherits from the root `.envrc`).

**Key environment variables set automatically:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `HTM_ENV` | `examples` | HTM environment name |
| `HTM_DATABASE__URL` | `postgresql://...htm_examples` | HTM database connection |
| `HTM_EMBEDDING__PROVIDER` | `ollama` | Embedding provider |
| `HTM_EMBEDDING__MODEL` | `embeddinggemma` | Embedding model |
| `HTM_TAG__PROVIDER` | `ollama` | Tag extraction provider |
| `HTM_TAG__MODEL` | `phi4` | Tag extraction model |
| `HTM_EXTRACT_PROPOSITIONS` | `true` | Enable proposition extraction |

To verify your environment is configured:
```bash
# Should show HTM_ENV=examples and HTM_DATABASE__URL pointing to htm_examples
env | grep HTM
```

### Installation

```bash
# Allow direnv (if prompted)
direnv allow

# Install Ruby dependencies
bundle install

# Create the Rails app database (required for Rails to boot)
createdb htm_rails_example_dev

# Create and setup the HTM examples database
createdb htm_examples
psql htm_examples -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Initialize HTM schema
bundle exec rake htm:db:setup

# Ensure Ollama models are available
ollama pull embeddinggemma
ollama pull phi4
```

**Note:** This app uses two databases:
- `htm_rails_example_dev` - Rails application database (minimal, required for Rails)
- `htm_examples` - HTM memory database (configured via direnv)

## Running

```bash
# Start the Rails server
./bin/dev

# Or start manually
bundle exec rails server
```

## Screenshots

The app features a dark theme with:
- Clean dashboard with statistics cards
- Memory browser with tag filtering
- Interactive search playground comparing strategies
- Tag hierarchy visualization (text tree + SVG)
- Robot management for multi-agent scenarios

## How HTM Integration Works

1. The HTM gem includes a Rails Railtie (`lib/htm/railtie.rb`)
2. When Rails boots, the Railtie automatically:
   - Configures HTM to use `Rails.logger`
   - Sets job backend to `:active_job` (or `:inline` in test env)
   - Loads HTM rake tasks
   - Verifies database connection in development

3. The `ApplicationController` provides a `htm` helper method that creates an HTM instance scoped to the current robot (session-based)

4. All HTM features are exposed through the UI:
   - `htm.remember()` - Add memories (Memories > New)
   - `htm.recall()` - Search memories (Search page)
   - `htm.forget()` / `htm.restore()` - Soft delete/restore
   - `htm.load_file()` - Load markdown files (Files page)
   - Tag hierarchy visualization via `HTM::Models::Tag.tree_svg`

## Pages

| Route | Description |
|-------|-------------|
| `/` | Dashboard with stats and overview |
| `/memories` | Browse, search, and filter memories |
| `/memories/new` | Add a new memory |
| `/memories/deleted` | View and restore deleted memories |
| `/tags` | Browse tags (list, tree, or diagram view) |
| `/robots` | Manage robots and switch active robot |
| `/search` | Semantic search playground |
| `/files` | File loading and management |

## Development

The app uses:
- `propshaft` for asset pipeline (CSS/images only)
- Tailwind CSS via CDN (no build step)
- Hotwire (Turbo) via CDN (no build step)
- Manual offset/limit pagination (no Kaminari)

No JavaScript build step required. All frontend dependencies are loaded via CDN.

## Maintenance

**Uploaded Files:** Files uploaded via the web UI are stored in `tmp/uploads/`. These files are kept to support the "Sync" feature which re-reads files from disk. To clean up old uploads:

```bash
# Remove all uploaded files (will break sync for uploaded files)
rm -rf tmp/uploads/*
```
