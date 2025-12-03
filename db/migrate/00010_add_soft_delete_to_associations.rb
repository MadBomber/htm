# frozen_string_literal: true

class AddSoftDeleteToAssociations < ActiveRecord::Migration[7.0]
  def change
    # Add deleted_at to robot_nodes for soft delete support
    unless column_exists?(:robot_nodes, :deleted_at)
      add_column :robot_nodes, :deleted_at, :datetime, null: true
    end
    unless index_exists?(:robot_nodes, :deleted_at)
      add_index :robot_nodes, :deleted_at
    end

    # Add deleted_at to node_tags for soft delete support
    unless column_exists?(:node_tags, :deleted_at)
      add_column :node_tags, :deleted_at, :datetime, null: true
    end
    unless index_exists?(:node_tags, :deleted_at)
      add_index :node_tags, :deleted_at
    end

    # Add deleted_at to tags for soft delete support
    unless column_exists?(:tags, :deleted_at)
      add_column :tags, :deleted_at, :datetime, null: true
    end
    unless index_exists?(:tags, :deleted_at)
      add_index :tags, :deleted_at
    end
  end
end
