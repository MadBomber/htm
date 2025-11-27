# frozen_string_literal: true

class RemoveUnusedColumns < ActiveRecord::Migration[7.1]
  def change
    # Remove in_working_memory from nodes - now tracked per-robot in working_memories table
    remove_index :nodes, name: 'idx_nodes_in_working_memory', if_exists: true
    remove_column :nodes, :in_working_memory, :boolean, default: false

    # Remove unused metadata column from robots
    remove_column :robots, :metadata, :jsonb
  end
end
