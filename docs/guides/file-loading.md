# File Loading

HTM can load text-based files (currently markdown) into long-term memory with automatic chunking, source tracking, and re-sync support. This is ideal for building knowledge bases from documentation, notes, or any text content.

## Overview

The file loading system provides:

- **Automatic chunking**: Large files are split into semantically-aware chunks
- **YAML frontmatter extraction**: Metadata from file headers is preserved
- **Source tracking**: Files are tracked for re-sync when content changes
- **Duplicate detection**: Content hashing prevents duplicate chunks
- **Soft delete**: Unloading files uses soft delete for recovery

## Quick Start

```ruby
require 'htm'

htm = HTM.new(robot_name: "Document Loader")

# Load a single markdown file
result = htm.load_file("docs/guide.md")
# => { file_source_id: 1, chunks_created: 5, chunks_updated: 0, skipped: false }

# Load all markdown files from a directory
results = htm.load_directory("docs/", pattern: "**/*.md")
# => [{ file_path: "docs/guide.md", ... }, { file_path: "docs/api.md", ... }]

# Query nodes from a specific file
nodes = htm.nodes_from_file("docs/guide.md")

# Unload a file (soft deletes chunks)
htm.unload_file("docs/guide.md")
```

## API Reference

### load_file(path, force: false)

Loads a single file into long-term memory.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | required | Path to the file |
| `force` | Boolean | `false` | Force reload even if file unchanged |

**Returns:** Hash with keys:
- `file_source_id`: ID of the FileSource record
- `chunks_created`: Number of new chunks created
- `chunks_updated`: Number of existing chunks updated
- `chunks_deleted`: Number of chunks removed
- `skipped`: Whether file was skipped (unchanged)

```ruby
# Normal load - skips unchanged files
result = htm.load_file("docs/guide.md")

# Force reload even if file hasn't changed
result = htm.load_file("docs/guide.md", force: true)
```

### load_directory(path, pattern: "**/*.md", force: false)

Loads all matching files from a directory.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | required | Directory path |
| `pattern` | String | `"**/*.md"` | Glob pattern for files |
| `force` | Boolean | `false` | Force reload all files |

**Returns:** Array of result hashes (one per file)

```ruby
# Load all markdown files
results = htm.load_directory("docs/")

# Load only top-level markdown files
results = htm.load_directory("docs/", pattern: "*.md")

# Load specific subdirectory
results = htm.load_directory("docs/guides/", pattern: "**/*.md")
```

### nodes_from_file(path)

Returns all nodes loaded from a specific file.

```ruby
nodes = htm.nodes_from_file("docs/guide.md")
nodes.each do |node|
  puts "#{node.id}: #{node.content[0..50]}..."
end
```

### unload_file(path)

Soft deletes all nodes from a file and removes the file source.

```ruby
count = htm.unload_file("docs/guide.md")
puts "Removed #{count} chunks"
```

## YAML Frontmatter

Files with YAML frontmatter have their metadata extracted and stored:

```markdown
---
title: PostgreSQL Guide
author: HTM Team
tags:
  - database
  - postgresql
version: 1.2
---

# PostgreSQL Guide

Content starts here...
```

Access frontmatter via the FileSource model:

```ruby
source = HTM::Models::FileSource.find_by(file_path: "docs/guide.md")
source.title            # => "PostgreSQL Guide"
source.author           # => "HTM Team"
source.frontmatter_tags # => ["database", "postgresql"]
source.frontmatter      # => { "title" => "...", "author" => "...", ... }
```

## Chunking Strategy

