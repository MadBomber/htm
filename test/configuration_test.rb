# frozen_string_literal: true

require "test_helper"
require 'fileutils'
require 'tmpdir'

class ConfigurationTest < Minitest::Test
  def setup
    @original_config = HTM.config
    HTM.reset_configuration!
  end

  def teardown
    HTM.instance_variable_set(:@config, @original_config)
  end

  def test_default_values
    # Temporarily clear HTM env vars and isolate from user XDG config
    saved_env = ENV.to_h.select { |k, _| k.start_with?('HTM_') }
    saved_env.each_key { |k| ENV.delete(k) }
    saved_xdg = ENV['XDG_CONFIG_HOME']
    temp_dir = Dir.mktmpdir('htm_config_test')
    ENV['XDG_CONFIG_HOME'] = temp_dir

    begin
      config = HTM::Config.new

      assert_equal :ollama, config.embedding_provider
      assert_equal 'nomic-embed-text:latest', config.embedding_model
      assert_equal 768, config.embedding_dimensions
      assert_equal :ollama, config.tag_provider
      assert_equal 'gemma3:latest', config.tag_model
      assert_equal 120, config.embedding_timeout
      assert_equal 180, config.tag_timeout
      assert_equal 60, config.connection_timeout
      assert_equal :sunday, config.week_start
    ensure
      # Restore env vars
      saved_env.each { |k, v| ENV[k] = v }
      saved_xdg ? ENV['XDG_CONFIG_HOME'] = saved_xdg : ENV.delete('XDG_CONFIG_HOME')
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  def test_configure_block
    HTM.configure do |config|
      config.embedding.provider = :openai
      config.embedding.model = 'text-embedding-3-small'
      config.embedding.dimensions = 1536
    end

    assert_equal :openai, HTM.config.embedding_provider
    assert_equal 'text-embedding-3-small', HTM.config.embedding_model
    assert_equal 1536, HTM.config.embedding_dimensions
  end

  def test_validate_embedding_generator
    config = HTM::Config.new
    config.embedding_generator = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_tag_extractor
    config = HTM::Config.new
    config.embedding_generator = ->(text) { [0.1, 0.2] }
    config.tag_extractor = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_token_counter
    config = HTM::Config.new
    config.embedding_generator = ->(text) { [0.1, 0.2] }
    config.tag_extractor = ->(text, ont) { [] }
    config.token_counter = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_logger
    config = HTM::Config.new
    config.logger = "not a logger"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_job_backend
    config = HTM::Config.new
    config.job.backend = :unknown_backend

    assert_raises(Anyway::Config::ValidationError) do
      config.validate_settings!
    end
  end

  def test_validate_week_start
    config = HTM::Config.new
    config.week_start = :wednesday

    assert_raises(Anyway::Config::ValidationError) do
      config.validate_settings!
    end
  end

  def test_validate_embedding_provider
    config = HTM::Config.new
    config.embedding.provider = :unsupported_provider

    assert_raises(Anyway::Config::ValidationError) do
      config.validate_settings!
    end
  end

  def test_validate_tag_provider
    config = HTM::Config.new
    config.tag.provider = :unsupported_provider

    assert_raises(Anyway::Config::ValidationError) do
      config.validate_settings!
    end
  end

  def test_supported_providers
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :openai
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :anthropic
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :gemini
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :azure
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :ollama
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :huggingface
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :openrouter
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :bedrock
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :deepseek
  end

  def test_default_dimensions_by_provider
    assert_equal 1536, HTM::Config::DEFAULT_DIMENSIONS[:openai]
    assert_equal 768, HTM::Config::DEFAULT_DIMENSIONS[:ollama]
    assert_equal 768, HTM::Config::DEFAULT_DIMENSIONS[:gemini]
  end

  def test_normalize_ollama_model
    config = HTM::Config.new

    assert_equal 'llama3:latest', config.normalize_ollama_model('llama3')
    assert_equal 'llama3:7b', config.normalize_ollama_model('llama3:7b')
    assert_equal 'nomic-embed-text:latest', config.normalize_ollama_model('nomic-embed-text')
  end

  def test_normalize_ollama_model_with_nil
    config = HTM::Config.new

    assert_nil config.normalize_ollama_model(nil)
    assert_equal '', config.normalize_ollama_model('')
  end

  def test_reset_to_defaults
    config = HTM::Config.new

    config.embedding_generator = ->(text) { [0.0] }
    config.reset_to_defaults

    assert_respond_to config.embedding_generator, :call
  end

  def test_count_tokens
    HTM.configure do |config|
      config.token_counter = ->(text) { text.split.size }
    end

    assert_equal 4, HTM.count_tokens("this is a test")
  end

  def test_count_tokens_error
    HTM.configure do |config|
      config.token_counter = ->(text) { raise "boom" }
    end

    assert_raises(HTM::ValidationError) do
      HTM.count_tokens("test")
    end
  end

  def test_logger_default
    config = HTM::Config.new
    logger = config.logger

    assert_respond_to logger, :info
    assert_respond_to logger, :warn
    assert_respond_to logger, :error
  end

  def test_valid_job_backends
    %i[active_job sidekiq inline thread].each do |backend|
      config = HTM::Config.new
      config.job.backend = backend
      # Should not raise
      assert_equal backend, config.job_backend
    end
  end

  def test_configuration_alias
    # Test that HTM.configuration is aliased to HTM.config
    assert_equal HTM.config.object_id, HTM.configuration.object_id
  end

  def test_environment_helpers
    config = HTM::Config.new
    assert_respond_to config, :test?
    assert_respond_to config, :development?
    assert_respond_to config, :production?
    assert_respond_to config, :environment
  end

  def test_database_url_from_components
    # Test that URL is built from components at load time when no URL is set.
    # Set component env vars BEFORE creating config (reconciliation happens at load).
    saved_vars = {}
    %w[HTM_DATABASE__URL HTM_DATABASE__HOST HTM_DATABASE__PORT HTM_DATABASE__NAME
       HTM_DATABASE__USER HTM_DATABASE__PASSWORD HTM_DATABASE__SSLMODE].each do |var|
      saved_vars[var] = ENV[var]
    end

    ENV.delete('HTM_DATABASE__URL')
    ENV['HTM_DATABASE__HOST'] = 'dbhost'
    ENV['HTM_DATABASE__PORT'] = '5433'
    ENV['HTM_DATABASE__NAME'] = 'mydb'
    ENV['HTM_DATABASE__USER'] = 'myuser'
    ENV['HTM_DATABASE__PASSWORD'] = 'mypass'
    ENV['HTM_DATABASE__SSLMODE'] = 'require'

    config = HTM::Config.new

    expected_url = 'postgresql://myuser:mypass@dbhost:5433/mydb?sslmode=require'
    assert_equal expected_url, config.database_url
  ensure
    saved_vars.each do |var, val|
      val ? ENV[var] = val : ENV.delete(var)
    end
  end

  def test_database_url_takes_precedence
    config = HTM::Config.new
    config.database.url = 'postgresql://override@host:5432/override_db'
    config.database.host = 'other_host'
    config.database.name = 'other_db'

    assert_equal 'postgresql://override@host:5432/override_db', config.database_url
  end

  def test_database_configured
    # Test database_configured? reflects state after reconciliation.
    # With a URL set, database is configured.
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://user@localhost:5432/testdb'

    config = HTM::Config.new
    assert config.database_configured?
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_not_configured_when_empty
    # Test that database_configured? returns false when no database config.
    # Must clear ALL database-related env vars to get unconfigured state.
    saved_vars = {}
    %w[HTM_DATABASE__URL HTM_DATABASE__HOST HTM_DATABASE__PORT HTM_DATABASE__NAME
       HTM_DATABASE__USER HTM_DATABASE__PASSWORD].each do |var|
      saved_vars[var] = ENV[var]
      ENV.delete(var)
    end

    config = HTM::Config.new

    # After clearing env vars, defaults.yml still sets database.name per environment.
    # With name set, reconciliation builds a URL, so database is configured.
    # To truly test unconfigured state, we need to clear the name after load.
    config.database.name = nil
    config.database.url = nil
    refute config.database_configured?
  ensure
    saved_vars.each do |var, val|
      val ? ENV[var] = val : ENV.delete(var)
    end
  end

  def test_database_config_hash
    # Test that database_config hash reflects component values.
    # Set component env vars BEFORE creating config (reconciliation happens at load).
    saved_vars = {}
    %w[HTM_DATABASE__URL HTM_DATABASE__HOST HTM_DATABASE__PORT HTM_DATABASE__NAME
       HTM_DATABASE__USER HTM_DATABASE__PASSWORD HTM_DATABASE__POOL_SIZE].each do |var|
      saved_vars[var] = ENV[var]
    end

    ENV.delete('HTM_DATABASE__URL')
    ENV['HTM_DATABASE__HOST'] = 'localhost'
    ENV['HTM_DATABASE__PORT'] = '5432'
    ENV['HTM_DATABASE__NAME'] = 'test_db'
    ENV['HTM_DATABASE__USER'] = 'test_user'
    ENV['HTM_DATABASE__POOL_SIZE'] = '5'

    config = HTM::Config.new
    db_config = config.database_config

    assert_equal 'postgresql', db_config[:adapter]
    assert_equal 'localhost', db_config[:host]
    assert_equal 5432, db_config[:port]
    assert_equal 'test_db', db_config[:database]
    assert_equal 'test_user', db_config[:username]
    assert_equal 5, db_config[:pool]
  ensure
    saved_vars.each do |var, val|
      val ? ENV[var] = val : ENV.delete(var)
    end
  end

  # Environment validation tests

  def test_class_valid_environments
    envs = HTM::Config.valid_environments

    assert_instance_of Array, envs
    assert_includes envs, :development
    assert_includes envs, :test
    assert_includes envs, :production
    refute_includes envs, :defaults
  end

  def test_class_valid_environment_with_valid_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'test'

    assert HTM::Config.valid_environment?
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_class_valid_environment_with_invalid_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'staginr'

    refute HTM::Config.valid_environment?
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_class_valid_environment_with_defaults_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'defaults'

    refute HTM::Config.valid_environment?
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_class_validate_environment_raises_for_invalid_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'staginr'

    error = assert_raises(HTM::ConfigurationError) do
      HTM::Config.validate_environment!
    end

    assert_match(/Invalid environment 'staginr'/, error.message)
    assert_match(/Valid environments are:/, error.message)
    assert_match(/development/, error.message)
    assert_match(/test/, error.message)
    assert_match(/production/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_class_validate_environment_raises_for_defaults_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'defaults'

    error = assert_raises(HTM::ConfigurationError) do
      HTM::Config.validate_environment!
    end

    assert_match(/Invalid environment 'defaults'/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_class_validate_environment_succeeds_for_valid_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'test'

    # Should not raise
    assert HTM::Config.validate_environment!
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_instance_validate_database_raises_for_invalid_env
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'staginr'

    config = HTM::Config.new

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_database!
    end

    assert_match(/Invalid environment 'staginr'/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_instance_validate_database_raises_when_database_not_configured
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']

    ENV['HTM_ENV'] = 'test'
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new
    config.database.url = nil
    config.database.name = nil

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_database!
    end

    assert_match(/No database configured/, error.message)
    assert_match(/environment 'test'/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_instance_validate_database_succeeds_when_properly_configured
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.name = 'test_db'

    # Should not raise
    assert config.validate_database!
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_instance_validate_environment
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new

    # Should not raise
    assert config.validate_environment!
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_instance_validate_environment_raises_for_invalid
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'invalid_env'

    config = HTM::Config.new

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_environment!
    end

    assert_match(/Invalid environment 'invalid_env'/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  # ==========================================================================
  # Database Naming Convention Tests
  # ==========================================================================

  def test_expected_database_name
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    # Default service.name is 'htm' from defaults.yml
    assert_equal 'htm_test', config.expected_database_name

    ENV['HTM_ENV'] = 'development'
    config = HTM::Config.new
    assert_equal 'htm_development', config.expected_database_name

    ENV['HTM_ENV'] = 'production'
    config = HTM::Config.new
    assert_equal 'htm_production', config.expected_database_name
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_expected_database_name_with_custom_service
    saved_htm_env = ENV['HTM_ENV']
    ENV['HTM_ENV'] = 'production'

    config = HTM::Config.new
    config.service.name = 'payroll'

    assert_equal 'payroll_production', config.expected_database_name
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
  end

  def test_actual_database_name_from_url
    saved_dburl = ENV['HTM_DATABASE__URL']

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/myapp_test'

    assert_equal 'myapp_test', config.actual_database_name
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_actual_database_name_from_config
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new
    config.database.url = nil
    config.database.name = 'myapp_development'

    assert_equal 'myapp_development', config.actual_database_name
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_actual_database_name_url_takes_precedence
    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/from_url'
    config.database.name = 'from_config'

    assert_equal 'from_url', config.actual_database_name
  end

  def test_valid_database_name_when_matching
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/htm_test'

    assert config.valid_database_name?
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_valid_database_name_when_not_matching
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/htm_production'

    refute config.valid_database_name?
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_validate_database_name_succeeds_when_matching
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/htm_test'

    # Should not raise
    assert config.validate_database_name!
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_validate_database_name_raises_when_environment_wrong
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/htm_production'

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_database_name!
    end

    assert_match(/does not match expected/, error.message)
    assert_match(/htm_production/, error.message)
    assert_match(/htm_test/, error.message)
    assert_match(/Service name: htm/, error.message)
    assert_match(/Environment:  test/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_validate_database_name_raises_when_service_wrong
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'production'

    config = HTM::Config.new
    # Default service.name is 'htm'
    config.database.url = 'postgresql://user@localhost:5432/payroll_production'

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_database_name!
    end

    assert_match(/does not match expected/, error.message)
    assert_match(/payroll_production/, error.message)
    assert_match(/htm_production/, error.message)
    assert_match(/Service name: htm/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_validate_database_name_raises_when_format_wrong
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'test'

    config = HTM::Config.new
    config.database.url = 'postgresql://user@localhost:5432/random_database'

    error = assert_raises(HTM::ConfigurationError) do
      config.validate_database_name!
    end

    assert_match(/does not match expected/, error.message)
    assert_match(/random_database/, error.message)
    assert_match(/htm_test/, error.message)
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_validate_database_name_custom_service_and_env
    saved_htm_env = ENV['HTM_ENV']
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_ENV'] = 'production'

    config = HTM::Config.new
    config.service.name = 'payroll'
    config.database.url = 'postgresql://user@localhost:5432/payroll_production'

    # Should not raise - custom service name with matching database
    assert config.validate_database_name!
  ensure
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  # ==========================================================================
  # Database URL/Components Consistency Tests
  # ==========================================================================

  def test_parse_database_url
    config = HTM::Config.new
    config.database.url = 'postgresql://myuser:mypass@dbhost:5433/mydb'

    parsed = config.parse_database_url

    assert_equal 'dbhost', parsed[:host]
    assert_equal 5433, parsed[:port]
    assert_equal 'mydb', parsed[:name]
    assert_equal 'myuser', parsed[:user]
    assert_equal 'mypass', parsed[:password]
  end

  def test_parse_database_url_without_password
    config = HTM::Config.new
    config.database.url = 'postgresql://myuser@dbhost:5432/mydb'

    parsed = config.parse_database_url

    assert_equal 'dbhost', parsed[:host]
    assert_equal 'myuser', parsed[:user]
    refute parsed.key?(:password)
  end

  def test_parse_database_url_returns_nil_when_no_url
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new
    config.database.url = nil

    assert_nil config.parse_database_url
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_parse_database_url_with_sslmode
    config = HTM::Config.new
    config.database.url = 'postgresql://myuser@dbhost:5432/mydb?sslmode=require'

    parsed = config.parse_database_url

    assert_equal 'dbhost', parsed[:host]
    assert_equal 5432, parsed[:port]
    assert_equal 'mydb', parsed[:name]
    assert_equal 'myuser', parsed[:user]
    assert_equal 'require', parsed[:sslmode]
  end

  def test_build_database_url_includes_sslmode
    saved_vars = {}
    %w[HTM_DATABASE__URL HTM_DATABASE__HOST HTM_DATABASE__PORT HTM_DATABASE__NAME
       HTM_DATABASE__USER HTM_DATABASE__SSLMODE].each do |var|
      saved_vars[var] = ENV[var]
    end

    ENV.delete('HTM_DATABASE__URL')
    ENV['HTM_DATABASE__HOST'] = 'dbhost'
    ENV['HTM_DATABASE__PORT'] = '5432'
    ENV['HTM_DATABASE__NAME'] = 'mydb'
    ENV['HTM_DATABASE__USER'] = 'myuser'
    ENV['HTM_DATABASE__SSLMODE'] = 'require'

    config = HTM::Config.new

    assert_equal 'postgresql://myuser@dbhost:5432/mydb?sslmode=require', config.database.url
  ensure
    saved_vars.each do |var, val|
      val ? ENV[var] = val : ENV.delete(var)
    end
  end

  def test_reconciliation_extracts_sslmode_from_url
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://testuser@testhost:5432/testdb?sslmode=verify-full'

    config = HTM::Config.new

    assert_equal 'verify-full', config.database.sslmode
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  # ==========================================================================
  # Database Configuration Reconciliation
  # ==========================================================================
  #
  # Reconciliation happens at config load time:
  # - If URL exists: all components are populated from the URL
  # - If no URL but components exist: URL is built from components
  #

  def test_reconciliation_populates_components_from_url_at_load_time
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://testuser:testpass@testhost:5433/testdb'

    config = HTM::Config.new

    # Components should be populated from URL at load time
    assert_equal 'testhost', config.database.host
    assert_equal 5433, config.database.port
    assert_equal 'testdb', config.database.name
    assert_equal 'testuser', config.database.user
    assert_equal 'testpass', config.database.password
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_reconciliation_builds_url_from_components_when_no_url
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')
    saved_name = ENV['HTM_DATABASE__NAME']
    saved_user = ENV['HTM_DATABASE__USER']

    ENV['HTM_DATABASE__NAME'] = 'component_db'
    ENV['HTM_DATABASE__USER'] = 'component_user'

    config = HTM::Config.new

    # URL should be built from components at load time (sslmode=prefer is the default)
    assert_equal 'postgresql://component_user@localhost:5432/component_db?sslmode=prefer', config.database.url
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
    saved_name ? ENV['HTM_DATABASE__NAME'] = saved_name : ENV.delete('HTM_DATABASE__NAME')
    saved_user ? ENV['HTM_DATABASE__USER'] = saved_user : ENV.delete('HTM_DATABASE__USER')
  end

  def test_reconciliation_uses_defaults_for_host_and_port_when_building_url
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')
    saved_name = ENV['HTM_DATABASE__NAME']

    ENV['HTM_DATABASE__NAME'] = 'mydb'

    config = HTM::Config.new

    # Should use localhost:5432 defaults
    assert_equal 'localhost', config.database.host
    assert_equal 5432, config.database.port
    assert_match(%r{localhost:5432/mydb}, config.database.url)
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
    saved_name ? ENV['HTM_DATABASE__NAME'] = saved_name : ENV.delete('HTM_DATABASE__NAME')
  end

  def test_reconciliation_auto_generates_database_name_from_service_and_environment
    # When database.name is missing but other components exist,
    # auto-generate name from service.name and environment
    saved_vars = {}
    %w[HTM_DATABASE__URL HTM_DATABASE__NAME HTM_DATABASE__USER HTM_ENV HTM_SERVICE__NAME].each do |var|
      saved_vars[var] = ENV[var]
    end

    ENV.delete('HTM_DATABASE__URL')
    ENV.delete('HTM_DATABASE__NAME')
    ENV['HTM_DATABASE__USER'] = 'testuser'  # This triggers reconciliation
    ENV['HTM_ENV'] = 'test'
    ENV['HTM_SERVICE__NAME'] = 'myapp'

    config = HTM::Config.new

    # Name should be auto-generated as {service_name}_{environment}
    assert_equal 'myapp_test', config.database.name
    assert_match(%r{/myapp_test}, config.database.url)
  ensure
    saved_vars.each do |var, val|
      val ? ENV[var] = val : ENV.delete(var)
    end
  end

  # ==========================================================================
  # Database Component Accessors
  # ==========================================================================
  #
  # These are simple accessors that return the component values.
  # Reconciliation has already happened at load time.
  #

  def test_database_host_returns_component_value
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://user@myhost:5432/mydb'

    config = HTM::Config.new

    assert_equal 'myhost', config.database_host
    assert_equal config.database.host, config.database_host
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_port_returns_component_value
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://user@localhost:5433/mydb'

    config = HTM::Config.new

    assert_equal 5433, config.database_port
    assert_equal config.database.port, config.database_port
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_name_returns_component_value
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://user@localhost:5432/extracted_db'

    config = HTM::Config.new

    assert_equal 'extracted_db', config.database_name
    assert_equal config.database.name, config.database_name
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_user_returns_component_value
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://dbuser@localhost:5432/mydb'

    config = HTM::Config.new

    assert_equal 'dbuser', config.database_user
    assert_equal config.database.user, config.database_user
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_password_returns_component_value
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV['HTM_DATABASE__URL'] = 'postgresql://user:secret123@localhost:5432/mydb'

    config = HTM::Config.new

    assert_equal 'secret123', config.database_password
    assert_equal config.database.password, config.database_password
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end
end
