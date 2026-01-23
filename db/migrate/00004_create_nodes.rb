# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateNodes < HTM::Migration
  def up
    create_table(:nodes) do
      primary_key :id
      String :content, text: true, null: false
      Integer :access_count, default: 0, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :last_accessed, default: Sequel::CURRENT_TIMESTAMP
      Integer :token_count
      column :embedding, 'vector(2000)'
      Integer :embedding_dimension
      String :content_hash, size: 64
      DateTime :deleted_at
      Bignum :source_id
      Integer :chunk_position
      column :metadata, :jsonb, default: Sequel.lit("'{}'::jsonb"), null: false
    end

    # Basic indexes for common queries
    add_index :nodes, :created_at, name: :idx_nodes_created_at
    add_index :nodes, :updated_at, name: :idx_nodes_updated_at
    add_index :nodes, :last_accessed, name: :idx_nodes_last_accessed
    add_index :nodes, :access_count, name: :idx_nodes_access_count
    add_index :nodes, :content_hash, unique: true, name: :idx_nodes_content_hash_unique
    add_index :nodes, :deleted_at, name: :idx_nodes_deleted_at
    add_index :nodes, :source_id, name: :idx_nodes_source_id
    add_index :nodes, [:source_id, :chunk_position], name: :idx_nodes_source_chunk_position

    # Comments
    run "COMMENT ON TABLE nodes IS 'Core memory storage for conversation messages and context'"
    run "COMMENT ON COLUMN nodes.content IS 'The conversation message/utterance content'"
    run "COMMENT ON COLUMN nodes.access_count IS 'Number of times this node has been accessed/retrieved'"
    run "COMMENT ON COLUMN nodes.created_at IS 'When this memory was created'"
    run "COMMENT ON COLUMN nodes.updated_at IS 'When this memory was last modified'"
    run "COMMENT ON COLUMN nodes.last_accessed IS 'When this memory was last accessed'"
    run "COMMENT ON COLUMN nodes.token_count IS 'Number of tokens in the content (for context budget management)'"
    run "COMMENT ON COLUMN nodes.embedding IS 'Vector embedding (max 2000 dimensions) for semantic search'"
    run "COMMENT ON COLUMN nodes.embedding_dimension IS 'Actual number of dimensions used in the embedding vector (max 2000)'"
    run "COMMENT ON COLUMN nodes.content_hash IS 'SHA-256 hash of content for deduplication'"
    run "COMMENT ON COLUMN nodes.deleted_at IS 'Soft delete timestamp - node is considered deleted when set'"
    run "COMMENT ON COLUMN nodes.source_id IS 'Reference to source file (for file-loaded nodes)'"
    run "COMMENT ON COLUMN nodes.chunk_position IS 'Position within source file (0-indexed)'"
    run "COMMENT ON COLUMN nodes.metadata IS 'Flexible metadata storage (memory_type, importance, source, etc.)'"

    # Partial index for efficiently querying non-deleted nodes
    run "CREATE INDEX idx_nodes_not_deleted_created_at ON nodes (created_at) WHERE deleted_at IS NULL"

    # GIN index for JSONB metadata queries
    run "CREATE INDEX idx_nodes_metadata ON nodes USING gin(metadata)"

    # Vector similarity search index (HNSW for better performance)
    run <<-SQL
      CREATE INDEX idx_nodes_embedding ON nodes
        USING hnsw (embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64)
    SQL

    # Full-text search on conversation content
    run "CREATE INDEX idx_nodes_content_gin ON nodes USING gin(to_tsvector('english', content))"

    # Trigram indexes for fuzzy matching on conversation content
    run "CREATE INDEX idx_nodes_content_trgm ON nodes USING gin(content gin_trgm_ops)"

    # Check constraint for embedding dimensions
    run <<-SQL
      ALTER TABLE nodes ADD CONSTRAINT check_embedding_dimension
        CHECK (embedding_dimension IS NULL OR (embedding_dimension > 0 AND embedding_dimension <= 2000))
    SQL

    # Partial index for active (non-deleted) node queries
    run "CREATE INDEX idx_nodes_active ON nodes (id) WHERE deleted_at IS NULL"

    # Composite index for embedding-based searches on active nodes
    run "CREATE INDEX idx_nodes_active_with_embedding ON nodes (id) WHERE deleted_at IS NULL AND embedding IS NOT NULL"

    # LZ4 compression for better read performance
    run "ALTER TABLE nodes ALTER COLUMN metadata SET COMPRESSION lz4"
    run "ALTER TABLE nodes ALTER COLUMN content SET COMPRESSION lz4"

    # Foreign key to file_sources table
    alter_table(:nodes) do
      add_foreign_key [:source_id], :file_sources, on_delete: :set_null
    end
  end

  def down
    drop_table(:nodes)
  end
end