HTM uses the [Baran gem](https://github.com/baran) with `MarkdownSplitter` for intelligent chunking that respects markdown structure:

- **Headers**: Chunks break at header boundaries
- **Code blocks**: Code blocks are kept intact
- **Horizontal rules**: Natural section breaks
- **Configurable size**: Control chunk size and overlap

### Configuration

```ruby
# Global configuration
HTM.configure do |config|
  config.chunk_size = 1024    # Characters per chunk (default: 1024)
  config.chunk_overlap = 64   # Overlap between chunks (default: 64)
end

# Or via environment variables
# HTM_CHUNK_SIZE=512
# HTM_CHUNK_OVERLAP=50
```

### Per-Loader Configuration

```ruby
loader = HTM::Loaders::MarkdownLoader.new(
  htm,
  chunk_size: 512,
  chunk_overlap: 50
)
loader.load("docs/guide.md")
```

## Re-Sync Behavior

The file loading system tracks file modification times for efficient re-syncing:

1. **First load**: Creates FileSource record and chunks
2. **Subsequent loads**: Compares mtime, skips unchanged files
3. **Changed files**: Re-chunks and updates nodes
4. **Force reload**: Bypasses mtime check

```ruby
# First load - creates chunks
htm.load_file("docs/guide.md")
# => { skipped: false, chunks_created: 5 }

# Second load - skipped (unchanged)
htm.load_file("docs/guide.md")
# => { skipped: true }

# After editing file - re-syncs
htm.load_file("docs/guide.md")
# => { skipped: false, chunks_updated: 2, chunks_created: 1 }

# Force reload
htm.load_file("docs/guide.md", force: true)
# => { skipped: false, chunks_updated: 5 }
```

## FileSource Model

The `HTM::Models::FileSource` tracks loaded files:

```ruby
source = HTM::Models::FileSource.find_by(file_path: "docs/guide.md")

source.file_path       # Full path to file
source.mtime           # Last modification time
source.needs_sync?     # Check if file changed since load
source.chunks          # Associated nodes (ordered by position)
source.frontmatter     # Parsed YAML frontmatter
source.title           # Frontmatter title (convenience)
source.author          # Frontmatter author (convenience)
source.frontmatter_tags # Tags from frontmatter
```

## Rake Tasks

HTM provides rake tasks for file management:

```bash
# Load a single file
rake 'htm:files:load[docs/guide.md]'

# Load directory
rake 'htm:files:load_dir[docs/]'
rake 'htm:files:load_dir[docs/,**/*.md]'

# List loaded files
rake htm:files:list

# Show file details
rake 'htm:files:info[docs/guide.md]'

# Unload a file
rake 'htm:files:unload[docs/guide.md]'

# Sync all files (reload changed)
rake htm:files:sync

# Show statistics
rake htm:files:stats

# Force reload with FORCE=true
FORCE=true rake 'htm:files:load[docs/guide.md]'
```

## Best Practices

### Organize Files Logically

```ruby
# Load by category
htm.load_directory("docs/guides/", pattern: "**/*.md")
htm.load_directory("docs/api/", pattern: "**/*.md")
htm.load_directory("docs/tutorials/", pattern: "**/*.md")
```

### Use Frontmatter for Metadata

```markdown
---
title: API Authentication
category: api
tags:
  - security
  - authentication
priority: high
---
```

### Tune Chunk Size for Your Content

```ruby
# Smaller chunks for dense technical content
HTM.configure { |c| c.chunk_size = 512 }

# Larger chunks for narrative content
HTM.configure { |c| c.chunk_size = 2048 }
```

### Regular Sync for Updated Content

```ruby
# Sync all loaded files periodically
htm.sync_files  # Re-checks all FileSource records
```

## Example: Building a Knowledge Base

```ruby
require 'htm'

# Initialize
htm = HTM.new(robot_name: "Knowledge Base")

# Configure chunking for technical docs
HTM.configure do |config|
  config.chunk_size = 768
  config.chunk_overlap = 100
end

# Load documentation
htm.load_directory("docs/", pattern: "**/*.md")
htm.load_directory("README.md")
htm.load_directory("CHANGELOG.md")

# Query the knowledge base
results = htm.recall(
  "How do I configure authentication?",
  strategy: :hybrid,
  limit: 5
)

results.each do |result|
  puts result['content']
  puts "---"
end
```

## Related Documentation

- [Adding Memories](adding-memories.md) - Core memory operations
- [Search Strategies](search-strategies.md) - Querying loaded content
- [API Reference: HTM](../api/htm.md) - Complete API documentation
- [Example: File Loading](../examples/file-loading.md) - Working example
