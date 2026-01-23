# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class EnableExtensions < HTM::Migration
  def up
    run "CREATE EXTENSION IF NOT EXISTS vector"
    run "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    run "CREATE EXTENSION IF NOT EXISTS pg_search"
  end

  def down
    run "DROP EXTENSION IF EXISTS pg_search"
    run "DROP EXTENSION IF EXISTS pg_trgm"
    run "DROP EXTENSION IF EXISTS vector"
  end
end
