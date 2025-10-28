# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:tags)
      create_table :tags, comment: 'Hierarchical topic tags for flexible categorization using colon-delimited format' do |t|
        t.bigint :node_id, null: false, comment: 'ID of the node being tagged'
        t.text :tag, null: false, comment: 'Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb)'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this tag was created'
      end

      add_foreign_key :tags, :nodes, on_delete: :cascade

      add_index :tags, [:node_id, :tag], unique: true, name: 'idx_tags_unique'
      add_index :tags, :node_id, name: 'idx_tags_node_id'
      add_index :tags, :tag, name: 'idx_tags_tag'
      add_index :tags, :tag, using: :btree, opclass: :text_pattern_ops, name: 'idx_tags_tag_pattern'
    end
  end
end
