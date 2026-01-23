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

- Rails 7.1 with Hotwire (Turbo + Stimulus)
- Tailwind CSS for dark-themed UI
- PostgreSQL with pgvector
- HTM gem for semantic memory management

## Setup

```bash
# From this directory
bundle install

# Ensure HTM database is set up
export HTM_DATABASE__URL="postgresql://localhost/htm_development"

# Install Tailwind CSS
rails tailwindcss:install

# Set up importmap
rails importmap:install
rails turbo:install
rails stimulus:install
```

## Running

```bash
# Start the Rails server with Tailwind CSS watching
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
   - Tag hierarchy visualization via `HTM::Models::Tag.all.tree_svg`

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
- `propshaft` for asset pipeline
- `importmap-rails` for JavaScript
- `tailwindcss-rails` for styling
- `kaminari` for pagination
- `turbo-rails` for SPA-like navigation

No JavaScript build step required.
