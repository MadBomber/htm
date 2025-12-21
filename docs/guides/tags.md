# Hierarchical Tags

HTM uses a hierarchical tagging system to organize memories semantically. Tags use colon-separated namespaces (like `database:postgresql:extensions`) enabling both specific and broad queries.

## Overview

The tagging system provides:

- **Hierarchical organization**: `category:subcategory:topic`
- **LLM-powered extraction**: Tags auto-generated from content
- **Ontology awareness**: New tags consider existing taxonomy
- **Prefix queries**: Find all `database:*` tags easily
- **Visualization**: Export as text tree, Mermaid, or SVG

## Quick Start

```ruby
htm = HTM.new(robot_name: "Tag Demo")

# Tags are auto-extracted from content
htm.remember("PostgreSQL supports JSON and vector search via pgvector.")
# Auto-tags: ["database:postgresql", "database:postgresql:json",
#             "database:postgresql:pgvector", "search:vector"]

# Or specify tags manually
htm.remember(
  "Redis is an in-memory data store.",
  tags: ["database:redis", "database:nosql", "caching"]
)

# Query by tag
results = htm.recall("database features", tags: ["database:postgresql"])
```

## Tag Format

### Hierarchical Structure

Tags use colon (`:`) as the hierarchy separator:

```
category:subcategory:topic
    │         │        │
    └─────────┴────────┴── More specific →
```

**Examples:**
- `database:postgresql`
- `database:postgresql:extensions`
- `database:postgresql:extensions:pgvector`
- `programming:ruby:gems`
- `api:rest:authentication`

### Naming Conventions

- **Lowercase**: Use lowercase for consistency
- **Singular nouns**: `database` not `databases`
- **Hierarchical**: Most general → most specific
- **Descriptive**: Clear, semantic meaning

## Automatic Tag Extraction

HTM uses LLM to automatically extract relevant tags from content:

```ruby
HTM.configure do |config|
  config.tag.provider = :ollama  # or :openai, :anthropic, etc.
  config.tag.model = 'gemma3:latest'
end

# Tags extracted automatically
htm.remember("Ruby on Rails uses ActiveRecord for database access.")
# Extracted: ["programming:ruby:rails", "database:orm:activerecord",
#             "web:framework:rails"]
```

### Ontology Awareness

The tag extractor receives existing tags to maintain consistency:

```ruby
# First memory creates initial tags
htm.remember("PostgreSQL is a relational database.")
# Tags: ["database:postgresql", "database:relational"]

# Later memories align with existing ontology
htm.remember("MySQL is also a relational database.")
# Tags: ["database:mysql", "database:relational"]  # Reuses existing structure
```

### Custom Tag Extractor

Provide your own tag extraction logic:

```ruby
HTM.configure do |config|
  config.tag_extractor = lambda do |text, existing_ontology|
    # Your custom logic here
    # Must return Array<String>
    ["custom:tag:one", "custom:tag:two"]
  end
end
```

## Manual Tag Operations

### Adding Tags

```ruby
# Via remember
htm.remember("Content here", tags: ["topic:subtopic"])

# Via long-term memory directly
htm.long_term_memory.add_tag(node_id: node.id, tag: "new:tag")
```

### Querying Tags

```ruby
# Get tags for a node
tags = htm.long_term_memory.node_topics(node.id)
# => ["database:postgresql", "search:vector"]

# Find nodes by tag
nodes = HTM::Models::Node.joins(:tags).where(tags: { name: "database:postgresql" })

# Find by tag prefix
nodes = HTM::Models::Node.joins(:tags).where("tags.name LIKE ?", "database:%")
```

### Tag Relationships

Find tags that co-occur frequently:

```ruby
relationships = htm.long_term_memory.topic_relationships(min_shared_nodes: 2)
# => [
#   { tag1: "database:postgresql", tag2: "search:vector", shared_count: 15 },
#   { tag1: "programming:ruby", tag2: "web:rails", shared_count: 12 }
# ]
```

