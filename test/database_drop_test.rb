# frozen_string_literal: true

require_relative 'test_helper'

class DatabaseDropTest < Minitest::Test
  SCHEMA_FILE = File.expand_path('../db/schema.sql', __dir__)

  def test_drop_list_covers_every_table_in_schema
    schema_tables = File.read(SCHEMA_FILE).scan(/^CREATE TABLE public\.(\w+)/).flatten

    assert_empty schema_tables - HTM::Database::TABLES
  end

  def test_drop_removes_every_table_so_setup_can_rerun
    skip_without_database

    capture_io { HTM::Database.drop }

    assert_empty public_tables
  ensure
    capture_io { HTM::Database.setup } if database_available?
  end

  private

  def public_tables
    HTM.db.fetch("SELECT tablename FROM pg_tables WHERE schemaname = 'public'").map(:tablename)
  end
end
