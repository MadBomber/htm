# frozen_string_literal: true

class CreateNodes < ActiveRecord::Migration[7.1]
  def change
    create_table :nodes, comment: 'Core memory storage for conversation messages and context' do |t|
      t.text :content, null: false, comment: 'The conversation message/utterance content'
      t.integer :access_count, default: 0, null: false, comment: 'Number of times this node has been accessed/retrieved'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was created'
      t.timestamptz :updated_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was last modified'
      t.timestamptz :last_accessed, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was last accessed'
      t.integer :token_count, comment: 'Number of tokens in the content (for context budget management)'
      t.vector :embedding, limit: 2000, comment: 'Vector embedding (max 2000 dimensions) for semantic search'
      t.integer :embedding_dimension, comment: 'Actual number of dimensions used in the embedding vector (max 2000)'
      t.string :content_hash, limit: 64, comment: 'SHA-256 hash of content for deduplication'
      t.timestamptz :deleted_at, comment: 'Soft delete timestamp - node is considered deleted when set'
      t.bigint :source_id, comment: 'Reference to source file (for file-loaded nodes)'
      t.integer :chunk_position, comment: 'Position within source file (0-indexed)'
    end

    # Basic indexes for common queries
    add_index :nodes, :created_at, name: 'idx_nodes_created_at'
    add_index :nodes, :updated_at, name: 'idx_nodes_updated_at'
    add_index :nodes, :last_accessed, name: 'idx_nodes_last_accessed'
    add_index :nodes, :access_count, name: 'idx_nodes_access_count'
    add_index :nodes, :content_hash, unique: true, name: 'idx_nodes_content_hash_unique'
    add_index :nodes, :deleted_at, name: 'idx_nodes_deleted_at'
    add_index :nodes, :source_id, name: 'idx_nodes_source_id'
    add_index :nodes, [:source_id, :chunk_position], name: 'idx_nodes_source_chunk_position'

    # Partial index for efficiently querying non-deleted nodes
    add_index :nodes, :created_at, name: 'idx_nodes_not_deleted_created_at', where: 'deleted_at IS NULL'

    # Vector similarity search index (HNSW for better performance)
    execute <<-SQL
      CREATE INDEX idx_nodes_embedding ON nodes
        USING hnsw (embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64)
    SQL

    # Full-text search on conversation content
    execute <<-SQL
      CREATE INDEX idx_nodes_content_gin ON nodes
        USING gin(to_tsvector('english', content))
    SQL

    # Trigram indexes for fuzzy matching on conversation content
    execute <<-SQL
      CREATE INDEX idx_nodes_content_trgm ON nodes
        USING gin(content gin_trgm_ops)
    SQL

    # Check constraint for embedding dimensions
    execute <<-SQL
      ALTER TABLE nodes ADD CONSTRAINT check_embedding_dimension
        CHECK (embedding_dimension IS NULL OR (embedding_dimension > 0 AND embedding_dimension <= 2000))
    SQL

    # Foreign key to file_sources table
    add_foreign_key :nodes, :file_sources, column: :source_id, on_delete: :nullify
  end
end
