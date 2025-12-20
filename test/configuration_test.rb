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
    config = HTM::Config.new

    assert_equal :ollama, config.embedding_provider
    assert_equal 'nomic-embed-text:latest', config.embedding_model
    assert_equal 768, config.embedding_dimensions
    assert_equal :ollama, config.tag_provider
    assert_equal 'gemma3:latest', config.tag_model
    assert_equal 120, config.embedding_timeout
    assert_equal 180, config.tag_timeout
    assert_equal 30, config.connection_timeout
    assert_equal :sunday, config.week_start
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
    # Temporarily clear HTM_DBURL so component-based URL building works
    saved_dburl = ENV['HTM_DBURL']
    ENV.delete('HTM_DBURL')

    config = HTM::Config.new
    config.database.host = 'dbhost'
    config.database.port = 5433
    config.database.name = 'mydb'
    config.database.user = 'myuser'
    config.database.password = 'mypass'

    expected_url = 'postgresql://myuser:mypass@dbhost:5433/mydb'
    assert_equal expected_url, config.database_url
  ensure
    saved_dburl ? ENV['HTM_DBURL'] = saved_dburl : ENV.delete('HTM_DBURL')
  end

  def test_database_url_takes_precedence
    config = HTM::Config.new
    config.database.url = 'postgresql://override@host:5432/override_db'
    config.database.host = 'other_host'
    config.database.name = 'other_db'

    assert_equal 'postgresql://override@host:5432/override_db', config.database_url
  end

  def test_database_configured
    # Temporarily clear HTM_DBURL to test component-based configuration
    saved_dburl = ENV['HTM_DBURL']
    ENV.delete('HTM_DBURL')

    config = HTM::Config.new

    # Clear environment-specific database.name to test unconfigured state
    config.database.name = nil
    refute config.database_configured?

    # With database.name set
    config.database.name = 'test_db'
    assert config.database_configured?
  ensure
    saved_dburl ? ENV['HTM_DBURL'] = saved_dburl : ENV.delete('HTM_DBURL')
  end

  def test_database_config_hash
    # Temporarily clear HTM_DBURL so component-based config is used
    saved_dburl = ENV['HTM_DBURL']
    ENV.delete('HTM_DBURL')

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
    saved_dburl ? ENV['HTM_DBURL'] = saved_dburl : ENV.delete('HTM_DBURL')
  end
end
