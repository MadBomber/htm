# frozen_string_literal: true

require "test_helper"
require "yaml"
require "htm/mcp/cli"

# `htm_mcp help` documents configuration environment variables. Each one
# must name a real key in the bundled defaults.yml schema, and any default
# it quotes must match that schema, or users set variables that do nothing.
class MCPCLIHelpTest < Minitest::Test
  DEFAULTS_PATH = File.expand_path("../lib/htm/config/defaults.yml", __dir__)

  # HTM_ENV selects the environment; it is not a config key.
  NON_CONFIG_VARS = %w[HTM_ENV].freeze

  def setup
    @defaults = YAML.safe_load_file(DEFAULTS_PATH, permitted_classes: [Symbol])["defaults"]
    @help, _err = capture_io { HTM::MCP::CLI.print_help }
  end

  def test_every_documented_env_var_maps_to_a_config_key
    names = @help.scan(/\bHTM_[A-Z_]+\b/).uniq - NON_CONFIG_VARS
    refute_empty names

    unknown = names.reject { |name| key_path_exists?(key_path(name)) }

    assert_empty unknown, "help lists env vars with no matching key in defaults.yml"
  end

  def test_documented_defaults_match_defaults_yml
    mismatches = @help.scan(/^\s+(HTM_[A-Z_]+)\s.*\(default: ([^)]+)\)/).filter_map do |name, documented|
      actual = @defaults.dig(*key_path(name))
      "#{name}: help says #{documented}, defaults.yml says #{actual}" unless documented == actual.to_s
    end

    assert_empty mismatches
  end

  def test_job_backends_include_every_supported_backend
    line = @help.lines.find { |l| l.include?("HTM_JOB__BACKEND") }

    %w[fiber thread inline active_job sidekiq].each do |backend|
      assert_includes line, backend
    end
  end

  private

  def key_path(env_name)
    env_name.delete_prefix("HTM_").downcase.split("__")
  end

  def key_path_exists?(path)
    *parents, leaf = path
    container = parents.empty? ? @defaults : @defaults.dig(*parents)
    container.is_a?(Hash) && container.key?(leaf)
  end
end
