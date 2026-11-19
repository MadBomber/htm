# Class HTM <a id="class-HTM"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm.rb, lib/htm/config.rb, lib/htm/errors.rb, lib/htm/mcp/cli.rb, lib/htm/railtie.rb, lib/htm/version.rb, lib/htm/database.rb, lib/htm/mcp/tools.rb, lib/htm/migration.rb, lib/htm/telemetry.rb, lib/htm/timeframe.rb, lib/htm/mcp/server.rb, lib/htm/models/tag.rb, lib/htm/job_adapter.rb, lib/htm/models/node.rb, lib/htm/query_cache.rb, lib/htm/robot_group.rb, lib/htm/sql_builder.rb, lib/htm/tag_service.rb, lib/htm/models/robot.rb, lib/htm/mcp/resources.rb, lib/htm/observability.rb, lib/htm/sequel_config.rb, lib/htm/config/builder.rb, lib/htm/working_memory.rb, lib/htm/circuit_breaker.rb, lib/htm/config/database.rb, lib/htm/mcp/group_tools.rb, lib/htm/models/node_tag.rb, lib/htm/config/validator.rb, lib/htm/long_term_memory.rb, lib/htm/embedding_service.rb, lib/htm/models/robot_node.rb, lib/htm/models/file_source.rb, lib/htm/proposition_service.rb, lib/htm/timeframe_extractor.rb, lib/htm/integrations/sinatra.rb, lib/htm/jobs/generate_tags_job.rb, lib/htm/working_memory_channel.rb, lib/htm/loaders/markdown_loader.rb, lib/htm/loaders/markdown_chunker.rb, lib/htm/models/node_relationship.rb, lib/htm/jobs/generate_embedding_job.rb, lib/htm/workflows/remember_workflow.rb, lib/htm/jobs/generate_propositions_job.rb, lib/htm/long_term_memory/hybrid_search.rb, lib/htm/long_term_memory/vector_search.rb, lib/htm/jobs/generate_relationships_job.rb, lib/htm/long_term_memory/tag_operations.rb, lib/htm/long_term_memory/fulltext_search.rb, lib/htm/long_term_memory/node_operations.rb, lib/htm/long_term_memory/relevance_scorer.rb, lib/htm/long_term_memory/robot_operations.rb |

examples/robot_groups/lib/htm/working_memory_channel.rb frozen_string_literal:
true

## Constants
### `MAX_ARRAY_SIZE` <a id="constant-MAX_ARRAY_SIZE"></a> <a id="MAX_ARRAY_SIZE-constant"></a>
Not documented.

### `MAX_KEY_LENGTH` <a id="constant-MAX_KEY_LENGTH"></a> <a id="MAX_KEY_LENGTH-constant"></a>
Validation constants

### `MAX_VALUE_LENGTH` <a id="constant-MAX_VALUE_LENGTH"></a> <a id="MAX_VALUE_LENGTH-constant"></a>
1MB

### `VALID_RECALL_STRATEGIES` <a id="constant-VALID_RECALL_STRATEGIES"></a> <a id="VALID_RECALL_STRATEGIES-constant"></a>
Not documented.

### `VERSION` <a id="constant-VERSION"></a> <a id="VERSION-constant"></a>
Not documented.

## Attributes
### `long_term_memory` [R] <a id="attribute-i-long_term_memory"></a> <a id="long_term_memory-instance_method"></a>
Returns the value of attribute long_term_memory.

### `robot_id` [R] <a id="attribute-i-robot_id"></a> <a id="robot_id-instance_method"></a>
Returns the value of attribute robot_id.

### `robot_name` [R] <a id="attribute-i-robot_name"></a> <a id="robot_name-instance_method"></a>
Returns the value of attribute robot_name.

### `working_memory` [R] <a id="attribute-i-working_memory"></a> <a id="working_memory-instance_method"></a>
Returns the value of attribute working_memory.

## Public Class Methods
### `config()` <a id="method-c-config"></a> <a id="config-class_method"></a>
Get current configuration (singleton)
- **`@return`** [HTM::Config]

### `configure()` <a id="method-c-configure"></a> <a id="configure-class_method"></a>
Configure HTM
- **`@yield`** [config] Configuration object
- **`@yieldparam`** `config` [HTM::Config]

**@example Custom configuration**
```ruby
HTM.configure do |config|
  config.embedding_generator = ->(text) { MyEmbedder.embed(text) }
  config.tag_extractor = ->(text, ontology) { MyTagger.extract(text, ontology) }
end
```

