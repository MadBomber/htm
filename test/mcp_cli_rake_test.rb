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
