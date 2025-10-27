# frozen_string_literal: true

# HTM Rake Tasks Loader
#
# Load HTM database management tasks into your application's Rakefile:
#
#   require 'htm/tasks'
#
# This will make the following tasks available:
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

if defined?(Rake)
  # Load the rake tasks
  load File.expand_path('../tasks/htm.rake', __dir__)
else
  warn "HTM tasks not loaded: Rake is not available"
end
