# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'open3'
require 'rbconfig'

# The examples setup scripts shell out to psql/createdb/dropdb. Those must
# target the server in the examples database URL, not the libpq default.
# Fake binaries on PATH record their arguments and fail, so the scripts
# abort before touching any real database.
class ExamplesDbCommandsTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def setup
    tmp_root = File.join(ROOT, 'test', 'tmp')
    FileUtils.mkdir_p(tmp_root)
    @shim_dir = Dir.mktmpdir('pg_shims', tmp_root)
    @log = File.join(@shim_dir, 'calls.log')
    %w[psql createdb dropdb].each do |cmd|
      path = File.join(@shim_dir, cmd)
      File.write(path, "#!/bin/sh\necho \"#{cmd} $*\" >> '#{@log}'\nexit 1\n")
      File.chmod(0o755, path)
    end
  end

  def teardown
    FileUtils.rm_rf(@shim_dir)
  end

  def test_create_examples_db_targets_configured_server
    run_ruby(File.join(ROOT, 'examples', '00_create_examples_db.rb'))

    assert_targets_examples_server(%w[psql createdb])
  end

  def test_reset_targets_configured_server
    run_ruby('-e', "ARGV << '--reset'; require './examples/examples_helper'; ExamplesHelper.reset_if_requested!")

    assert_targets_examples_server(%w[dropdb])
  end

  private

  def run_ruby(*args)
    env = { 'PATH' => "#{@shim_dir}:#{ENV.fetch('PATH')}", 'HTM_DATABASE__URL' => nil, 'HTM_SERVICE__NAME' => nil }
    Open3.capture2e(env, RbConfig.ruby, *args, chdir: ROOT)
  end

  def assert_targets_examples_server(commands)
    calls = File.readlines(@log, chomp: true)
    user = ENV.fetch('USER')

    assert_equal commands, calls.map { |call| call.split.first }
    calls.each do |call|
      assert_includes call, "-h localhost -p 5432 -U #{user}", call
    end
  end
end
