# Rails Integration Example

A full-stack Rails application demonstrating HTM integration with a compelling UI/UX for exploring and managing semantic memories.

**Source:** [`examples/rails_app/`](https://github.com/madbomber/htm/tree/main/examples/rails_app)

## Overview

The HTM Memory Explorer is a Rails 7.1 application that demonstrates:

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
cd examples/rails_app

# Install dependencies
bundle install

# Ensure HTM database is set up
export HTM_DATABASE__URL="postgresql://localhost/htm_development"

# Install frontend dependencies
rails tailwindcss:install
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

Then open http://localhost:3000 in your browser.

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

## How HTM Integration Works

### Automatic Rails Integration

The HTM gem includes a Rails Railtie (`lib/htm/railtie.rb`) that automatically:

1. Configures HTM to use `Rails.logger`
2. Sets job backend to `:active_job` (or `:inline` in test env)
3. Loads HTM rake tasks
4. Verifies database connection in development

### Controller Helper

The `ApplicationController` provides a `htm` helper method:

```ruby
class ApplicationController < ActionController::Base
  private

  def htm
    @htm ||= HTM.new(
      robot_name: session[:robot_name] || "web_user_#{session.id}"
    )
  end
  helper_method :htm
end
```

### Using HTM in Controllers

```ruby
class MemoriesController < ApplicationController
  def create
    node_id = htm.remember(
      params[:content],
      tags: params[:tags]&.split(','),
      metadata: { category: params[:category] }
    )
    redirect_to memories_path, notice: "Memory created (ID: #{node_id})"
  end

  def index
    @memories = if params[:search].present?
      htm.recall(params[:search], strategy: :hybrid, limit: 50, raw: true)
    else
      HTM::Models::Node.order(created_at: :desc).limit(50)
    end
  end

  def destroy
    htm.forget(params[:id])  # Soft delete by default
    redirect_to memories_path, notice: "Memory deleted"
  end

  def restore
    htm.restore(params[:id])
    redirect_to memories_path, notice: "Memory restored"
  end
end
```

### Tag Visualization

```ruby
class TagsController < ApplicationController
  def index
    @tags = HTM::Models::Tag.all

    respond_to do |format|
      format.html
      format.text { render plain: @tags.tree_string }
      format.svg { render plain: @tags.tree_svg }
    end
  end
end
```

## Features Demonstrated

| HTM Feature | UI Component |
|-------------|--------------|
| `htm.remember()` | Memories > New form |
| `htm.recall()` | Search page with strategy selector |
| `htm.forget()` | Delete button (soft delete) |
| `htm.restore()` | Restore button in deleted view |
| `htm.load_file()` | Files page with file browser |
| Tag hierarchy | Tags page with tree/SVG views |
| Robot management | Robots page with activity stats |

## Development Notes

The app uses:

- `propshaft` for asset pipeline
- `importmap-rails` for JavaScript
- `tailwindcss-rails` for styling
- `kaminari` for pagination
- `turbo-rails` for SPA-like navigation

No JavaScript build step required.

## See Also

- [Getting Started Guide](../guides/getting-started.md)
- [Multi-Robot Systems](../guides/multi-robot.md)
- [Search Strategies](../guides/search-strategies.md)
