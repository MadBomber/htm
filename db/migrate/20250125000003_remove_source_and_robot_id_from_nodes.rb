# frozen_string_literal: true

class RemoveSourceAndRobotIdFromNodes < ActiveRecord::Migration[7.1]
  def change
    # Remove foreign key constraint first
    if foreign_key_exists?(:nodes, :robots, column: :robot_id)
      remove_foreign_key :nodes, :robots, column: :robot_id
    end

    # Remove indexes
    if index_exists?(:nodes, :robot_id, name: 'idx_nodes_robot_id')
      remove_index :nodes, name: 'idx_nodes_robot_id'
    end

    if index_exists?(:nodes, :source, name: 'idx_nodes_source')
      remove_index :nodes, name: 'idx_nodes_source'
    end

    # Remove columns
    if column_exists?(:nodes, :robot_id)
      remove_column :nodes, :robot_id
    end

    if column_exists?(:nodes, :source)
      remove_column :nodes, :source
    end
  end
end
