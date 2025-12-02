# Class: HTM
**Inherits:** Object
    

HTM (Hierarchical Temporary Memory) error classes

All HTM errors inherit from HTM::Error, allowing you to catch all HTM-related
errors with a single rescue clause.


**`@example`**
```ruby
begin
  htm.remember("some content")
rescue HTM::Error => e
  logger.error "HTM error: #{e.message}"
end
```
**`@example`**
```ruby
begin
  htm.forget(node_id, soft: false)
rescue HTM::NotFoundError
  puts "Node not found"
rescue HTM::ValidationError
  puts "Invalid input"
end
```
# Class Methods
## configure() {: #method-c-configure }
Configure HTM
**`@yield`** [config] Configuration object

**`@yieldparam`** [HTM::Configuration] 


**`@example`**
```ruby
HTM.configure do |config|
  config.embedding_generator = ->(text) { MyEmbedder.embed(text) }
  config.tag_extractor = ->(text, ontology) { MyTagger.extract(text, ontology) }
end
```
**`@example`**
```ruby
HTM.configure  # Uses RubyLLM defaults
```
## count_tokens(text ) {: #method-c-count_tokens }
Count tokens using configured counter
**`@param`** [String] Text to count tokens for

**`@return`** [Integer] Token count

## embed(text ) {: #method-c-embed }
Generate embedding using EmbeddingService
**`@param`** [String] Text to embed

**`@return`** [Array<Float>] Embedding vector (original, not padded)

## extract_tags(text , existing_ontology: []) {: #method-c-extract_tags }
Extract tags using TagService
**`@param`** [String] Text to analyze

**`@param`** [Array<String>] Sample of existing tags for context

**`@return`** [Array<String>] Extracted and validated tag names

## logger() {: #method-c-logger }
Get configured logger
**`@return`** [Logger] Configured logger instance

## reset_configuration!() {: #method-c-reset_configuration! }
Reset configuration to defaults
# Attributes
## configuration[RW] {: #attribute-c-configuration }
Get current configuration

**`@return`** [HTM::Configuration] 


