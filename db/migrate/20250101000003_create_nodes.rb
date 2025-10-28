# frozen_string_literal: true

class CreateNodes < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:nodes)
      create_table :nodes, comment: 'Core memory storage for conversation messages and context' do |t|
        t.text :content, null: false, comment: 'The conversation message/utterance content'
        t.text :speaker, null: false, comment: 'Who said it: user or robot name'
        t.text :type, comment: 'Memory type: fact, context, code, preference, decision, question'
        t.text :category, comment: 'Optional category for organizing memories'
        t.float :importance, default: 1.0, comment: 'Importance score (0.0-1.0) for prioritizing recall'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was created'
        t.timestamptz :updated_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was last modified'
        t.timestamptz :last_accessed, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this memory was last accessed'
        t.integer :token_count, comment: 'Number of tokens in the content (for context budget management)'
        t.boolean :in_working_memory, default: false, comment: 'Whether this memory is currently in working memory'
        t.text :robot_id, null: false, comment: 'ID of the robot that owns this memory'
        t.column :embedding, 'vector(2000)', comment: 'Vector embedding (max 2000 dimensions) for semantic search'
        t.integer :embedding_dimension, comment: 'Actual number of dimensions used in the embedding vector (max 2000)'
      end

      # Basic indexes for common queries
      add_index :nodes, :created_at, name: 'idx_nodes_created_at'
      add_index :nodes, :updated_at, name: 'idx_nodes_updated_at'
      add_index :nodes, :last_accessed, name: 'idx_nodes_last_accessed'
      add_index :nodes, :type, name: 'idx_nodes_type'
      add_index :nodes, :category, name: 'idx_nodes_category'
      add_index :nodes, :robot_id, name: 'idx_nodes_robot_id'
      add_index :nodes, :speaker, name: 'idx_nodes_speaker'
      add_index :nodes, :in_working_memory, name: 'idx_nodes_in_working_memory'

      # Add check constraint for embedding dimensions
      # Only validates when embedding_dimension is provided (allows NULL for nodes without embeddings)
      execute <<-SQL
        ALTER TABLE nodes ADD CONSTRAINT check_embedding_dimension
          CHECK (embedding_dimension IS NULL OR (embedding_dimension > 0 AND embedding_dimension <= 2000))
      SQL
    end
  end
end
