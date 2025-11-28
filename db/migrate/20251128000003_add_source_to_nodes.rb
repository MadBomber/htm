# frozen_string_literal: true

class AddSourceToNodes < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:nodes, :source_id)
      add_column :nodes, :source_id, :bigint, comment: 'Reference to source file (for file-loaded nodes)'
      add_column :nodes, :chunk_position, :integer, comment: 'Position within source file (0-indexed)'
    end

    unless index_exists?(:nodes, :source_id)
      add_index :nodes, :source_id, name: 'idx_nodes_source_id'
      add_index :nodes, [:source_id, :chunk_position], name: 'idx_nodes_source_chunk_position'
    end

    unless foreign_key_exists?(:nodes, :file_sources, column: :source_id)
      add_foreign_key :nodes, :file_sources, column: :source_id, on_delete: :nullify
    end
  end
end
