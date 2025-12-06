# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags, comment: 'Unique tag names for categorization' do |t|
      t.text :name, null: false, comment: 'Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb)'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this tag was created'
      t.timestamptz :deleted_at, comment: 'Soft delete timestamp'
    end

    add_index :tags, :name, unique: true, name: 'idx_tags_name_unique'
    add_index :tags, :name, using: :btree, opclass: :text_pattern_ops, name: 'idx_tags_name_pattern'
    add_index :tags, :deleted_at, name: 'idx_tags_deleted_at'

    # GIN trigram index for fuzzy search (typo-tolerant queries)
    execute <<~SQL
      CREATE INDEX idx_tags_name_trgm ON tags USING gin(name gin_trgm_ops);
    SQL
  end
end