## Tag Visualization

### Text Tree

```ruby
# All tags as directory-style tree
puts HTM::Models::Tag.all.tree_string
```

Output:
```
database
├── postgresql
│   ├── extensions
│   │   └── pgvector
│   └── json
├── mysql
└── redis
programming
├── ruby
│   ├── rails
│   └── gems
└── python
```

### Mermaid Flowchart

```ruby
# Generate Mermaid diagram
mermaid = HTM::Models::Tag.all.tree_mermaid
File.write("tags.md", "```mermaid\n#{mermaid}\n```")

# Left-to-right orientation
mermaid = HTM::Models::Tag.all.tree_mermaid(direction: 'LR')
```

### SVG Diagram

```ruby
# Generate SVG (dark theme, transparent background)
svg = HTM::Models::Tag.all.tree_svg
File.write("tags.svg", svg)

# With custom title
svg = HTM::Models::Tag.all.tree_svg(title: "Knowledge Taxonomy")
```

## Rake Tasks

```bash
# Display text tree (all tags)
rake htm:tags:tree

# Display tags with prefix
rake 'htm:tags:tree[database]'

# Export to Mermaid format
rake htm:tags:mermaid
rake 'htm:tags:mermaid[api]'

# Export to SVG
rake htm:tags:svg
rake 'htm:tags:svg[web]'

# Export all formats
rake htm:tags:export
rake 'htm:tags:export[database]'

# Rebuild all tags (regenerate via LLM)
rake htm:tags:rebuild
```

## Filtering by Tags

### In Recall

```ruby
# Filter by specific tag
results = htm.recall("query", tags: ["database:postgresql"])

# Filter by multiple tags (AND)
results = htm.recall("query", tags: ["database:postgresql", "search:vector"])

# Combine with other filters
results = htm.recall(
  "performance optimization",
  tags: ["database:postgresql"],
  timeframe: "last week",
  strategy: :hybrid,
  limit: 10
)
```

### Direct Queries

```ruby
# Find all nodes with a tag
HTM::Models::Node.with_tag("database:postgresql")

# Find nodes with any of several tags
HTM::Models::Node.with_any_tags(["database:postgresql", "database:mysql"])

# Find nodes with all specified tags
HTM::Models::Node.with_all_tags(["database:postgresql", "search:vector"])
```

## Database Schema

### Tags Table

```sql
CREATE TABLE tags (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tags_name ON tags(name);
CREATE INDEX idx_tags_name_prefix ON tags USING btree (name text_pattern_ops);
```

### Node-Tag Association

```sql
CREATE TABLE node_tags (
  node_id INTEGER REFERENCES nodes(id),
  tag_id INTEGER REFERENCES tags(id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (node_id, tag_id)
);
```

## Best Practices

### Design a Consistent Hierarchy

Plan your top-level categories:

```
database:      # Database-related
programming:   # Programming languages and frameworks
api:           # API design and integration
infrastructure: # DevOps, cloud, servers
concept:       # Abstract concepts and patterns
```

### Use Appropriate Depth

- **2-3 levels**: Typical for most use cases
- **4+ levels**: Only for highly specialized domains

```ruby
# Good
"database:postgresql:extensions"

# Too deep (usually)
"database:sql:relational:postgresql:extensions:pgvector:hnsw"
```

### Combine Auto and Manual Tags

```ruby
# Let LLM extract, but add specific tags you need
htm.remember(
  "PostgreSQL 16 introduces new parallel query features.",
  tags: ["version:postgresql:16", "release:2023"]  # Manual additions
)
# LLM will also add: ["database:postgresql", "performance:parallel"]
```

## Related Documentation

- [Adding Memories](adding-memories.md) - Core memory operations
- [Search Strategies](search-strategies.md) - Using tags in queries
- [Propositions](propositions.md) - Proposition nodes get tags too
- [API Reference: TagService](../api/yard/HTM/TagService.md)
