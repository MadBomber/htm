# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'

class DefaultsLoaderTest < Minitest::Test
  def setup
    @original_htm_env = ENV['HTM_ENV']
    @original_rails_env = ENV['RAILS_ENV']
    @original_rack_env = ENV['RACK_ENV']
    @original_xdg_config_home = ENV['XDG_CONFIG_HOME']
    @temp_dir = Dir.mktmpdir('htm_defaults_test')
    # Isolate from user's XDG config to test bundled defaults in isolation
    ENV['XDG_CONFIG_HOME'] = @temp_dir
  end

  def teardown
    # Restore original environment variables
    @original_htm_env ? ENV['HTM_ENV'] = @original_htm_env : ENV.delete('HTM_ENV')
    @original_rails_env ? ENV['RAILS_ENV'] = @original_rails_env : ENV.delete('RAILS_ENV')
    @original_rack_env ? ENV['RACK_ENV'] = @original_rack_env : ENV.delete('RACK_ENV')
    @original_xdg_config_home ? ENV['XDG_CONFIG_HOME'] = @original_xdg_config_home : ENV.delete('XDG_CONFIG_HOME')
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_defaults_path_exists
    assert HTM::Loaders::DefaultsLoader.defaults_exist?
    assert File.exist?(HTM::Loaders::DefaultsLoader.defaults_path)
  end

  def test_schema_returns_defaults_section
    schema = HTM::Loaders::DefaultsLoader.schema
    assert_instance_of Hash, schema
    # Schema should contain nested section keys
    assert schema.key?(:database)
    assert schema.key?(:embedding)
    assert schema.key?(:job)
    # Check nested values
    assert_equal 'localhost', schema[:database][:host]
    assert_equal 'ollama', schema[:embedding][:provider]
  end

  def test_schema_does_not_include_environment_keys
    schema = HTM::Loaders::DefaultsLoader.schema
    refute schema.key?(:defaults)
    refute schema.key?(:development)
    refute schema.key?(:test)
    refute schema.key?(:production)
  end

  def test_loader_merges_defaults_with_development_overrides
    ENV.delete('HTM_ENV')
    ENV.delete('RAILS_ENV')
    ENV['RACK_ENV'] = 'development'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Should get development database.name override
    assert_equal 'htm_development', result[:database][:name]
    # Should get development log_level override
    assert_equal 'debug', result[:log_level]
    # Should still have base defaults
    assert_equal 'localhost', result[:database][:host]
    # Raw loader returns strings; type coercion happens at Config level
    assert_equal 'ollama', result[:embedding][:provider]
  end

  def test_loader_merges_defaults_with_test_overrides
    ENV['HTM_ENV'] = 'test'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Should get test database.name override
    assert_equal 'htm_test', result[:database][:name]
    # Should get test job.backend override
    assert_equal 'inline', result[:job][:backend]
    # Should get test log_level override
    assert_equal 'warn', result[:log_level]
    # Should still have base defaults
    assert_equal 'localhost', result[:database][:host]
  end

  def test_loader_merges_defaults_with_production_overrides
    ENV['HTM_ENV'] = 'production'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Should get production database.pool_size override
    assert_equal 25, result[:database][:pool_size]
    # Should get production database.sslmode override
    assert_equal 'require', result[:database][:sslmode]
    # Should get production log_level override
    assert_equal 'warn', result[:log_level]
    # Should get production telemetry_enabled override
    assert_equal true, result[:telemetry_enabled]
    # Should still have base defaults
    assert_equal 'localhost', result[:database][:host]
  end

  def test_loader_uses_base_defaults_for_unknown_environment
    ENV['HTM_ENV'] = 'staging'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # Should get base defaults (no staging section in defaults.yml)
    assert_nil result[:database][:name]
    assert_equal 10, result[:database][:pool_size]
    assert_equal 'info', result[:log_level]
  end

  def test_environment_priority_htm_env_over_rails_env
    ENV['HTM_ENV'] = 'production'
    ENV['RAILS_ENV'] = 'development'
    ENV['RACK_ENV'] = 'test'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # HTM_ENV takes priority, so should get production overrides
    assert_equal 25, result[:database][:pool_size]
    assert_equal 'warn', result[:log_level]
  end

  def test_environment_priority_rails_env_over_rack_env
    ENV.delete('HTM_ENV')
    ENV['RAILS_ENV'] = 'production'
    ENV['RACK_ENV'] = 'development'

    loader = HTM::Loaders::DefaultsLoader.new(local: false)
    result = loader.call(name: 'htm')

    # RAILS_ENV takes priority, so should get production overrides
    assert_equal 25, result[:database][:pool_size]
    assert_equal 'warn', result[:log_level]
  end

  def test_config_loads_environment_aware_defaults
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new

    # Test environment should have inline job_backend
    assert_equal :inline, config.job_backend
    # Test environment should have htm_test database.name (but can be overridden by HTM_DATABASE__URL)
    # Note: db_name may be parsed from HTM_DATABASE__URL if set
  end

  # Environment validation tests

  def test_valid_environments_returns_top_level_keys_excluding_defaults
    envs = HTM::Loaders::DefaultsLoader.valid_environments

    assert_instance_of Array, envs
    assert_includes envs, :development
    assert_includes envs, :test
    assert_includes envs, :production
    refute_includes envs, :defaults
  end

  def test_valid_environments_are_sorted
    envs = HTM::Loaders::DefaultsLoader.valid_environments

    assert_equal envs.sort, envs
  end

  def test_valid_environment_with_valid_environments
    assert HTM::Loaders::DefaultsLoader.valid_environment?(:development)
    assert HTM::Loaders::DefaultsLoader.valid_environment?(:test)
    assert HTM::Loaders::DefaultsLoader.valid_environment?(:production)
    assert HTM::Loaders::DefaultsLoader.valid_environment?('development')
    assert HTM::Loaders::DefaultsLoader.valid_environment?('test')
    assert HTM::Loaders::DefaultsLoader.valid_environment?('production')
  end

  def test_valid_environment_with_defaults_is_invalid
    refute HTM::Loaders::DefaultsLoader.valid_environment?(:defaults)
    refute HTM::Loaders::DefaultsLoader.valid_environment?('defaults')
  end

  def test_valid_environment_with_unknown_environment
    refute HTM::Loaders::DefaultsLoader.valid_environment?(:staging)
    refute HTM::Loaders::DefaultsLoader.valid_environment?('staging')
    refute HTM::Loaders::DefaultsLoader.valid_environment?(:staginr)
    refute HTM::Loaders::DefaultsLoader.valid_environment?('unknown')
  end

  def test_valid_environment_with_nil_or_empty
    refute HTM::Loaders::DefaultsLoader.valid_environment?(nil)
    refute HTM::Loaders::DefaultsLoader.valid_environment?('')
  end
end
