# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "htm/mcp/cli"

# htm_mcp must accept a database configured anywhere HTM.config reads from
# (env, --config file, ~/.config/htm/htm.yml, defaults), not only ENV.
class MCPCLIDatabaseConfigTest < Minitest::Test
  def test_passes_when_htm_config_has_a_database_without_env_vars
    config = Struct.new(:database_configured?).new(true)

    without_database_env do
      HTM.stub(:config, config) { HTM::MCP::CLI.check_database_config! }
    end

    pass
  end

  def test_exits_when_no_database_is_configured
    config = Struct.new(:database_configured?).new(false)

    HTM.stub(:config, config) do
      assert_raises(SystemExit) { HTM::MCP::CLI.check_database_config! }
    end
  end

  private

  def without_database_env
    saved = ENV.to_h.slice("HTM_DATABASE__URL", "HTM_DATABASE__NAME")
    saved.each_key { |key| ENV.delete(key) }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
