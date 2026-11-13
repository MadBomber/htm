# frozen_string_literal: true

require "test_helper"

# HTM::Database.drop removes HTM::Database::TABLES. A table missing from that
# list survives a drop and makes the next migrate fail (htm:db:reset).
class DatabaseTablesTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../db/schema.sql", __dir__)

  def test_tables_match_schema
    schema_tables = File.read(SCHEMA_PATH).scan(/^CREATE TABLE public\.(\w+)/).flatten

    assert_equal schema_tables.sort, HTM::Database::TABLES.sort
  end
end
