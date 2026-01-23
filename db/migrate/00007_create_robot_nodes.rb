# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateRobotNodes < HTM::Migration
  def up
    create_table(:robot_nodes) do
      primary_key :id
      Bignum :robot_id, null: false
      Bignum :node_id, null: false
      DateTime :first_remembered_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :last_remembered_at, default: Sequel::CURRENT_TIMESTAMP
      Integer :remember_count, default: 1, null: false
      TrueClass :working_memory, default: false, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :deleted_at
    end

    add_index :robot_nodes, [:robot_id, :node_id], unique: true, name: :idx_robot_nodes_unique
    add_index :robot_nodes, :robot_id, name: :idx_robot_nodes_robot_id
    add_index :robot_nodes, :node_id, name: :idx_robot_nodes_node_id
    add_index :robot_nodes, :last_remembered_at, name: :idx_robot_nodes_last_remembered_at
    add_index :robot_nodes, :deleted_at, name: :idx_robot_nodes_deleted_at

    # Partial index for working memory queries
    run "CREATE INDEX idx_robot_nodes_working_memory ON robot_nodes (robot_id, working_memory) WHERE working_memory = true"

    alter_table(:robot_nodes) do
      add_foreign_key [:robot_id], :robots, on_delete: :cascade
      add_foreign_key [:node_id], :nodes, on_delete: :cascade
    end

    run "COMMENT ON TABLE robot_nodes IS 'Join table connecting robots to nodes (many-to-many)'"
    run "COMMENT ON COLUMN robot_nodes.robot_id IS 'ID of the robot that remembered this node'"
    run "COMMENT ON COLUMN robot_nodes.node_id IS 'ID of the node being remembered'"
    run "COMMENT ON COLUMN robot_nodes.first_remembered_at IS 'When this robot first remembered this content'"
    run "COMMENT ON COLUMN robot_nodes.last_remembered_at IS 'When this robot last tried to remember this content'"
    run "COMMENT ON COLUMN robot_nodes.remember_count IS 'Number of times this robot has tried to remember this content'"
    run "COMMENT ON COLUMN robot_nodes.working_memory IS 'True if this node is currently in the robot working memory'"
    run "COMMENT ON COLUMN robot_nodes.deleted_at IS 'Soft delete timestamp'"
  end

  def down
    drop_table(:robot_nodes)
  end
end
