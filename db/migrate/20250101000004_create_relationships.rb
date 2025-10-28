# frozen_string_literal: true

class CreateRelationships < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:relationships)
      create_table :relationships, comment: 'Knowledge graph edges connecting related nodes' do |t|
        t.bigint :from_node_id, null: false, comment: 'Source node ID'
        t.bigint :to_node_id, null: false, comment: 'Target node ID'
        t.text :relationship_type, comment: 'Type of relationship: relates_to, caused_by, follows, etc.'
        t.float :strength, default: 1.0, comment: 'Relationship strength/weight (0.0-1.0)'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this relationship was created'
      end

      add_foreign_key :relationships, :nodes, column: :from_node_id, on_delete: :cascade
      add_foreign_key :relationships, :nodes, column: :to_node_id, on_delete: :cascade

      add_index :relationships, [:from_node_id, :to_node_id, :relationship_type],
                unique: true,
                name: 'idx_relationships_unique'
      add_index :relationships, :from_node_id, name: 'idx_relationships_from'
      add_index :relationships, :to_node_id, name: 'idx_relationships_to'
    end
  end
end
