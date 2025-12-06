# frozen_string_literal: true

class CreateRobotNodes < ActiveRecord::Migration[7.1]
  def change
    create_table :robot_nodes, comment: 'Join table connecting robots to nodes (many-to-many)' do |t|
      t.bigint :robot_id, null: false, comment: 'ID of the robot that remembered this node'
      t.bigint :node_id, null: false, comment: 'ID of the node being remembered'
      t.timestamptz :first_remembered_at, default: -> { 'CURRENT_TIMESTAMP' },
                    comment: 'When this robot first remembered this content'
      t.timestamptz :last_remembered_at, default: -> { 'CURRENT_TIMESTAMP' },
                    comment: 'When this robot last tried to remember this content'
      t.integer :remember_count, default: 1, null: false,
                comment: 'Number of times this robot has tried to remember this content'
      t.boolean :working_memory, default: false, null: false,
                comment: 'True if this node is currently in the robot working memory'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :updated_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :deleted_at, comment: 'Soft delete timestamp'
    end

    add_index :robot_nodes, [:robot_id, :node_id], unique: true, name: 'idx_robot_nodes_unique'
    add_index :robot_nodes, :robot_id, name: 'idx_robot_nodes_robot_id'
    add_index :robot_nodes, :node_id, name: 'idx_robot_nodes_node_id'
    add_index :robot_nodes, :last_remembered_at, name: 'idx_robot_nodes_last_remembered_at'
    add_index :robot_nodes, :deleted_at, name: 'idx_robot_nodes_deleted_at'
    add_index :robot_nodes, [:robot_id, :working_memory],
              where: 'working_memory = true',
              name: 'idx_robot_nodes_working_memory'

    add_foreign_key :robot_nodes, :robots, column: :robot_id, on_delete: :cascade
    add_foreign_key :robot_nodes, :nodes, column: :node_id, on_delete: :cascade
  end
end
