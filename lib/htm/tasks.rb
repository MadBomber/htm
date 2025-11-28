# frozen_string_literal: true

# HTM Rake Tasks Loader
#
# Load HTM database management tasks into your application's Rakefile:
#
#   require 'htm/tasks'
#
# This will make the following tasks available:
#
# Database tasks:
#   rake htm:db:setup      # Set up HTM database schema and run migrations
#   rake htm:db:migrate    # Run pending database migrations
#   rake htm:db:status     # Show migration status
#   rake htm:db:info       # Show database info
#   rake htm:db:test       # Test database connection
#   rake htm:db:console    # Open PostgreSQL console
#   rake htm:db:seed       # Seed database with sample data
#   rake htm:db:drop       # Drop all HTM tables (destructive!)
#   rake htm:db:reset      # Drop and recreate database (destructive!)
#
# Async job tasks:
#   rake htm:jobs:stats              # Show async job statistics
#   rake htm:jobs:process_embeddings # Process pending embedding jobs
#   rake htm:jobs:process_tags       # Process pending tag extraction jobs
#   rake htm:jobs:process_all        # Process all pending jobs
#   rake htm:jobs:reprocess_embeddings # Force regenerate all embeddings
#   rake htm:jobs:failed             # Show nodes with processing issues
#   rake htm:jobs:clear_all          # Clear all embeddings and tags (testing)
#
# Tag tasks:
#   rake htm:tags:tree               # Display tags as hierarchical tree
#   rake htm:tags:tree[prefix]       # Display tags with prefix filter
#   rake htm:tags:mermaid            # Export all tags to tags.md (Mermaid)
#   rake htm:tags:mermaid[prefix]    # Export filtered tags to tags.md
#   rake htm:tags:svg                # Export all tags to tags.svg
#   rake htm:tags:svg[prefix]        # Export filtered tags to tags.svg
#   rake htm:tags:export             # Export all tags to tags.txt, tags.md, tags.svg
#   rake htm:tags:export[prefix]     # Export filtered tags to all formats
#
# File loading tasks:
#   rake htm:files:load[path]        # Load a markdown file into memory
#   rake htm:files:load_dir[path]    # Load all markdown files from a directory
#   rake htm:files:list              # List all loaded file sources
#   rake htm:files:info[path]        # Show details for a loaded file
#   rake htm:files:unload[path]      # Unload a file from memory
#   rake htm:files:sync              # Sync all loaded files (reload changed files)
#   rake htm:files:stats             # Show file loading statistics
#

if defined?(Rake)
  # Load the rake tasks
  load File.expand_path('../tasks/htm.rake', __dir__)
  load File.expand_path('../tasks/jobs.rake', __dir__)
  load File.expand_path('../tasks/tags.rake', __dir__)
  load File.expand_path('../tasks/files.rake', __dir__)
else
  warn "HTM tasks not loaded: Rake is not available"
end
