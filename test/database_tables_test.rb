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

  def test_info_counts_every_table
    conn = Object.new
    queries = []
    conn.define_singleton_method(:exec) do |sql|
      queries << sql
      [{ 'count' => '0' }]
    end

    capture_io { HTM::Database.send(:print_table_counts, conn) }

    counted = queries.map { |sql| sql[/FROM (\w+)/, 1] }
    assert_equal HTM::Database::TABLES.sort, counted.sort
  end
end