**@example Default configuration**
```ruby
HTM.configure  # Uses RubyLLM defaults
```

### `count_tokens(text)` <a id="method-c-count_tokens"></a> <a id="count_tokens-class_method"></a>
Count tokens using configured counter
- **`@param`** `text` [String] Text to count tokens for
- **`@return`** [Integer] Token count

### `db()` <a id="method-c-db"></a> <a id="db-class_method"></a>
Convenience method to access the database connection
- **`@return`** [Sequel::Database]

### `development?()` <a id="method-c-development-3F"></a> <a id="development?-class_method"></a>
Check if running in development environment
- **`@return`** [Boolean]

### `embed(text)` <a id="method-c-embed"></a> <a id="embed-class_method"></a>
Generate embedding using EmbeddingService
- **`@param`** `text` [String] Text to embed
- **`@return`** [Array<Float>] Embedding vector (original, not padded)

### `env()` <a id="method-c-env"></a> <a id="env-class_method"></a>
Get current environment
- **`@return`** [String] Current environment name

### `extract_propositions(text)` <a id="method-c-extract_propositions"></a> <a id="extract_propositions-class_method"></a>
Extract propositions using PropositionService
- **`@param`** `text` [String] Text to analyze
- **`@return`** [Array<String>] Extracted atomic propositions

### `extract_tags(text, existing_ontology: [])` <a id="method-c-extract_tags"></a> <a id="extract_tags-class_method"></a>
Extract tags using TagService
- **`@param`** `text` [String] Text to analyze
- **`@param`** `existing_ontology` [Array<String>] Sample of existing tags for context
- **`@return`** [Array<String>] Extracted and validated tag names

### `logger()` <a id="method-c-logger"></a> <a id="logger-class_method"></a>
Get configured logger
- **`@return`** [Logger] Configured logger instance

### `production?()` <a id="method-c-production-3F"></a> <a id="production?-class_method"></a>
Check if running in production environment
- **`@return`** [Boolean]

### `reset_configuration!()` <a id="method-c-reset_configuration-21"></a> <a id="reset_configuration!-class_method"></a>
Reset configuration to defaults

### `test?()` <a id="method-c-test-3F"></a> <a id="test?-class_method"></a>
Check if running in test environment
- **`@return`** [Boolean]

## Public Instance Methods
### `clear_working_memory()` <a id="method-i-clear_working_memory"></a> <a id="clear_working_memory-instance_method"></a>
Clear all nodes from working memory

Marks all nodes as evicted from working memory (in database) and clears the
in-memory cache. Nodes remain in long-term memory.
- **`@return`** [Integer] Number of nodes cleared from working memory

**`@example`**
```ruby
htm.clear_working_memory  # => 5
```

### `forget(node_id, soft: true, confirm: false)` <a id="method-i-forget"></a> <a id="forget-instance_method"></a>
Forget a memory node (soft delete by default, permanent delete requires
confirmation)

By default, performs a soft delete (sets deleted_at timestamp). The node
remains in the database but is excluded from queries. Use soft: false with
confirm: :confirmed for permanent deletion.
- **`@param`** `node_id` [Integer] ID of the node to delete
- **`@param`** `soft` [Boolean] If true (default), soft delete; if false, permanent delete
- **`@param`** `confirm` [Symbol] Must be :confirmed to proceed with permanent deletion
- **`@raise`** [ArgumentError] if permanent deletion requested without confirmation
- **`@raise`** [HTM::NotFoundError] if node doesn't exist
- **`@return`** [Boolean] true if deleted

**@example Soft delete (recoverable)**
```ruby
htm.forget(node_id)
htm.forget(node_id, soft: true)
```

**@example Permanent delete (requires confirmation)**
```ruby
htm.forget(node_id, soft: false, confirm: :confirmed)
```

### `forget_content(content_substring, soft: true, confirm: false)` <a id="method-i-forget_content"></a> <a id="forget_content-instance_method"></a>
Forget all nodes whose content includes the given string

Performs a soft delete on all matching nodes. The nodes remain in the database
but are excluded from queries. Use case-insensitive LIKE matching.
- **`@param`** `content_substring` [String] Substring to search for in node content
- **`@param`** `soft` [Boolean] If true (default), soft delete; if false, permanent delete
- **`@param`** `confirm` [Symbol] Must be :confirmed to proceed with permanent deletion
- **`@raise`** [ArgumentError] if content_substring is blank
- **`@raise`** [ArgumentError] if permanent deletion requested without confirmation
- **`@return`** [Array<Integer>] Array of node IDs that were deleted

