# Class: HTM::Configuration
**Inherits:** Object
    

HTM Configuration

HTM uses RubyLLM for multi-provider LLM support. Supported providers:
*   :openai (OpenAI API)
*   :anthropic (Anthropic Claude)
*   :gemini (Google Gemini)
*   :azure (Azure OpenAI)
*   :ollama (Local Ollama - default)
*   :huggingface (HuggingFace Inference API)
*   :openrouter (OpenRouter)
*   :bedrock (AWS Bedrock)
*   :deepseek (DeepSeek)


**@example**
```ruby
HTM.configure do |config|
  config.embedding_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  config.tag_provider = :openai
  config.tag_model = 'gpt-4o-mini'
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```
**@example**
```ruby
HTM.configure do |config|
  config.embedding_provider = :ollama
  config.embedding_model = 'nomic-embed-text'
  config.tag_provider = :ollama
  config.tag_model = 'llama3'
  config.ollama_url = 'http://localhost:11434'
end
```
**@example**
```ruby
HTM.configure do |config|
  config.embedding_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.tag_provider = :anthropic
  config.tag_model = 'claude-3-haiku-20240307'
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end
```
**@example**
```ruby
HTM.configure do |config|
  config.embedding_generator = ->(text) {
    MyApp::LLMService.embed(text)  # Returns Array<Float>
  }
  config.tag_extractor = ->(text, ontology) {
    MyApp::LLMService.extract_tags(text, ontology)  # Returns Array<String>
  }
  config.logger = Rails.logger
end
```
# Attributes
## anthropic_api_key[RW] [](#attribute-i-anthropic_api_key)
Returns the value of attribute anthropic_api_key.

## azure_api_key[RW] [](#attribute-i-azure_api_key)
Returns the value of attribute azure_api_key.

## azure_api_version[RW] [](#attribute-i-azure_api_version)
Returns the value of attribute azure_api_version.

## azure_endpoint[RW] [](#attribute-i-azure_endpoint)
Returns the value of attribute azure_endpoint.

## bedrock_access_key[RW] [](#attribute-i-bedrock_access_key)
Returns the value of attribute bedrock_access_key.

## bedrock_region[RW] [](#attribute-i-bedrock_region)
Returns the value of attribute bedrock_region.

## bedrock_secret_key[RW] [](#attribute-i-bedrock_secret_key)
Returns the value of attribute bedrock_secret_key.

## connection_timeout[RW] [](#attribute-i-connection_timeout)
Returns the value of attribute connection_timeout.

## deepseek_api_key[RW] [](#attribute-i-deepseek_api_key)
Returns the value of attribute deepseek_api_key.

## embedding_dimensions[RW] [](#attribute-i-embedding_dimensions)
Returns the value of attribute embedding_dimensions.

## embedding_generator[RW] [](#attribute-i-embedding_generator)
Returns the value of attribute embedding_generator.

## embedding_model[RW] [](#attribute-i-embedding_model)
Returns the value of attribute embedding_model.

## embedding_provider[RW] [](#attribute-i-embedding_provider)
Returns the value of attribute embedding_provider.

## embedding_timeout[RW] [](#attribute-i-embedding_timeout)
Returns the value of attribute embedding_timeout.

## gemini_api_key[RW] [](#attribute-i-gemini_api_key)
Returns the value of attribute gemini_api_key.

## huggingface_api_key[RW] [](#attribute-i-huggingface_api_key)
Returns the value of attribute huggingface_api_key.

## job_backend[RW] [](#attribute-i-job_backend)
Returns the value of attribute job_backend.

## logger[RW] [](#attribute-i-logger)
Returns the value of attribute logger.

## ollama_url[RW] [](#attribute-i-ollama_url)
Returns the value of attribute ollama_url.

## openai_api_key[RW] [](#attribute-i-openai_api_key)
Provider-specific API keys and endpoints

## openai_organization[RW] [](#attribute-i-openai_organization)
Provider-specific API keys and endpoints

## openai_project[RW] [](#attribute-i-openai_project)
Provider-specific API keys and endpoints

## openrouter_api_key[RW] [](#attribute-i-openrouter_api_key)
Returns the value of attribute openrouter_api_key.

## tag_extractor[RW] [](#attribute-i-tag_extractor)
Returns the value of attribute tag_extractor.

## tag_model[RW] [](#attribute-i-tag_model)
Returns the value of attribute tag_model.

## tag_provider[RW] [](#attribute-i-tag_provider)
Returns the value of attribute tag_provider.

## tag_timeout[RW] [](#attribute-i-tag_timeout)
Returns the value of attribute tag_timeout.

## token_counter[RW] [](#attribute-i-token_counter)
Returns the value of attribute token_counter.

## week_start[RW] [](#attribute-i-week_start)
Returns the value of attribute week_start.


# Instance Methods
## configure_ruby_llm(providernil) [](#method-i-configure_ruby_llm)
Configure RubyLLM with the appropriate provider credentials

**@param** [Symbol] The provider to configure (:openai, :anthropic, etc.)

## initialize() [](#method-i-initialize)

**@return** [Configuration] a new instance of Configuration

## normalize_ollama_model(model_name) [](#method-i-normalize_ollama_model)
Normalize Ollama model name to include tag if missing

Ollama models require a tag (e.g., :latest, :7b, :13b). If the user specifies
a model without a tag, we append :latest by default.

**@param** [String] Original model name

**@return** [String] Normalized model name with tag

## reset_to_defaults() [](#method-i-reset_to_defaults)
Reset to default RubyLLM-based implementations

## validate!() [](#method-i-validate!)
Validate configuration

