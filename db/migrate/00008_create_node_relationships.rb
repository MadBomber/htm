# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateNodeRelationships < HTM::Migration
  def up
    create_table(:node_relationships) do
      primary_key :id
      Bignum :source_id, null: false
      Bignum :target_id, null: false
      String :rel_type,  null: false, default: 'related_to'
      String :origin,    null: false, default: 'tag_cooccurrence'
      Float  :weight,    null: false, default: 1.0
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    add_index :node_relationships, [:source_id, :target_id, :rel_type],
              unique: true, name: :idx_node_relationships_unique
    add_index :node_relationships, :source_id, name: :idx_node_relationships_source_id
    add_index :node_relationships, :target_id, name: :idx_node_relationships_target_id
    add_index :node_relationships, :weight,    name: :idx_node_relationships_weight
    add_index :node_relationships, :origin,    name: :idx_node_relationships_origin

    alter_table(:node_relationships) do
      add_foreign_key [:source_id], :nodes, name: :fk_node_relationships_source, on_delete: :cascade
      add_foreign_key [:target_id], :nodes, name: :fk_node_relationships_target, on_delete: :cascade
    end

    run <<~SQL
      ALTER TABLE node_relationships
        ADD CONSTRAINT chk_node_relationships_weight
        CHECK (weight >= 0.0 AND weight <= 1.0)
    SQL

    run <<~SQL
      ALTER TABLE node_relationships
        ADD CONSTRAINT chk_node_relationships_no_self_loop
        CHECK (source_id <> target_id)
    SQL

    run "COMMENT ON TABLE node_relationships IS 'Weighted directed edges between nodes for graph traversal'"
    run "COMMENT ON COLUMN node_relationships.source_id IS 'Starting node of the relationship'"
    run "COMMENT ON COLUMN node_relationships.target_id IS 'Ending node of the relationship'"
    run "COMMENT ON COLUMN node_relationships.rel_type IS 'Semantic label: related_to, supports, contradicts, derived_from'"
    run "COMMENT ON COLUMN node_relationships.origin IS 'How created: tag_cooccurrence, tag_hierarchy, explicit'"
    run "COMMENT ON COLUMN node_relationships.weight IS 'Relationship strength 0.0-1.0 (Jaccard similarity for tag_cooccurrence)'"
    run "COMMENT ON COLUMN node_relationships.updated_at IS 'When weight was last recalculated'"
  end

  def down
    drop_table(:node_relationships)
  end
end
