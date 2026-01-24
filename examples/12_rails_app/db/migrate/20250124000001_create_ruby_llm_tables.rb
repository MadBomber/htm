# frozen_string_literal: true

class CreateRubyLlmTables < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.text :instructions

      t.timestamps
    end

    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens

      t.timestamps
    end

    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.jsonb :arguments, default: {}

      t.timestamps
    end

    add_index :tool_calls, :tool_call_id
  end
end
