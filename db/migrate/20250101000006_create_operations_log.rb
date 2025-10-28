# frozen_string_literal: true

class CreateOperationsLog < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:operations_log)
      create_table :operations_log, comment: 'Audit trail of all HTM operations for debugging and replay' do |t|
        t.timestamptz :timestamp, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this operation occurred'
        t.text :operation, null: false, comment: 'Operation type: add, retrieve, remove, evict, recall'
        t.bigint :node_id, comment: 'ID of the node affected by this operation (if applicable)'
        t.text :robot_id, null: false, comment: 'ID of the robot that performed this operation'
        t.jsonb :details, comment: 'Additional operation details and context'
      end

      # Indexes for common queries
      add_index :operations_log, :timestamp, name: 'idx_operations_log_timestamp'
      add_index :operations_log, :robot_id, name: 'idx_operations_log_robot_id'
      add_index :operations_log, :node_id, name: 'idx_operations_log_node_id'
      add_index :operations_log, :operation, name: 'idx_operations_log_operation'
    end

    # Foreign keys (outside table_exists check so they get added even if table already exists)
    unless foreign_key_exists?(:operations_log, :robots, column: :robot_id)
      add_foreign_key :operations_log, :robots, column: :robot_id, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:operations_log, :nodes, column: :node_id)
      add_foreign_key :operations_log, :nodes, column: :node_id, on_delete: :cascade
    end
  end
end
