# frozen_string_literal: true

class AddContentHashToNodes < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:nodes, :content_hash)
      # Add content_hash column for SHA-256 hash of content (64 hex characters)
      add_column :nodes, :content_hash, :string, limit: 64,
                 comment: 'SHA-256 hash of content for deduplication'

      # Unique index to prevent duplicate content
      add_index :nodes, :content_hash, unique: true, name: 'idx_nodes_content_hash_unique'
    end
  end
end
