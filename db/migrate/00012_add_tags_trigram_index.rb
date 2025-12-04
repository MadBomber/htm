# frozen_string_literal: true

class AddTagsTrigramIndex < ActiveRecord::Migration[7.0]
  def up
    # Add GIN trigram index on tags.name for fuzzy search
    # Enables queries like: WHERE name % 'postgrsql' (typo-tolerant)
    # Also speeds up LIKE '%pattern%' queries
    execute <<~SQL
      CREATE INDEX idx_tags_name_trgm ON tags USING gin(name gin_trgm_ops);
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS idx_tags_name_trgm;
    SQL
  end
end
