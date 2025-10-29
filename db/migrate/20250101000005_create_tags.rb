# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[7.1]
  def change
    # Create tags table with unique tag names
    unless table_exists?(:tags)
      create_table :tags, comment: 'Unique tag names for categorization' do |t|
        t.text :name, null: false, comment: 'Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb)'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this tag was created'
      end

      add_index :tags, :name, unique: true, name: 'idx_tags_name_unique'
      add_index :tags, :name, using: :btree, opclass: :text_pattern_ops, name: 'idx_tags_name_pattern'
    end

    # Create join table for many-to-many relationship
    unless table_exists?(:nodes_tags)
      create_table :nodes_tags, comment: 'Join table connecting nodes to tags (many-to-many)' do |t|
        t.bigint :node_id, null: false, comment: 'ID of the node being tagged'
        t.bigint :tag_id, null: false, comment: 'ID of the tag being applied'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this association was created'
      end

      add_index :nodes_tags, [:node_id, :tag_id], unique: true, name: 'idx_nodes_tags_unique'
      add_index :nodes_tags, :node_id, name: 'idx_nodes_tags_node_id'
      add_index :nodes_tags, :tag_id, name: 'idx_nodes_tags_tag_id'
    end

    # Add foreign keys (outside table_exists check so they get added even if table already exists)
    unless foreign_key_exists?(:nodes_tags, :nodes, column: :node_id)
      add_foreign_key :nodes_tags, :nodes, column: :node_id, primary_key: :id, on_delete: :cascade
    end

    unless foreign_key_exists?(:nodes_tags, :tags, column: :tag_id)
      add_foreign_key :nodes_tags, :tags, column: :tag_id, primary_key: :id, on_delete: :cascade
    end
  end
end
