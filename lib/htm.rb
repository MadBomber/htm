# frozen_string_literal: true

require_relative "htm/version"
require_relative "htm/errors"
require_relative "htm/configuration"
require_relative "htm/active_record_config"
require_relative "htm/database"
require_relative "htm/long_term_memory"
require_relative "htm/working_memory"
require_relative "htm/embedding_service"
require_relative "htm/tag_service"
require_relative "htm/timeframe_extractor"
require_relative "htm/timeframe"
require_relative "htm/job_adapter"
require_relative "htm/jobs/generate_embedding_job"
require_relative "htm/jobs/generate_tags_job"
require_relative "htm/loaders/paragraph_chunker"
require_relative "htm/loaders/markdown_loader"

require "pg"
require "securerandom"
require "uri"

# Load Rails integration if Rails is defined
require_relative "htm/railtie" if defined?(Rails::Railtie)

# HTM (Hierarchical Temporary Memory) - Intelligent memory management for LLM robots
#
# HTM implements a two-tier memory system:
# - Working Memory: Token-limited, active context for immediate LLM use
# - Long-term Memory: Durable PostgreSQL/TimescaleDB storage for permanent knowledge
#
# Key Features:
# - Never forgets unless explicitly told
# - RAG-based retrieval (temporal + semantic search)
# - Multi-robot "hive mind" - all robots share global memory
# - Relationship graphs for knowledge connections
# - Time-series optimized with TimescaleDB
#
# @example Basic usage
#   htm = HTM.new(robot_name: "Code Helper")
#
#   # Remember information
#   htm.remember("We decided to use PostgreSQL for HTM", source: "architect")
#
#   # Recall from the past
#   memories = htm.recall(timeframe: "last week", topic: "PostgreSQL")
#
#   # Create context for LLM
#   context = htm.create_context(strategy: :balanced)
#
class HTM
  attr_reader :robot_id, :robot_name, :working_memory, :long_term_memory

  # Validation constants
  MAX_KEY_LENGTH = 255
  MAX_VALUE_LENGTH = 1_000_000  # 1MB
  MAX_ARRAY_SIZE = 1000

  VALID_RECALL_STRATEGIES = [:vector, :fulltext, :hybrid].freeze

  # Initialize a new HTM instance
  #
  # @param working_memory_size [Integer] Maximum tokens for working memory (default: 128,000)
  # @param robot_name [String] Human-readable name for this robot (auto-generated if not provided)
  # @param db_config [Hash] Database configuration (uses ENV['HTM_DBURL'] if not provided)
  # @param db_pool_size [Integer] Database connection pool size (default: 5)
  # @param db_query_timeout [Integer] Database query timeout in milliseconds (default: 30000)
  # @param db_cache_size [Integer] Number of database query results to cache (default: 1000, use 0 to disable)
  # @param db_cache_ttl [Integer] Database cache TTL in seconds (default: 300)
  #
  def initialize(
    working_memory_size: 128_000,
    robot_name: nil,
    db_config: nil,
    db_pool_size: 5,
    db_query_timeout: 30_000,
    db_cache_size: 1000,
    db_cache_ttl: 300
  )
    # Establish ActiveRecord connection if not already connected
    HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?

    @robot_name = robot_name || "robot_#{SecureRandom.uuid[0..7]}"

    # Initialize components
    @working_memory = HTM::WorkingMemory.new(max_tokens: working_memory_size)
    @long_term_memory = HTM::LongTermMemory.new(
      db_config || HTM::Database.default_config,
      pool_size: db_pool_size,
      query_timeout: db_query_timeout,
      cache_size: db_cache_size,
      cache_ttl: db_cache_ttl
    )

    # Register this robot in the database and get its integer ID
    @robot_id = register_robot
  end

  # Remember new information
  #
  # Stores content in long-term memory and adds it to working memory.
  # Embeddings and hierarchical tags are automatically extracted by LLM in the background.
  #
  # If content is empty, returns the ID of the most recent node without creating a duplicate.
  # Nil values for content or source are converted to empty strings.
  #
  # @param content [String, nil] The information to remember
  # @param source [String, nil] Where this content came from (defaults to empty string if not provided)
  # @param tags [Array<String>] Manual tags to assign (optional, in addition to auto-extracted tags)
  # @return [Integer] Database ID of the memory node
  #
  # @example Remember with source
  #   node_id = htm.remember("PostgreSQL is great for HTM")
  #
  # @example Remember with manual tags
  #   node_id = htm.remember("Time-series data", tags: ["database:timescaledb"])
  #
  def remember(content, tags: [])
    # Convert nil to empty string
    content = content.to_s

    # If content is empty, return the last node ID without creating a new entry
    if content.empty?
      last_node = HTM::Models::Node.order(created_at: :desc).first
      return last_node&.id || 0
    end

    # Calculate token count using configured counter
    token_count = HTM.count_tokens(content)

    # Store in long-term memory (with deduplication)
    # Returns { node_id:, is_new:, robot_node: }
    result = @long_term_memory.add(
      content: content,
      token_count: token_count,
      robot_id: @robot_id,
      embedding: nil  # Will be generated in background
    )

    node_id = result[:node_id]
    is_new = result[:is_new]

    if is_new
      HTM.logger.info "Node #{node_id} created for robot #{@robot_name} (#{token_count} tokens)"

      # Enqueue background jobs for embedding and tag generation
      # Only for NEW nodes - existing nodes already have embeddings/tags
      enqueue_embedding_job(node_id)
      enqueue_tags_job(node_id, manual_tags: tags)
    else
      HTM.logger.info "Node #{node_id} already exists, linked to robot #{@robot_name} (remember_count: #{result[:robot_node].remember_count})"

      # For existing nodes, only add manual tags if provided
      if tags.any?
        node = HTM::Models::Node.find(node_id)
        node.add_tags(tags)
        HTM.logger.info "Added #{tags.length} manual tags to existing node #{node_id}"
      end
    end

    # Add to working memory (access_count starts at 0)
    @working_memory.add(node_id, content, token_count: token_count, access_count: 0)

    update_robot_activity
    node_id
  end

  # Recall memories from a timeframe and topic
  #
  # @param topic [String] Topic to search for (required)
  # @param timeframe [nil, Range, Array<Range>, Date, DateTime, Time, String, Symbol] Time filter
  #   - nil: No time filter (search all memories)
  #   - Range: Time range (e.g., 7.days.ago..Time.now)
  #   - Array<Range>: Multiple time windows (OR'd together)
  #   - Date: Entire day
  #   - DateTime/Time: Entire day containing that moment
  #   - String: Natural language (e.g., "last week", "few days ago")
  #   - :auto: Extract timeframe from topic query automatically
  # @param limit [Integer] Maximum number of nodes to retrieve (default: 20)
  # @param strategy [Symbol] Search strategy (:vector, :fulltext, :hybrid) (default: :vector)
  # @param with_relevance [Boolean] Include dynamic relevance scores (default: false)
  # @param query_tags [Array<String>] Tags to boost relevance (default: [])
  # @param raw [Boolean] Return full node hashes (true) or just content strings (false) (default: false)
  # @return [Array<String>, Array<Hash>] Content strings (raw: false) or full node hashes (raw: true)
  #
  # @example Basic usage - no time filter (returns content strings)
  #   memories = htm.recall("PostgreSQL")
  #   # => ["PostgreSQL is great for time-series data", "PostgreSQL with TimescaleDB..."]
  #
  # @example With explicit timeframe
  #   memories = htm.recall("PostgreSQL", timeframe: "last week")
  #   memories = htm.recall("PostgreSQL", timeframe: Date.today)
  #   memories = htm.recall("PostgreSQL", timeframe: 7.days.ago..Time.now)
  #
  # @example Auto-extract timeframe from query
  #   memories = htm.recall("what did we discuss last week about PostgreSQL", timeframe: :auto)
  #   # Extracts "last week" as timeframe, searches for "what did we discuss about PostgreSQL"
  #
  # @example Multiple time windows
  #   memories = htm.recall("meetings", timeframe: [last_monday, last_friday])
  #
  def recall(topic, timeframe: nil, limit: 20, strategy: :vector, with_relevance: false, query_tags: [], raw: false)
    # Validate inputs
    validate_timeframe!(timeframe)
    validate_positive_integer!(limit, "limit")
    validate_recall_strategy!(strategy)
    validate_array!(query_tags, "query_tags")

    # Normalize timeframe and potentially extract from query
    search_query = topic
    normalized_timeframe = if timeframe == :auto
      result = HTM::Timeframe.normalize(:auto, query: topic)
      search_query = result.query  # Use cleaned query for search
      HTM.logger.debug "Auto-extracted timeframe: #{result.extracted.inspect}" if result.extracted
      result.timeframe
    else
      HTM::Timeframe.normalize(timeframe)
    end

    # Use relevance-based search if requested
    if with_relevance
      nodes = @long_term_memory.search_with_relevance(
        timeframe: normalized_timeframe,
        query: search_query,
        query_tags: query_tags,
        limit: limit,
        embedding_service: (strategy == :vector || strategy == :hybrid) ? HTM : nil
      )
    else
      # Perform standard RAG-based retrieval
      nodes = case strategy
      when :vector
        # Vector search using query embedding
        @long_term_memory.search(
          timeframe: normalized_timeframe,
          query: search_query,
          limit: limit,
          embedding_service: HTM
        )
      when :fulltext
        @long_term_memory.search_fulltext(
          timeframe: normalized_timeframe,
          query: search_query,
          limit: limit
        )
      when :hybrid
        # Hybrid search combining vector + fulltext
        @long_term_memory.search_hybrid(
          timeframe: normalized_timeframe,
          query: search_query,
          limit: limit,
          embedding_service: HTM
        )
      end
    end

    # Add to working memory (evict if needed)
    nodes.each do |node|
      add_to_working_memory(node)
    end

    update_robot_activity

    # Return full nodes or just content based on raw parameter
    raw ? nodes : nodes.map { |node| node['content'] }
  end

  # Forget a memory node (soft delete by default, permanent delete requires confirmation)
  #
  # By default, performs a soft delete (sets deleted_at timestamp). The node
  # remains in the database but is excluded from queries. Use soft: false
  # with confirm: :confirmed for permanent deletion.
  #
  # @param node_id [Integer] ID of the node to delete
  # @param soft [Boolean] If true (default), soft delete; if false, permanent delete
  # @param confirm [Symbol] Must be :confirmed to proceed with permanent deletion
  # @return [Boolean] true if deleted
  # @raise [ArgumentError] if permanent deletion requested without confirmation
  # @raise [HTM::NotFoundError] if node doesn't exist
  #
  # @example Soft delete (recoverable)
  #   htm.forget(node_id)
  #   htm.forget(node_id, soft: true)
  #
  # @example Permanent delete (requires confirmation)
  #   htm.forget(node_id, soft: false, confirm: :confirmed)
  #
  def forget(node_id, soft: true, confirm: false)
    # Validate inputs
    raise ArgumentError, "node_id cannot be nil" if node_id.nil?

    # Permanent delete requires confirmation
    if !soft && confirm != :confirmed
      raise ArgumentError, "Must pass confirm: :confirmed for permanent deletion"
    end

    # Verify node exists (including soft-deleted for restore scenarios)
    node = HTM::Models::Node.with_deleted.find_by(id: node_id)
    raise HTM::NotFoundError, "Node not found: #{node_id}" unless node

    if soft
      # Soft delete - mark as deleted but keep in database
      node.soft_delete!
      @long_term_memory.clear_cache!  # Invalidate cache since node is no longer visible
      HTM.logger.info "Node #{node_id} soft deleted"
    else
      # Permanent delete (also invalidates cache internally)
      @long_term_memory.delete(node_id)
      HTM.logger.info "Node #{node_id} permanently deleted"
    end

    # Remove from working memory either way
    @working_memory.remove(node_id)

    update_robot_activity
    true
  end

  # Restore a soft-deleted memory node
  #
  # @param node_id [Integer] ID of the soft-deleted node to restore
  # @return [Boolean] true if restored
  # @raise [HTM::NotFoundError] if node doesn't exist or isn't deleted
  #
  # @example
  #   htm.forget(node_id)        # Soft delete
  #   htm.restore(node_id)       # Bring it back
  #
  def restore(node_id)
    raise ArgumentError, "node_id cannot be nil" if node_id.nil?

    # Find including soft-deleted nodes
    node = HTM::Models::Node.with_deleted.find_by(id: node_id)
    raise HTM::NotFoundError, "Node not found: #{node_id}" unless node

    unless node.deleted?
      raise ArgumentError, "Node #{node_id} is not deleted"
    end

    node.restore!
    HTM.logger.info "Node #{node_id} restored"

    update_robot_activity
    true
  end

  # Permanently delete all soft-deleted nodes older than specified time
  #
  # @param older_than [Time, ActiveSupport::Duration] Purge nodes soft-deleted before this time
  # @param confirm [Symbol] Must be :confirmed to proceed
  # @return [Integer] Number of nodes permanently deleted
  # @raise [ArgumentError] if confirmation not provided
  #
  # @example Purge nodes deleted more than 30 days ago
  #   htm.purge_deleted(older_than: 30.days.ago, confirm: :confirmed)
  #
  # @example Purge nodes deleted before a specific date
  #   htm.purge_deleted(older_than: Time.new(2024, 1, 1), confirm: :confirmed)
  #
  def purge_deleted(older_than:, confirm: false)
    raise ArgumentError, "Must pass confirm: :confirmed to purge" unless confirm == :confirmed

    count = HTM::Models::Node.purge_deleted(older_than: older_than)
    HTM.logger.info "Purged #{count} soft-deleted nodes older than #{older_than}"

    count
  end

  # Load a single file into long-term memory
  #
  # Reads a text-based file (starting with markdown), chunks it by paragraph,
  # and stores each chunk as a node. YAML frontmatter is preserved as metadata
  # on the first chunk.
  #
  # @param path [String] Path to file
  # @param force [Boolean] Force re-sync even if mtime unchanged (default: false)
  # @return [Hash] Result with keys:
  #   - :file_path [String] Absolute path to file
  #   - :chunks_created [Integer] Number of new chunks created
  #   - :chunks_updated [Integer] Number of existing chunks updated
  #   - :chunks_deleted [Integer] Number of chunks soft-deleted
  #   - :skipped [Boolean] True if file was unchanged and skipped
  #
  # @example Load a markdown file
  #   result = htm.load_file('/path/to/doc.md')
  #   # => { file_path: '/path/to/doc.md', chunks_created: 5, ... }
  #
  # @example Force re-sync even if unchanged
  #   result = htm.load_file('/path/to/doc.md', force: true)
  #
  def load_file(path, force: false)
    loader = HTM::Loaders::MarkdownLoader.new(self)
    result = loader.load_file(path, force: force)

    update_robot_activity unless result[:skipped]
    result
  end

  # Load all matching files from a directory into long-term memory
  #
  # @param path [String] Directory path
  # @param pattern [String] Glob pattern (default: '**/*.md')
  # @param force [Boolean] Force re-sync even if unchanged (default: false)
  # @return [Array<Hash>] Results for each file
  #
  # @example Load all markdown files recursively
  #   results = htm.load_directory('/path/to/docs')
  #
  # @example Load only top-level markdown files
  #   results = htm.load_directory('/path/to/docs', pattern: '*.md')
  #
  def load_directory(path, pattern: '**/*.md', force: false)
    loader = HTM::Loaders::MarkdownLoader.new(self)
    results = loader.load_directory(path, pattern: pattern, force: force)

    # Update activity if any files were processed
    if results.any? { |r| !r[:skipped] && !r[:error] }
      update_robot_activity
    end

    results
  end

  # Get all nodes loaded from a specific file
  #
  # @param file_path [String] Path to the source file
  # @return [ActiveRecord::Relation] Nodes from this file, ordered by chunk_position
  #
  # @example
  #   nodes = htm.nodes_from_file('/path/to/doc.md')
  #   nodes.each { |node| puts node.content }
  #
  def nodes_from_file(file_path)
    source = HTM::Models::FileSource.find_by(file_path: File.expand_path(file_path))
    return HTM::Models::Node.none unless source

    HTM::Models::Node.from_source(source.id)
  end

  # Unload a file (soft-delete all its chunks and remove source record)
  #
  # @param file_path [String] Path to the source file
  # @return [Integer] Number of nodes soft-deleted
  #
  # @example
  #   count = htm.unload_file('/path/to/doc.md')
  #   puts "Unloaded #{count} chunks"
  #
  def unload_file(file_path)
    source = HTM::Models::FileSource.find_by(file_path: File.expand_path(file_path))
    return 0 unless source

    count = source.soft_delete_chunks!
    @long_term_memory.clear_cache!
    source.destroy

    update_robot_activity
    count
  end

  private

  def register_robot
    @long_term_memory.register_robot(@robot_name)
  end

  def update_robot_activity
    @long_term_memory.update_robot_activity(@robot_id)
  end

  def enqueue_embedding_job(node_id)
    # Enqueue embedding generation using configured job backend
    # Job will use HTM.embed which delegates to configured embedding_generator
    HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: node_id)
  rescue StandardError => e
    HTM.logger.error "Failed to enqueue embedding job for node #{node_id}: #{e.message}"
  end

  def enqueue_tags_job(node_id, manual_tags: [])
    # Add manual tags immediately if provided
    if manual_tags.any?
      manual_tags.each do |tag_name|
        tag = HTM::Models::Tag.find_or_create_by!(name: tag_name)
        HTM::Models::NodeTag.find_or_create_by!(node_id: node_id, tag_id: tag.id)
      end
      HTM.logger.debug "Added #{manual_tags.length} manual tags to node #{node_id}"
    end

    # Enqueue tag generation using configured job backend
    # Job will use HTM.extract_tags which delegates to configured tag_extractor
    HTM::JobAdapter.enqueue(HTM::Jobs::GenerateTagsJob, node_id: node_id)
  rescue StandardError => e
    HTM.logger.error "Failed to enqueue tags job for node #{node_id}: #{e.message}"
  end

  def add_to_working_memory(node)
    # Convert token_count to integer (may be String from database/cache)
    token_count = node['token_count'].to_i
    access_count = (node['access_count'] || 0).to_i
    last_accessed = node['last_accessed'] ? Time.parse(node['last_accessed'].to_s) : nil

    if @working_memory.has_space?(token_count)
      @working_memory.add(
        node['id'],
        node['content'],
        token_count: token_count,
        access_count: access_count,
        last_accessed: last_accessed,
        from_recall: true
      )
    else
      # Evict to make space
      evicted = @working_memory.evict_to_make_space(token_count)
      evicted_keys = evicted.map { |n| n[:key] }
      @long_term_memory.mark_evicted(evicted_keys) if evicted_keys.any?

      # Now add the recalled node
      @working_memory.add(
        node['id'],
        node['content'],
        token_count: token_count,
        access_count: access_count,
        last_accessed: last_accessed,
        from_recall: true
      )
    end
  end

  private

  # Validation helper methods

  def validate_array!(array, name, max_size: MAX_ARRAY_SIZE)
    raise ValidationError, "#{name} must be an Array" unless array.is_a?(Array)
    raise ValidationError, "#{name} too large (max #{max_size} items)" if array.size > max_size
  end

  def validate_recall_strategy!(strategy)
    raise ValidationError, "Strategy must be a Symbol" unless strategy.is_a?(Symbol)
    unless VALID_RECALL_STRATEGIES.include?(strategy)
      raise ValidationError, "Invalid strategy: #{strategy}. Must be one of #{VALID_RECALL_STRATEGIES.join(', ')}"
    end
  end


  def validate_timeframe!(timeframe)
    return if HTM::Timeframe.valid?(timeframe)
    raise ValidationError, "Invalid timeframe type: #{timeframe.class}. " \
      "Expected nil, Range, Array<Range>, Date, DateTime, Time, String, or :auto"
  end

  def validate_positive_integer!(value, name)
    raise ValidationError, "#{name} must be a positive Integer" unless value.is_a?(Integer) && value > 0
  end

end
