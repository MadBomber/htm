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
require_relative "htm/jobs/generate_embedding_job"
require_relative "htm/jobs/generate_tags_job"

require "pg"
require "pgvector"
require "securerandom"
require "uri"
require "async/job"

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
#   # Add memories
#   htm.add_message("We decided to use PostgreSQL for HTM",
#                   speaker: "architect", tags: ["type:decision", "architecture"])
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
  VALID_CONTEXT_STRATEGIES = [:recent, :frequent, :balanced].freeze

  # Initialize a new HTM instance
  #
  # @param working_memory_size [Integer] Maximum tokens for working memory (default: 128,000)
  # @param robot_id [String] Unique identifier for this robot (auto-generated if not provided)
  # @param robot_name [String] Human-readable name for this robot
  # @param db_config [Hash] Database configuration (uses ENV['HTM_DBURL'] if not provided)
  # @param db_pool_size [Integer] Database connection pool size (default: 5)
  # @param db_query_timeout [Integer] Database query timeout in milliseconds (default: 30000)
  # @param db_cache_size [Integer] Number of database query results to cache (default: 1000, use 0 to disable)
  # @param db_cache_ttl [Integer] Database cache TTL in seconds (default: 300)
  #
  def initialize(
    working_memory_size: 128_000,
    robot_id: nil,
    robot_name: nil,
    db_config: nil,
    db_pool_size: 5,
    db_query_timeout: 30_000,
    db_cache_size: 1000,
    db_cache_ttl: 300
  )
    # Establish ActiveRecord connection if not already connected
    HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?

    @robot_id = robot_id || SecureRandom.uuid
    @robot_name = robot_name || "robot_#{@robot_id[0..7]}"

    # Initialize components
    @working_memory = HTM::WorkingMemory.new(max_tokens: working_memory_size)
    @long_term_memory = HTM::LongTermMemory.new(
      db_config || HTM::Database.default_config,
      pool_size: db_pool_size,
      query_timeout: db_query_timeout,
      cache_size: db_cache_size,
      cache_ttl: db_cache_ttl
    )

    # Register this robot in the database
    register_robot
  end

  # Add a new memory node
  #
  # @param content [String] Content of the memory
  # @param speaker [String] Who created this memory (e.g., "user", "assistant", robot name)
  # @param related_to [Array<String>] Keys of related nodes
  # @param tags [Array<String>] Manual tags to add (hierarchical tags will be auto-extracted)
  # @return [Integer] Database ID of the created node
  #
  def add_message(content, speaker:, related_to: [], tags: [])
    # Validate all inputs
    validate_content!(content)
    validate_speaker!(speaker)
    validate_array!(related_to, "related_to")
    validate_array!(tags, "tags")

    # Calculate token count using configured counter
    token_count = HTM.count_tokens(content)

    # Store in long-term memory immediately (without embedding)
    # Embedding and tags will be generated asynchronously
    node_id = @long_term_memory.add(
      content: content,
      speaker: speaker,
      token_count: token_count,
      robot_id: @robot_id,
      embedding: nil  # Will be generated in background
    )

    HTM.logger.info "Node #{node_id} created for robot #{@robot_name} (#{token_count} tokens)"

    # Enqueue background jobs for embedding and tag generation
    # Both jobs run in parallel with equal priority
    enqueue_embedding_job(node_id)
    enqueue_tags_job(node_id, manual_tags: tags)

    # Add to working memory (access_count starts at 0)
    @working_memory.add(node_id, content, token_count: token_count, access_count: 0)

    update_robot_activity
    node_id
  end

  # Recall memories from a timeframe and topic
  #
  # @param timeframe [String, Range] Time range ("last week", 7.days.ago..Time.now)
  # @param topic [String] Topic to search for
  # @param limit [Integer] Maximum number of nodes to retrieve (default: 20)
  # @param strategy [Symbol] Search strategy (:vector, :fulltext, :hybrid)
  # @param with_relevance [Boolean] Include dynamic relevance scores (default: false)
  # @param query_tags [Array<String>] Tags to boost relevance (optional)
  # @return [Array<Hash>] Retrieved memory nodes (with 'relevance' key if with_relevance: true)
  #
  def recall(timeframe:, topic:, limit: 20, strategy: :vector, with_relevance: false, query_tags: [])
    # Validate inputs
    validate_timeframe!(timeframe)
    validate_value!(topic)
    validate_positive_integer!(limit, "limit")
    validate_recall_strategy!(strategy)
    validate_array!(query_tags, "query_tags")

    parsed_timeframe = parse_timeframe(timeframe)

    # Use relevance-based search if requested
    if with_relevance
      nodes = @long_term_memory.search_with_relevance(
        timeframe: parsed_timeframe,
        query: topic,
        query_tags: query_tags,
        limit: limit,
        embedding_service: (strategy == :vector || strategy == :hybrid) ? HTM : nil
      )
    else
      # Perform standard RAG-based retrieval
      nodes = case strategy
      when :vector
        # Generate query embedding using configured generator
        query_embedding = HTM.embed(topic)
        @long_term_memory.search_vector(
          timeframe: parsed_timeframe,
          query_embedding: query_embedding,
          limit: limit
        )
      when :fulltext
        @long_term_memory.search_fulltext(
          timeframe: parsed_timeframe,
          query: topic,
          limit: limit
        )
      when :hybrid
        # Generate query embedding for hybrid search
        query_embedding = HTM.embed(topic)
        @long_term_memory.search_hybrid(
          timeframe: parsed_timeframe,
          query: topic,
          query_embedding: query_embedding,
          limit: limit
        )
      end
    end

    # Add to working memory (evict if needed)
    nodes.each do |node|
      add_to_working_memory(node)
    end

    update_robot_activity
    nodes
  end

  # Recall memories by tags
  #
  # Search for nodes matching specific tags with dynamic relevance scoring.
  # Tags use hierarchical format (e.g., "type:decision", "architecture:database").
  #
  # @param tags [Array<String>] Tags to search for
  # @param match_all [Boolean] Require all tags (AND) vs. any tag (OR) (default: false)
  # @param timeframe [String, Range, nil] Optional time range filter
  # @param limit [Integer] Maximum number of nodes to retrieve (default: 20)
  # @return [Array<Hash>] Retrieved nodes with relevance scores and tags
  #
  # @example Find all database decisions
  #   nodes = htm.recall_by_tags(["type:decision", "architecture:database"], match_all: true)
  #
  # @example Find any architecture or performance related nodes
  #   nodes = htm.recall_by_tags(["architecture", "performance"])
  #
  def recall_by_tags(tags, match_all: false, timeframe: nil, limit: 20)
    # Validate inputs
    validate_array!(tags, "tags")
    raise ValidationError, "tags cannot be empty" if tags.empty?
    validate_timeframe!(timeframe) if timeframe
    validate_positive_integer!(limit, "limit")

    parsed_timeframe = timeframe ? parse_timeframe(timeframe) : nil

    nodes = @long_term_memory.search_by_tags(
      tags: tags,
      match_all: match_all,
      timeframe: parsed_timeframe,
      limit: limit
    )

    # Add to working memory (evict if needed)
    nodes.each do |node|
      add_to_working_memory(node)
    end

    update_robot_activity
    nodes
  end

  # Get most popular tags
  #
  # Returns the most frequently used tags across all nodes,
  # useful for understanding the knowledge base structure.
  #
  # @param limit [Integer] Maximum number of tags to return (default: 20)
  # @param timeframe [String, Range, nil] Optional time range filter
  # @return [Array<Hash>] Tag names with usage counts (keys: :name, :usage_count)
  #
  # @example Get top 10 tags
  #   tags = htm.popular_tags(limit: 10)
  #   tags.each { |t| puts "#{t[:name]}: #{t[:usage_count]} uses" }
  #
  # @example Get popular tags from last month
  #   tags = htm.popular_tags(timeframe: "last month", limit: 20)
  #
  def popular_tags(limit: 20, timeframe: nil)
    # Validate inputs
    validate_positive_integer!(limit, "limit")
    validate_timeframe!(timeframe) if timeframe

    parsed_timeframe = timeframe ? parse_timeframe(timeframe) : nil

    @long_term_memory.popular_tags(limit: limit, timeframe: parsed_timeframe)
  end

  # Retrieve a specific memory node
  #
  # @param key [String] Key of the node to retrieve
  # @return [Hash, nil] The node data or nil if not found
  #
  def retrieve(key)
    # Validate input
    validate_key!(key)

    node = @long_term_memory.retrieve(key)
    if node
      @long_term_memory.update_last_accessed(key)
    end
    node
  end

  # Forget a memory node (explicit deletion)
  #
  # @param key [String] Key of the node to delete
  # @param confirm [Symbol] Must be :confirmed to proceed
  # @return [Boolean] true if deleted
  # @raise [ArgumentError] if confirmation not provided
  # @raise [HTM::NotFoundError] if node doesn't exist
  #
  def forget(node_id, confirm: false)
    # Validate inputs
    raise ArgumentError, "node_id cannot be nil" if node_id.nil?
    raise ArgumentError, "Must pass confirm: :confirmed to delete" unless confirm == :confirmed

    # Verify node exists
    unless @long_term_memory.exists?(node_id)
      raise HTM::NotFoundError, "Node not found: #{node_id}"
    end

    # Delete the node and remove from working memory
    @long_term_memory.delete(node_id)
    @working_memory.remove(node_id)

    update_robot_activity
    true
  end

  # Create context string for LLM
  #
  # @param strategy [Symbol] Assembly strategy (:recent, :important, :balanced)
  # @param max_tokens [Integer] Optional token limit
  # @return [String] Assembled context
  #
  def create_context(strategy: :balanced, max_tokens: nil)
    # Validate inputs
    validate_context_strategy!(strategy)
    validate_positive_integer!(max_tokens, "max_tokens") if max_tokens

    @working_memory.assemble_context(strategy: strategy, max_tokens: max_tokens)
  end

  # Get memory statistics
  #
  # @return [Hash] Statistics about memory usage
  #
  def memory_stats
    @long_term_memory.stats.merge({
      robot_id: @robot_id,
      robot_name: @robot_name,
      working_memory: {
        current_tokens: @working_memory.token_count,
        max_tokens: @working_memory.max_tokens,
        utilization: @working_memory.utilization_percentage,
        node_count: @working_memory.node_count
      },
      database: {
        pool_size: @long_term_memory.pool_size,
        query_timeout_ms: @long_term_memory.query_timeout
      }
    })
  end

  # Shutdown HTM and release resources
  # Should be called when shutting down the application
  #
  # @return [void]
  #
  def shutdown
    @long_term_memory.shutdown
    HTM::ActiveRecordConfig.disconnect!
  end

  # Which robot discussed a topic?
  #
  # @param topic [String] Topic to search for
  # @param limit [Integer] Maximum results (default: 100)
  # @return [Hash] Robot IDs mapped to mention counts
  #
  def which_robot_said(topic, limit: 100)
    results = @long_term_memory.search_fulltext(
      timeframe: (Time.at(0)..Time.now),
      query: topic,
      limit: limit
    )

    results.group_by { |n| n['robot_id'] }
           .transform_values(&:count)
  end

  # Get chronological conversation timeline
  #
  # @param topic [String] Topic to search for
  # @param limit [Integer] Maximum results (default: 50)
  # @return [Array<Hash>] Timeline of memories
  #
  def conversation_timeline(topic, limit: 50)
    results = @long_term_memory.search_fulltext(
      timeframe: (Time.at(0)..Time.now),
      query: topic,
      limit: limit
    )

    results.sort_by { |n| n['created_at'] }
           .map { |n| {
             timestamp: n['created_at'],
             robot: n['robot_id'],
             content: n['value'],
             speaker: n['speaker']
           }}
  end

  # Retrieve nodes by ontological topic
  #
  # Enables structured navigation of the knowledge base using hierarchical topics.
  # Topics can be assigned manually via the tags parameter when adding messages.
  #
  # @param topic_path [String] Topic hierarchy path (e.g., "database:postgresql" or "ai:llm")
  # @param exact [Boolean] Exact match (false) or prefix match (true, default)
  # @param limit [Integer] Maximum results (default: 50)
  # @return [Array<Hash>] Nodes matching the topic
  #
  # @example Exact topic match
  #   nodes = htm.nodes_by_topic("database:postgresql", exact: true)
  #
  # @example Topic prefix match (includes all subtopics)
  #   nodes = htm.nodes_by_topic("database:postgresql")  # includes database:postgresql:performance, etc.
  #
  def nodes_by_topic(topic_path, exact: false, limit: 50)
    validate_value!(topic_path)
    validate_positive_integer!(limit, "limit")

    @long_term_memory.nodes_by_topic(topic_path, exact: exact, limit: limit)
  end

  # Get the ontology structure
  #
  # Returns a hierarchical view of all topics in the knowledge base,
  # showing the emergent ontology discovered by LLM analysis.
  #
  # @return [Array<Hash>] Ontology structure with root topics, levels, and node counts
  #
  # @example View ontology
  #   structure = htm.ontology_structure
  #   structure.group_by { |row| row['root_topic'] }
  #
  def ontology_structure
    @long_term_memory.ontology_structure
  end

  # Get topic relationships (co-occurrence)
  #
  # Shows which topics appear together across nodes, revealing
  # conceptual connections in the knowledge base.
  #
  # @param min_shared_nodes [Integer] Minimum shared nodes to report (default: 2)
  # @param limit [Integer] Maximum relationships to return (default: 50)
  # @return [Array<Hash>] Topic pairs with shared node counts
  #
  # @example Find related topics
  #   rels = htm.topic_relationships
  #   rels.each { |r| puts "#{r['topic1']} <-> #{r['topic2']}: #{r['shared_nodes']} nodes" }
  #
  def topic_relationships(min_shared_nodes: 2, limit: 50)
    validate_positive_integer!(min_shared_nodes, "min_shared_nodes")
    validate_positive_integer!(limit, "limit")

    @long_term_memory.topic_relationships(min_shared_nodes: min_shared_nodes, limit: limit)
  end

  # Get all topics for a specific node
  #
  # @param key [String] Node key
  # @return [Array<String>] Topic paths for this node
  #
  # @example Get node topics
  #   topics = htm.node_topics("memory_001")
  #   # => ["database:postgresql:performance", "optimization:query", "timeseries"]
  #
  def node_topics(key)
    validate_key!(key)

    node = @long_term_memory.retrieve(key)
    return [] unless node

    @long_term_memory.node_topics(node['id'].to_i)
  end

  private

  def register_robot
    @long_term_memory.register_robot(@robot_id, @robot_name)
  end

  def update_robot_activity
    @long_term_memory.update_robot_activity(@robot_id)
  end

  def enqueue_embedding_job(node_id)
    # Enqueue job using async-job
    # Job will use HTM.embed which delegates to configured embedding_generator
    Async::Job.enqueue(
      HTM::Jobs::GenerateEmbeddingJob,
      :perform,
      node_id: node_id
    )
    HTM.logger.debug "Enqueued embedding job for node #{node_id}"
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

    # Enqueue job for LLM-generated tags
    # Job will use HTM.extract_tags which delegates to configured tag_extractor
    Async::Job.enqueue(
      HTM::Jobs::GenerateTagsJob,
      :perform,
      node_id: node_id
    )
    HTM.logger.debug "Enqueued tags job for node #{node_id}"
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

  def validate_content!(content)
    raise ValidationError, "Content cannot be nil" if content.nil?
    raise ValidationError, "Content must be a String" unless content.is_a?(String)
    raise ValidationError, "Content cannot be empty" if content.empty?
    raise ValidationError, "Content too long (max #{MAX_VALUE_LENGTH} characters)" if content.length > MAX_VALUE_LENGTH
  end

  def validate_speaker!(speaker)
    raise ValidationError, "Speaker cannot be nil" if speaker.nil?
    raise ValidationError, "Speaker must be a String" unless speaker.is_a?(String)
    raise ValidationError, "Speaker cannot be empty" if speaker.empty?
    raise ValidationError, "Speaker too long (max 255 characters)" if speaker.length > 255
  end

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

  def validate_context_strategy!(strategy)
    raise ValidationError, "Strategy must be a Symbol" unless strategy.is_a?(Symbol)
    unless VALID_CONTEXT_STRATEGIES.include?(strategy)
      raise ValidationError, "Invalid strategy: #{strategy}. Must be one of #{VALID_CONTEXT_STRATEGIES.join(', ')}"
    end
  end

  def validate_timeframe!(timeframe)
    return if timeframe.is_a?(Range) || timeframe.is_a?(String)
    raise ValidationError, "Timeframe must be a Range or String, got #{timeframe.class}"
  end

  def validate_positive_integer!(value, name)
    raise ValidationError, "#{name} must be a positive Integer" unless value.is_a?(Integer) && value > 0
  end

  def validate_key!(key)
    raise ValidationError, "Key cannot be nil" if key.nil?
    raise ValidationError, "Key must be a String" unless key.is_a?(String)
    raise ValidationError, "Key cannot be empty" if key.empty?
    raise ValidationError, "Key too long (max #{MAX_KEY_LENGTH} characters)" if key.length > MAX_KEY_LENGTH
  end

  def validate_value!(value)
    raise ValidationError, "Value cannot be nil" if value.nil?
    raise ValidationError, "Value must be a String" unless value.is_a?(String)
    raise ValidationError, "Value cannot be empty" if value.empty?
  end

  # Timeframe parsing methods

  def parse_timeframe(timeframe)
    case timeframe
    when Range
      timeframe
    when String
      parse_natural_timeframe(timeframe)
    else
      raise ArgumentError, "Invalid timeframe: #{timeframe}"
    end
  end

  def parse_natural_timeframe(text)
    now = Time.now

    case text.downcase
    when /last week/
      (now - 7 * 24 * 3600)..now
    when /yesterday/
      start_of_yesterday = Time.new(now.year, now.month, now.day - 1)
      start_of_yesterday..(start_of_yesterday + 24 * 3600)
    when /last (\d+) days?/
      days = $1.to_i
      (now - days * 24 * 3600)..now
    when /this month/
      start_of_month = Time.new(now.year, now.month, 1)
      start_of_month..now
    when /last month/
      start_of_last_month = Time.new(now.year, now.month - 1, 1)
      end_of_last_month = Time.new(now.year, now.month, 1) - 1
      start_of_last_month..end_of_last_month
    else
      # Default to last 24 hours
      (now - 24 * 3600)..now
    end
  end
end
