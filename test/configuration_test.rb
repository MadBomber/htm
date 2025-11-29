# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_config = HTM.configuration
    HTM.reset_configuration!
  end

  def teardown
    HTM.instance_variable_set(:@configuration, @original_config)
  end

  def test_default_values
    config = HTM::Configuration.new

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
      config.embedding_provider = :openai
      config.embedding_model = 'text-embedding-3-small'
      config.embedding_dimensions = 1536
    end

    assert_equal :openai, HTM.configuration.embedding_provider
    assert_equal 'text-embedding-3-small', HTM.configuration.embedding_model
    assert_equal 1536, HTM.configuration.embedding_dimensions
  end

  def test_validate_embedding_generator
    config = HTM::Configuration.new
    config.embedding_generator = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_tag_extractor
    config = HTM::Configuration.new
    config.embedding_generator = ->(text) { [0.1, 0.2] }
    config.tag_extractor = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_token_counter
    config = HTM::Configuration.new
    config.embedding_generator = ->(text) { [0.1, 0.2] }
    config.tag_extractor = ->(text, ont) { [] }
    config.token_counter = "not callable"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_logger
    config = HTM::Configuration.new
    config.logger = "not a logger"

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_job_backend
    config = HTM::Configuration.new
    config.job_backend = :unknown_backend

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_week_start
    config = HTM::Configuration.new
    config.week_start = :wednesday

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_embedding_provider
    config = HTM::Configuration.new
    config.embedding_provider = :unsupported_provider

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_validate_tag_provider
    config = HTM::Configuration.new
    config.tag_provider = :unsupported_provider

    assert_raises(HTM::ValidationError) do
      config.validate!
    end
  end

  def test_supported_providers
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :openai
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :anthropic
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :gemini
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :azure
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :ollama
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :huggingface
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :openrouter
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :bedrock
    assert_includes HTM::Configuration::SUPPORTED_PROVIDERS, :deepseek
  end

  def test_default_dimensions_by_provider
    assert_equal 1536, HTM::Configuration::DEFAULT_DIMENSIONS[:openai]
    assert_equal 768, HTM::Configuration::DEFAULT_DIMENSIONS[:ollama]
    assert_equal 768, HTM::Configuration::DEFAULT_DIMENSIONS[:gemini]
  end

  def test_normalize_ollama_model
    config = HTM::Configuration.new

    assert_equal 'llama3:latest', config.normalize_ollama_model('llama3')
    assert_equal 'llama3:7b', config.normalize_ollama_model('llama3:7b')
    assert_equal 'nomic-embed-text:latest', config.normalize_ollama_model('nomic-embed-text')
  end

  def test_normalize_ollama_model_with_nil
    config = HTM::Configuration.new

    assert_nil config.normalize_ollama_model(nil)
    assert_equal '', config.normalize_ollama_model('')
  end

  def test_reset_to_defaults
    config = HTM::Configuration.new
    original_generator = config.embedding_generator

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
    config = HTM::Configuration.new
    logger = config.logger

    assert_respond_to logger, :info
    assert_respond_to logger, :warn
    assert_respond_to logger, :error
  end

  def test_valid_job_backends
    %i[active_job sidekiq inline thread].each do |backend|
      config = HTM::Configuration.new
      config.job_backend = backend
      config.validate!  # Should not raise
    end
  end
end
