# frozen_string_literal: true

class CreateRobots < ActiveRecord::Migration[7.1]
  def change
    create_table :robots, comment: 'Registry of all LLM robots using the HTM system' do |t|
      t.text :name, comment: 'Human-readable name for the robot'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When the robot was first registered'
      t.timestamptz :last_active, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'Last time the robot accessed the system'
    end
  end
end
