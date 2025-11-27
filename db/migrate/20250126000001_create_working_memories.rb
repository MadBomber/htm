# frozen_string_literal: true

class CreateWorkingMemories < ActiveRecord::Migration[7.1]
  def change
    create_table :working_memories, comment: 'Per-robot working memory state (optional persistence)' do |t|
      t.bigint :robot_id, null: false, comment: 'Robot whose working memory this belongs to'
      t.bigint :node_id, null: false, comment: 'Node currently in working memory'
      t.timestamptz :added_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When node was added to working memory'
      t.integer :token_count, comment: 'Cached token count for budget tracking'
    end

    add_index :working_memories, :robot_id, name: 'idx_working_memories_robot_id'
    add_index :working_memories, :node_id, name: 'idx_working_memories_node_id'
    add_index :working_memories, [:robot_id, :node_id], unique: true, name: 'idx_working_memories_unique'

    add_foreign_key :working_memories, :robots, on_delete: :cascade
    add_foreign_key :working_memories, :nodes, on_delete: :cascade
  end
end
