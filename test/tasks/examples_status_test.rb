# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'

# Exercises the examples:status task from the Rakefile. Guards the regression
# where the task still called HTM::ActiveRecordConfig after HTM moved to
# Sequel, so the rescue always reported "Database connected: No".
#
# The task body runs via #execute, which skips the :set_examples_env
# prerequisite, so it talks to the test database rather than htm_examples.
class ExamplesStatusTaskTest < Minitest::Test
  def setup
    skip_without_database

    @rake = Rake::Application.new
    Rake.application = @rake
    @rake.instance_eval { load File.expand_path('../../Rakefile', __dir__) }
  end

  def teardown
    Rake.application = Rake::Application.new
  end

  def test_status_reports_connection_and_table_counts
    out, = capture_io { Rake::Task['examples:status'].execute }

    assert_includes out, "Database connected: Yes"
    %w[nodes robots tags file_sources].each do |table|
      assert_match(/^  #{table}: \d+$/, out)
    end
  end
end
