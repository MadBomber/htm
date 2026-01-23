# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateNodeTags < HTM::Migration
  def up
    create_table(:node_tags) do
      primary_key :id
      Bignum :node_id, null: false
      Bignum :tag_id, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :deleted_at
    end

    add_index :node_tags, [:node_id, :tag_id], unique: true, name: :idx_node_tags_unique
    add_index :node_tags, :node_id, name: :idx_node_tags_node_id
    add_index :node_tags, :tag_id, name: :idx_node_tags_tag_id
    add_index :node_tags, :deleted_at, name: :idx_node_tags_deleted_at

    alter_table(:node_tags) do
      add_foreign_key [:node_id], :nodes, on_delete: :cascade
      add_foreign_key [:tag_id], :tags, on_delete: :cascade
    end

    run "COMMENT ON TABLE node_tags IS 'Join table connecting nodes to tags (many-to-many)'"
    run "COMMENT ON COLUMN node_tags.node_id IS 'ID of the node being tagged'"
    run "COMMENT ON COLUMN node_tags.tag_id IS 'ID of the tag being applied'"
    run "COMMENT ON COLUMN node_tags.created_at IS 'When this association was created'"
    run "COMMENT ON COLUMN node_tags.deleted_at IS 'Soft delete timestamp'"
  end

  def down
    drop_table(:node_tags)
  end
end
