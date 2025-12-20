# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'

class XdgConfigLoaderTest < Minitest::Test
  def setup
    @original_xdg_config_home = ENV['XDG_CONFIG_HOME']
    @temp_dir = Dir.mktmpdir('htm_xdg_test')
  end

  def teardown
    # Restore original env
    if @original_xdg_config_home
      ENV['XDG_CONFIG_HOME'] = @original_xdg_config_home
    else
      ENV.delete('XDG_CONFIG_HOME')
    end

    # Clean up temp directory
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_config_paths_includes_xdg_default
    paths = HTM::Loaders::XdgConfigLoader.config_paths
    assert paths.any? { |p| p.include?('.config/htm') }
  end

  def test_config_paths_includes_xdg_config_home_when_set
    ENV['XDG_CONFIG_HOME'] = @temp_dir

    paths = HTM::Loaders::XdgConfigLoader.config_paths
    assert paths.any? { |p| p.start_with?(@temp_dir) }
  end

  def test_config_paths_includes_macos_app_support_on_darwin
    skip unless RUBY_PLATFORM.include?('darwin')

    paths = HTM::Loaders::XdgConfigLoader.config_paths
    assert paths.any? { |p| p.include?('Library/Application Support/htm') }
  end

  def test_find_config_file_returns_nil_when_no_file_exists
    ENV['XDG_CONFIG_HOME'] = @temp_dir

    result = HTM::Loaders::XdgConfigLoader.find_config_file('htm')
    assert_nil result
  end

  def test_find_config_file_returns_path_when_file_exists
    ENV['XDG_CONFIG_HOME'] = @temp_dir
    config_dir = File.join(@temp_dir, 'htm')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'htm.yml')
    File.write(config_file, "test: value\n")

    result = HTM::Loaders::XdgConfigLoader.find_config_file('htm')
    assert_equal config_file, result
  end

  def test_loader_returns_empty_hash_when_no_file
    ENV['XDG_CONFIG_HOME'] = @temp_dir

    loader = HTM::Loaders::XdgConfigLoader.new(local: false)
    result = loader.call(name: 'htm')

    assert_equal({}, result)
  end

  def test_loader_loads_flat_config
    ENV['XDG_CONFIG_HOME'] = @temp_dir
    config_dir = File.join(@temp_dir, 'htm')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'htm.yml')
    File.write(config_file, <<~YAML)
      embedding_provider: openai
      embedding_model: text-embedding-3-small
    YAML

    loader = HTM::Loaders::XdgConfigLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Raw loader returns strings; type coercion happens at Config level
    assert_equal 'openai', result[:embedding_provider]
    assert_equal 'text-embedding-3-small', result[:embedding_model]
  end

  def test_loader_loads_environment_specific_config
    ENV['XDG_CONFIG_HOME'] = @temp_dir
    ENV['HTM_ENV'] = 'production'

    config_dir = File.join(@temp_dir, 'htm')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'htm.yml')
    File.write(config_file, <<~YAML)
      development:
        embedding_provider: ollama
      production:
        embedding_provider: openai
    YAML

    loader = HTM::Loaders::XdgConfigLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Raw loader returns strings; type coercion happens at Config level
    assert_equal 'openai', result[:embedding_provider]
  ensure
    ENV.delete('HTM_ENV')
  end

  def test_xdg_config_file_class_method
    path = HTM::Config.xdg_config_file
    assert path.end_with?('htm/htm.yml')
    assert path.include?('.config') || path.include?(ENV['XDG_CONFIG_HOME'].to_s)
  end

  def test_xdg_config_paths_class_method
    paths = HTM::Config.xdg_config_paths
    assert_instance_of Array, paths
    assert paths.length >= 1
  end

  def test_active_xdg_config_file_returns_nil_when_no_config
    ENV['XDG_CONFIG_HOME'] = @temp_dir

    result = HTM::Config.active_xdg_config_file
    assert_nil result
  end

  def test_active_xdg_config_file_returns_path_when_exists
    ENV['XDG_CONFIG_HOME'] = @temp_dir
    config_dir = File.join(@temp_dir, 'htm')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'htm.yml')
    File.write(config_file, "test: value\n")

    result = HTM::Config.active_xdg_config_file
    assert_equal config_file, result
  end

  def test_loader_handles_invalid_yaml_gracefully
    ENV['XDG_CONFIG_HOME'] = @temp_dir
    config_dir = File.join(@temp_dir, 'htm')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'htm.yml')
    File.write(config_file, "invalid: yaml: syntax:\n  - broken")

    loader = HTM::Loaders::XdgConfigLoader.new(local: false)

    # Should not raise, should return empty hash
    result = loader.call(name: 'htm')
    assert_instance_of Hash, result
  end
end
