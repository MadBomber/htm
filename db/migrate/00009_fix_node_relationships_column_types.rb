# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class FixNodeRelationshipsColumnTypes < HTM::Migration
  def up
    run "ALTER TABLE node_relationships ALTER COLUMN id TYPE bigint"
    run "ALTER TABLE node_relationships ALTER COLUMN created_at TYPE timestamp with time zone"
    run "ALTER TABLE node_relationships ALTER COLUMN updated_at TYPE timestamp with time zone"
  end

  def down
    run "ALTER TABLE node_relationships ALTER COLUMN id TYPE integer"
    run "ALTER TABLE node_relationships ALTER COLUMN created_at TYPE timestamp without time zone"
    run "ALTER TABLE node_relationships ALTER COLUMN updated_at TYPE timestamp without time zone"
  end
end
