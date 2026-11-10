# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'
require 'tmpdir'
require 'fileutils'

# Exercises the htm:files:unload rake task end to end against a real test
# database. Guards the regression where the task branched on unload_file's
# return value (a chunk count: 0 when nothing matched), and 0 is truthy in
# Ruby, so an unknown path still printed "Unloaded:".
class FilesUnloadTaskTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    @htm = HTM.new(robot_name: "FilesUnloadTaskTest")
    @temp_dir = Dir.mktmpdir('htm_unload_task_test')

    @rake = Rake::Application.new
    Rake.application = @rake
    @rake.instance_eval { load File.expand_path('../../lib/tasks/files.rake', __dir__) }

    clean_sources
  end

  def teardown
    return unless database_available?

    Rake.application = Rake::Application.new
    clean_sources
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_unload_reports_not_found_for_unknown_file
    path = File.join(@temp_dir, 'never_loaded.md')

    out = run_unload(path)

    assert_includes out, "File not found: #{path}"
    refute_includes out, "Unloaded:"
  end

  def test_unload_reports_success_for_loaded_file
    path = File.join(@temp_dir, 'loaded.md')
    File.write(path, "# Heading\n\nA paragraph worth remembering.")
    @htm.load_file(path, force: true)

    out = run_unload(path)

    assert_match(/Unloaded: #{Regexp.escape(path)} \(\d+ chunks\)/, out)
    refute_includes out, "File not found:"
  end

  private

  def run_unload(path)
    task = Rake::Task["htm:files:unload"]
    task.reenable
    stdout, = capture_io { task.invoke(path) }
    stdout
  end

  def clean_sources
    HTM::Models::FileSource.where(Sequel.like(:file_path, "%#{@temp_dir}%")).each do |fs|
      fs.nodes_dataset.update(source_id: nil)
      fs.destroy
    end
  end
end
