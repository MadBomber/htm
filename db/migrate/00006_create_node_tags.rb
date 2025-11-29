# frozen_string_literal: true

class CreateNodeTags < ActiveRecord::Migration[7.1]
  def change
    create_table :node_tags, comment: 'Join table connecting nodes to tags (many-to-many)' do |t|
      t.bigint :node_id, null: false, comment: 'ID of the node being tagged'
      t.bigint :tag_id, null: false, comment: 'ID of the tag being applied'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this association was created'
    end

    add_index :node_tags, [:node_id, :tag_id], unique: true, name: 'idx_node_tags_unique'
    add_index :node_tags, :node_id, name: 'idx_node_tags_node_id'
    add_index :node_tags, :tag_id, name: 'idx_node_tags_tag_id'

    add_foreign_key :node_tags, :nodes, column: :node_id, on_delete: :cascade
    add_foreign_key :node_tags, :tags, column: :tag_id, on_delete: :cascade
  end
end
