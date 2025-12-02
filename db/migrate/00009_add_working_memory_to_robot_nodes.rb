# frozen_string_literal: true

class AddWorkingMemoryToRobotNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :robot_nodes, :working_memory, :boolean, default: false, null: false,
               comment: 'True if this node is currently in the robot working memory'

    add_index :robot_nodes, [:robot_id, :working_memory],
              where: 'working_memory = true',
              name: 'idx_robot_nodes_working_memory'
  end
end