**@example Soft delete all nodes containing "deprecated"**
```ruby
htm.forget_content("deprecated")
# => [42, 56, 78]  # IDs of deleted nodes
```

**@example Permanent delete all nodes containing "test data"**
```ruby
htm.forget_content("test data", soft: false, confirm: :confirmed)
```

### `initialize(working_memory_size: 128_000, robot_name: nil, db_config: nil, db_pool_size: 5, db_query_timeout: 30_000, db_cache_size: 1000, db_cache_ttl: 300)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize a new HTM instance
- **`@param`** `working_memory_size` [Integer] Maximum tokens for working memory (default: 128,000)
- **`@param`** `robot_name` [String] Human-readable name for this robot (auto-generated if not provided)
- **`@param`** `db_config` [Hash] Database configuration (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@param`** `db_pool_size` [Integer] Database connection pool size (default: 5)
- **`@param`** `db_query_timeout` [Integer] Database query timeout in milliseconds (default: 30000)
- **`@param`** `db_cache_size` [Integer] Number of database query results to cache (default: 1000, use 0 to disable)
- **`@param`** `db_cache_ttl` [Integer] Database cache TTL in seconds (default: 300)
- **`@return`** [HTM] a new instance of HTM

### `load_directory(path, pattern: '**/*.md', force: false)` <a id="method-i-load_directory"></a> <a id="load_directory-instance_method"></a>
Load all matching files from a directory into long-term memory
- **`@param`** `path` [String] Directory path
- **`@param`** `pattern` [String] Glob pattern (default: '**/*.md')
- **`@param`** `force` [Boolean] Force re-sync even if unchanged (default: false)
- **`@return`** [Array<Hash>] Results for each file

**@example Load all markdown files recursively**
```ruby
results = htm.load_directory('/path/to/docs')
```

**@example Load only top-level markdown files**
```ruby
results = htm.load_directory('/path/to/docs', pattern: '*.md')
```

### `load_file(path, force: false)` <a id="method-i-load_file"></a> <a id="load_file-instance_method"></a>
Load a single file into long-term memory

Reads a text-based file (starting with markdown), chunks it by paragraph, and
stores each chunk as a node. YAML frontmatter is preserved as metadata on the
first chunk.
- **`@param`** `path` [String] Path to file
- **`@param`** `force` [Boolean] Force re-sync even if mtime unchanged (default: false)
- **`@return`** [Hash] Result with keys:
- :file_path [String] Absolute path to file
- :chunks_created [Integer] Number of new chunks created
- :chunks_updated [Integer] Number of existing chunks updated
- :chunks_deleted [Integer] Number of chunks soft-deleted
- :skipped [Boolean] True if file was unchanged and skipped

**@example Load a markdown file**
```ruby
result = htm.load_file('/path/to/doc.md')
# => { file_path: '/path/to/doc.md', chunks_created: 5, ... }
```

**@example Force re-sync even if unchanged**
```ruby
result = htm.load_file('/path/to/doc.md', force: true)
```

### `nodes_from_file(file_path)` <a id="method-i-nodes_from_file"></a> <a id="nodes_from_file-instance_method"></a>
Get all nodes loaded from a specific file
- **`@param`** `file_path` [String] Path to the source file
- **`@return`** [Array<HTM::Models::Node>] Nodes from this file, ordered by chunk_position

**`@example`**
```ruby
nodes = htm.nodes_from_file('/path/to/doc.md')
nodes.each { |node| puts node.content }
```

### `purge_deleted(older_than:, confirm: false)` <a id="method-i-purge_deleted"></a> <a id="purge_deleted-instance_method"></a>
Permanently delete all soft-deleted nodes older than specified time
- **`@param`** `older_than` [Time, ActiveSupport::Duration] Purge nodes soft-deleted before this time
- **`@param`** `confirm` [Symbol] Must be :confirmed to proceed
- **`@raise`** [ArgumentError] if confirmation not provided
- **`@return`** [Integer] Number of nodes permanently deleted

**@example Purge nodes deleted more than 30 days ago**
```ruby
htm.purge_deleted(older_than: 30.days.ago, confirm: :confirmed)
```

**@example Purge nodes deleted before a specific date**
```ruby
htm.purge_deleted(older_than: Time.new(2024, 1, 1), confirm: :confirmed)
```

### `recall(topic, timeframe: nil, limit: 20, strategy: :fulltext, with_relevance: false, query_tags: [], raw: false, metadata: {})` <a id="method-i-recall"></a> <a id="recall-instance_method"></a>
Recall memories from a timeframe and topic
- **`@param`** `topic` [String] Topic to search for (required)
- **`@param`** `timeframe` [nil, Range, Array<Range>, Date, DateTime, Time, String, Symbol] Time filter
- nil: No time filter (search all memories)
- Range: Time range (e.g., 7.days.ago..Time.now)
- Array<Range>: Multiple time windows (OR'd together)
- Date: Entire day
- DateTime/Time: Entire day containing that moment
- String: Natural language (e.g., "last week", "few days ago")
- :auto: Extract timeframe from topic query automatically
- **`@param`** `limit` [Integer] Maximum number of nodes to retrieve (default: 20)
- **`@param`** `strategy` [Symbol] Search strategy (:vector, :fulltext, :hybrid) (default: :vector)
- **`@param`** `with_relevance` [Boolean] Include dynamic relevance scores (default: false)
- **`@param`** `query_tags` [Array<String>] Tags to boost relevance (default: [])
- **`@param`** `raw` [Boolean] Return full node hashes (true) or just content strings (false) (default: false)
- **`@param`** `metadata` [Hash] Filter by metadata fields using JSONB containment (default: {})
- **`@return`** [Array<String>, Array<Hash>] Content strings (raw: false) or full node hashes (raw: true)

**@example Basic usage - no time filter (returns content strings)**
```ruby
memories = htm.recall("PostgreSQL")
# => ["PostgreSQL is great for time-series data", "PostgreSQL with TimescaleDB..."]
```

**@example With explicit timeframe**
```ruby
memories = htm.recall("PostgreSQL", timeframe: "last week")
memories = htm.recall("PostgreSQL", timeframe: Date.today)
memories = htm.recall("PostgreSQL", timeframe: 7.days.ago..Time.now)
```

**@example Auto-extract timeframe from query**
```ruby
memories = htm.recall("what did we discuss last week about PostgreSQL", timeframe: :auto)
# Extracts "last week" as timeframe, searches for "what did we discuss about PostgreSQL"
```

**@example Multiple time windows**
```ruby
memories = htm.recall("meetings", timeframe: [last_monday, last_friday])
```

**@example Filter by metadata**
```ruby
memories = htm.recall("preferences", metadata: { source: "user" })
memories = htm.recall("decisions", metadata: { confidence: 0.9, type: "architectural" })
```

### `remember(content, tags: [], metadata: {})` <a id="method-i-remember"></a> <a id="remember-instance_method"></a>
Remember new information

Stores content in long-term memory and adds it to working memory. Embeddings
and hierarchical tags are automatically extracted by LLM in the background.
- **`@param`** `content` [String] The information to remember (required, cannot be nil or empty)
- **`@param`** `tags` [Array<String>] Manual tags to assign (optional, in addition to auto-extracted tags)
- **`@raise`** [ValidationError] If content is nil, empty, or exceeds maximum size
- **`@return`** [Integer] Database ID of the memory node

**@example Remember with source**
```ruby
node_id = htm.remember("PostgreSQL is great for HTM")
```

**@example Remember with manual tags**
```ruby
node_id = htm.remember("Time-series data", tags: ["database:timescaledb"])
```

**@example Remember with metadata**
```ruby
node_id = htm.remember("User prefers dark mode", metadata: { source: "user", confidence: 0.95 })
```

### `restore(node_id)` <a id="method-i-restore"></a> <a id="restore-instance_method"></a>
Restore a soft-deleted memory node
- **`@param`** `node_id` [Integer] ID of the soft-deleted node to restore
- **`@raise`** [HTM::NotFoundError] if node doesn't exist or isn't deleted
- **`@return`** [Boolean] true if restored

**`@example`**
```ruby
htm.forget(node_id)        # Soft delete
htm.restore(node_id)       # Bring it back
```

### `unload_file(file_path)` <a id="method-i-unload_file"></a> <a id="unload_file-instance_method"></a>
Unload a file (soft-delete all its chunks and remove source record in one
transaction)
- **`@param`** `file_path` [String] Path to the source file
- **`@return`** [Integer] Number of nodes soft-deleted

**`@example`**
```ruby
count = htm.unload_file('/path/to/doc.md')
puts "Unloaded #{count} chunks"
```
