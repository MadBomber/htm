# File Loading Example

This example demonstrates loading markdown files into HTM's long-term memory with automatic chunking, YAML frontmatter extraction, and source tracking.

**Source:** [`examples/file_loader_usage.rb`](https://github.com/madbomber/htm/blob/main/examples/file_loader_usage.rb)

## Overview

The file loading example shows:

- Loading single markdown files
- Loading directories with glob patterns
- YAML frontmatter extraction
- Querying nodes from loaded files
- Re-sync behavior for changed files
- Unloading files from memory

## Running the Example

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
ruby examples/file_loader_usage.rb
```

## Code Walkthrough

### Loading a Single File

```ruby
htm = HTM.new(robot_name: "FileLoaderDemo")

# Load a markdown file
result = htm.load_file("docs/guide.md")
# => {
#   file_source_id: 1,
#   chunks_created: 5,
#   chunks_updated: 0,
#   skipped: false
# }
```

### YAML Frontmatter

Files with frontmatter have metadata extracted automatically:

```markdown
---
title: PostgreSQL Guide
author: HTM Team
tags:
  - database
  - postgresql
---

# PostgreSQL Guide

Content starts here...
```

Access frontmatter via FileSource:

```ruby
source = HTM::Models::FileSource.find(result[:file_source_id])
source.title            # => "PostgreSQL Guide"
source.author           # => "HTM Team"
source.frontmatter_tags # => ["database", "postgresql"]
source.frontmatter      # => { "title" => "...", ... }
```

### Loading a Directory

```ruby
# Load all markdown files
results = htm.load_directory("docs/", pattern: "**/*.md")
# => [
#   { file_path: "docs/guide.md", chunks_created: 3, ... },
#   { file_path: "docs/api.md", chunks_created: 5, ... }
# ]

# Load with specific pattern
results = htm.load_directory("docs/guides/", pattern: "*.md")
```

### Querying Loaded Files

```ruby
# Get all nodes from a specific file
nodes = htm.nodes_from_file("docs/guide.md")

nodes.each do |node|
  puts "#{node.id}: #{node.content[0..50]}..."
end
```

### Re-Sync Behavior

HTM tracks file modification times for efficient updates:

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
```

### Unloading Files

```ruby
# Soft delete all chunks from a file
count = htm.unload_file("docs/guide.md")
puts "Removed #{count} chunks"
```

## Chunking Configuration

```ruby
HTM.configure do |config|
  config.chunk_size = 1024    # Characters per chunk (default)
  config.chunk_overlap = 64   # Overlap between chunks (default)
end
```

Or via environment variables:

```bash
export HTM_CHUNK_SIZE=512
export HTM_CHUNK_OVERLAP=50
```

## Expected Output

```
HTM File Loader Example
============================================================

1. Configuring HTM with Ollama provider...
   Configured with Ollama provider

2. Initializing HTM...
   Robot: FileLoaderDemo (ID: 1)

3. Creating sample markdown files...
   Created: /tmp/htm_demo/postgresql_guide.md
   Created: /tmp/htm_demo/ruby_intro.md

4. Loading single file with frontmatter...
   File: postgresql_guide.md
   Source ID: 1
   Chunks created: 3
   Frontmatter title: PostgreSQL Guide
   Frontmatter author: HTM Team
   Frontmatter tags: database, postgresql

5. Loading directory...
   Files processed: 2
   - postgresql_guide.md: skipped
   - ruby_intro.md: 2 chunks

...

============================================================
Example completed successfully!
```

## Rake Tasks

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

# Sync all files
rake htm:files:sync

# Show statistics
rake htm:files:stats

# Force reload
FORCE=true rake 'htm:files:load[docs/guide.md]'
```

## See Also

- [File Loading Guide](../guides/file-loading.md)
- [Basic Usage Example](basic-usage.md)
- [Markdown Chunking](../guides/file-loading.md#chunking-strategy)
