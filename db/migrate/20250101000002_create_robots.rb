# frozen_string_literal: true

class CreateRobots < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:robots)
      create_table :robots, id: false, comment: 'Registry of all LLM robots using the HTM system' do |t|
        t.text :id, primary_key: true, null: false, comment: 'Unique identifier for the robot'
        t.text :name, comment: 'Human-readable name for the robot'
        t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When the robot was first registered'
        t.timestamptz :last_active, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'Last time the robot accessed the system'
        t.jsonb :metadata, comment: 'Robot-specific configuration and metadata'
      end
    end
  end
end
