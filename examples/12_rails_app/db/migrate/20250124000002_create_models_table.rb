# frozen_string_literal: true

class CreateModelsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :models, [:provider, :model_id], unique: true
    add_index :models, :provider
    add_index :models, :family
    add_index :models, :capabilities, using: :gin
    add_index :models, :modalities, using: :gin
  end
end
