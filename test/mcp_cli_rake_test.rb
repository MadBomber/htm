# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rake"
require "htm/mcp/cli"

# `htm_mcp rake 'task[args]'` must pass bracketed arguments to the task.
class MCPCLIRakeTest < Minitest::Test
  def setup
    @original_application = Rake.application
    @received = nil
  end

  def teardown
    Rake.application = @original_application
  end

  def test_runs_task_with_bracketed_arguments
    with_stub_tasks do
      HTM::MCP::CLI.run_rake(["htm:test:echo[/tmp/a.md,extra]"])
    end

    assert_equal ["/tmp/a.md", "extra"], @received
  end

  def test_runs_task_without_arguments
    with_stub_tasks do
      HTM::MCP::CLI.run_rake(["htm:test:echo"])
    end

    assert_equal [nil, nil], @received
  end

  def test_unknown_task_exits
    with_stub_tasks do
      assert_raises(SystemExit) { HTM::MCP::CLI.run_rake(["htm:test:missing[x]"]) }
    end
    assert_nil @received
  end

  # The shipped rake files must not define top-level tasks such as
  # db:migrate that would merge into a host app's tasks (#71)
  def test_loaded_tasks_are_all_namespaced_under_htm
    original_argv = ARGV.dup
    ARGV.clear
    HTM::MCP::CLI.load_htm_rake_tasks

    # :environment is a deliberate no-op fallback defined by jobs.rake
    outside = Rake.application.tasks.map(&:name).reject { |name| name.start_with?('htm:') || name == 'environment' }

    assert_empty outside
  ensure
    ARGV.replace(original_argv)
  end

  private

  def with_stub_tasks(&block)
    received = ->(args) { @received = args }
    loader = lambda do
      Rake.application = Rake::Application.new
      Rake::Task.define_task(:"htm:test:echo", [:path, :other]) do |_t, args|
        received.call([args[:path], args[:other]])
      end
    end

    HTM::MCP::CLI.stub(:load_htm_rake_tasks, loader, &block)
  end
end
