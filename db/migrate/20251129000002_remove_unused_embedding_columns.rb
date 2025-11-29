# frozen_string_literal: true

class RemoveUnusedEmbeddingColumns < ActiveRecord::Migration[7.0]
  def change
    # Remove embedding_model - not needed since we always use the configured model
    remove_index :nodes, :embedding_model, if_exists: true
    remove_column :nodes, :embedding_model, :string

    # Remove embedding_dimension - not useful since embeddings are always padded to 2000
    remove_column :nodes, :embedding_dimension, :integer
  end
end
