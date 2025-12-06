# Class: HTM
**Inherits:** Object
    

examples/robot_groups/lib/htm/working_memory_channel.rb frozen_string_literal:
true


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

## extract_propositions(text ) {: #method-c-extract_propositions }
Extract propositions using PropositionService
**`@param`** [String] Text to analyze

**`@return`** [Array<String>] Extracted atomic propositions

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


