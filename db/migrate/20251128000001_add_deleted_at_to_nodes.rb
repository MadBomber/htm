# frozen_string_literal: true

class AddDeletedAtToNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :nodes, :deleted_at, :timestamptz, comment: 'Soft delete timestamp - node is considered deleted when set'
    add_index :nodes, :deleted_at, name: 'idx_nodes_deleted_at'

    # Partial index for efficiently querying non-deleted nodes
    add_index :nodes, :created_at, name: 'idx_nodes_not_deleted_created_at',
              where: 'deleted_at IS NULL'
  end
end
