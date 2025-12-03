# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Partial index for soft-delete filter (used in almost every query)
    # This complements idx_nodes_not_deleted_created_at for queries that
    # don't need created_at ordering but still filter by deleted_at IS NULL
    add_index :nodes, :id,
              name: 'idx_nodes_active',
              where: 'deleted_at IS NULL',
              comment: 'Partial index for active (non-deleted) node queries'

    # Composite index for embedding-based searches on active nodes
    # Helps vector_search and hybrid_search which filter by deleted_at IS NULL
    # and embedding IS NOT NULL
    execute <<-SQL
      CREATE INDEX idx_nodes_active_with_embedding ON nodes (id)
        WHERE deleted_at IS NULL AND embedding IS NOT NULL
    SQL
  end
end
