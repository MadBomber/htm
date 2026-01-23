# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateRobots < HTM::Migration
  def up
    create_table(:robots) do
      primary_key :id
      String :name, text: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :last_active, default: Sequel::CURRENT_TIMESTAMP
    end

    run "COMMENT ON TABLE robots IS 'Registry of all LLM robots using the HTM system'"
    run "COMMENT ON COLUMN robots.name IS 'Human-readable name for the robot'"
    run "COMMENT ON COLUMN robots.created_at IS 'When the robot was first registered'"
    run "COMMENT ON COLUMN robots.last_active IS 'Last time the robot accessed the system'"
  end

  def down
    drop_table(:robots)
  end
end
