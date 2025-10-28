# frozen_string_literal: true

class AddNodeVectorIndexes < ActiveRecord::Migration[7.1]
  def up
    # Vector similarity search index (HNSW for better performance)
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_nodes_embedding ON nodes
        USING hnsw (embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64)
    SQL

    # Full-text search on conversation content
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_nodes_content_gin ON nodes
        USING gin(to_tsvector('english', content))
    SQL

    # Trigram indexes for fuzzy matching on conversation content
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_nodes_content_trgm ON nodes
        USING gin(content gin_trgm_ops)
    SQL
  end

  def down
    remove_index :nodes, name: 'idx_nodes_embedding'
    remove_index :nodes, name: 'idx_nodes_content_gin'
    remove_index :nodes, name: 'idx_nodes_content_trgm'
  end
end
