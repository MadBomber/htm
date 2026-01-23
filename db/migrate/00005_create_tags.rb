# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateTags < HTM::Migration
  def up
    create_table(:tags) do
      primary_key :id
      String :name, text: true, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :deleted_at
    end

    add_index :tags, :name, unique: true, name: :idx_tags_name_unique
    add_index :tags, :deleted_at, name: :idx_tags_deleted_at

    # Pattern matching index for prefix queries
    run "CREATE INDEX idx_tags_name_pattern ON tags USING btree (name text_pattern_ops)"

    # GIN trigram index for fuzzy search (typo-tolerant queries)
    run "CREATE INDEX idx_tags_name_trgm ON tags USING gin(name gin_trgm_ops)"

    run "COMMENT ON TABLE tags IS 'Unique tag names for categorization'"
    run "COMMENT ON COLUMN tags.name IS 'Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb)'"
    run "COMMENT ON COLUMN tags.created_at IS 'When this tag was created'"
    run "COMMENT ON COLUMN tags.deleted_at IS 'Soft delete timestamp'"
  end

  def down
    drop_table(:tags)
  end
end
