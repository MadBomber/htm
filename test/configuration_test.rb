# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_config = HTM.config
    HTM.reset_configuration!
  end

  def teardown
    HTM.instance_variable_set(:@config, @original_config)
  end

  def test_default_values
    # Temporarily clear HTM env vars to test actual defaults from defaults.yml
    saved_env = ENV.to_h.select { |k, _| k.start_with?('HTM_') }
    saved_env.each_key { |k| ENV.delete(k) }

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
    # Temporarily clear database URL env var so component-based URL building works
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new
    config.database.host = 'dbhost'
    config.database.port = 5433
    config.database.name = 'mydb'
    config.database.user = 'myuser'
    config.database.password = 'mypass'

    expected_url = 'postgresql://myuser:mypass@dbhost:5433/mydb'
    assert_equal expected_url, config.database_url
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_url_takes_precedence
    config = HTM::Config.new
    config.database.url = 'postgresql://override@host:5432/override_db'
    config.database.host = 'other_host'
    config.database.name = 'other_db'

    assert_equal 'postgresql://override@host:5432/override_db', config.database_url
  end

  def test_database_configured
    # Temporarily clear database URL env var to test component-based configuration
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new

    # Clear environment-specific database.name to test unconfigured state
    config.database.name = nil
    refute config.database_configured?

    # With database.name set
    config.database.name = 'test_db'
    assert config.database_configured?
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
  end

  def test_database_config_hash
    # Temporarily clear database URL env var so component-based config is used
    saved_dburl = ENV['HTM_DATABASE__URL']
    ENV.delete('HTM_DATABASE__URL')

    config = HTM::Config.new
    config.database.host = 'localhost'
    config.database.port = 5432
    config.database.name = 'test_db'
    config.database.user = 'test_user'
    config.database.pool_size = 5
    config.database.timeout = 3000

    db_config = config.database_config

    assert_equal 'postgresql', db_config[:adapter]
    assert_equal 'localhost', db_config[:host]
    assert_equal 5432, db_config[:port]
    assert_equal 'test_db', db_config[:database]
    assert_equal 'test_user', db_config[:username]
    assert_equal 5, db_config[:pool]
  ensure
    saved_dburl ? ENV['HTM_DATABASE__URL'] = saved_dburl : ENV.delete('HTM_DATABASE__URL')
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
end
