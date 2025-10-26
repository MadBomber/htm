# frozen_string_literal: true

require "test_helper"

class CachingTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['TIGER_DBURL']
      skip "Database not configured. Set TIGER_DBURL to run caching tests."
    end

    # Use mock embedding service for tests
    @mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 768, cache_size: 100)

    @htm = HTM.new(
      robot_name: "Cache Test Robot",
      embedding_service: @mock_service,
      db_cache_size: 100,
      db_cache_ttl: 60,
      embedding_cache_size: 100
    )
  end

  def teardown
    return unless @htm

    # Clean up test data
    begin
      test_keys = [
        'cache_test_1', 'cache_test_2', 'cache_test_3',
        'cache_invalidation_test'
      ]

      # Also clean up numbered cache_test keys (from loop tests)
      10.times do |i|
        test_keys << "cache_test_#{i}"
      end

      test_keys.each do |key|
        @htm.forget(key, confirm: :confirmed) rescue nil
      end
    rescue => e
      # Ignore errors during cleanup
      puts "Cleanup warning: #{e.message}"
    ensure
      @htm.shutdown
    end
  end

  # Embedding Cache Tests

  def test_embedding_service_has_cache
    assert_respond_to @mock_service, :cache_stats
    refute_nil @mock_service.cache_stats
  end

  def test_embedding_cache_stats_structure
    stats = @mock_service.cache_stats
    assert_instance_of Hash, stats
    assert_includes stats, :hits
    assert_includes stats, :misses
    assert_includes stats, :hit_rate
    assert_includes stats, :size
  end

  def test_embedding_cache_hit
    # First call: cache miss
    embedding1 = @mock_service.embed("test text")
    stats1 = @mock_service.cache_stats

    assert_equal 0, stats1[:hits]
    assert_equal 1, stats1[:misses]
    assert_equal 0.0, stats1[:hit_rate]

    # Second call with same text: cache hit
    embedding2 = @mock_service.embed("test text")
    stats2 = @mock_service.cache_stats

    assert_equal 1, stats2[:hits]
    assert_equal 1, stats2[:misses]
    assert_equal 50.0, stats2[:hit_rate]

    # Embeddings should be identical
    assert_equal embedding1, embedding2
  end

  def test_embedding_cache_miss_on_different_text
    @mock_service.embed("first text")
    @mock_service.embed("second text")

    stats = @mock_service.cache_stats
    assert_equal 0, stats[:hits]
    assert_equal 2, stats[:misses]
  end

  def test_embedding_cache_can_be_disabled
    service_no_cache = MockEmbeddingService.new(:ollama, model: 'gpt-oss', cache_size: 0)

    # Cache should be disabled
    assert_nil service_no_cache.cache_stats

    # Should still work without caching
    embedding = service_no_cache.embed("test text")
    assert_instance_of Array, embedding
    refute_empty embedding
  end

  # Query Result Cache Tests

  def test_long_term_memory_has_cache
    # Add a test node first
    @htm.add_node("cache_test_1", "test content", type: :fact)

    # Search should use cache
    result = @htm.long_term_memory.stats
    assert_includes result, :cache
    refute_nil result[:cache]
  end

  def test_query_cache_stats_structure
    # Add a test node
    @htm.add_node("cache_test_1", "test content", type: :fact)

    # Perform a search to populate cache
    @htm.recall(timeframe: "last week", topic: "test")

    stats = @htm.long_term_memory.stats[:cache]
    assert_instance_of Hash, stats
    assert_includes stats, :hits
    assert_includes stats, :misses
    assert_includes stats, :hit_rate
    assert_includes stats, :size
  end

  def test_query_cache_hit_on_identical_queries
    # Add test data
    @htm.add_node("cache_test_1", "test content about PostgreSQL", type: :fact)

    # Use a fixed timeframe Range (not a string that gets parsed dynamically)
    now = Time.now
    timeframe = (now - 7 * 24 * 3600)..now
    topic = "PostgreSQL"

    # First query: cache miss
    result1 = @htm.recall(timeframe: timeframe, topic: topic, strategy: :fulltext)
    cache_stats1 = @htm.long_term_memory.stats[:cache]

    # Cache should have 1 miss (first query)
    assert cache_stats1[:misses] >= 1

    # Second identical query: cache hit
    result2 = @htm.recall(timeframe: timeframe, topic: topic, strategy: :fulltext)
    cache_stats2 = @htm.long_term_memory.stats[:cache]

    # Cache should have at least 1 hit
    assert cache_stats2[:hits] >= 1

    # Results should be identical
    assert_equal result1.length, result2.length
  end

  def test_query_cache_miss_on_different_queries
    # Add test data
    @htm.add_node("cache_test_1", "test content", type: :fact)

    # Different queries should not hit cache
    @htm.recall(timeframe: "last week", topic: "test1", strategy: :fulltext)
    @htm.recall(timeframe: "last week", topic: "test2", strategy: :fulltext)

    cache_stats = @htm.long_term_memory.stats[:cache]

    # Should have at least 2 misses
    assert cache_stats[:misses] >= 2
  end

  def test_query_cache_different_strategies_are_cached_separately
    # Add test data
    @htm.add_node("cache_test_1", "test content", type: :fact)

    timeframe = "last week"
    topic = "test"

    # Query with vector strategy
    @htm.recall(timeframe: timeframe, topic: topic, strategy: :vector)

    # Query with fulltext strategy (same timeframe/topic but different strategy)
    @htm.recall(timeframe: timeframe, topic: topic, strategy: :fulltext)

    cache_stats = @htm.long_term_memory.stats[:cache]

    # Should have 2 cache misses (different strategies)
    assert cache_stats[:misses] >= 2
  end

  def test_cache_invalidation_on_add_node
    # Add initial node
    @htm.add_node("cache_test_1", "initial content", type: :fact)

    # Query and cache result
    result1 = @htm.recall(timeframe: "last week", topic: "content", strategy: :fulltext)
    initial_size = result1.length

    # Get initial cache stats
    cache_stats1 = @htm.long_term_memory.stats[:cache]
    initial_cache_size = cache_stats1[:size]

    # Add new node - should invalidate cache
    @htm.add_node("cache_invalidation_test", "new content to trigger cache invalidation", type: :fact)

    # Cache should be cleared
    cache_stats2 = @htm.long_term_memory.stats[:cache]
    assert_equal 0, cache_stats2[:size], "Cache should be empty after adding node"

    # Query again - should be cache miss
    result2 = @htm.recall(timeframe: "last week", topic: "content", strategy: :fulltext)

    # Results may differ (new node included)
    assert result2.length >= initial_size
  end

  def test_cache_invalidation_on_delete_node
    # Add nodes
    @htm.add_node("cache_test_2", "content to cache", type: :fact)
    @htm.add_node("cache_test_3", "content to delete", type: :fact)

    # Query and cache
    @htm.recall(timeframe: "last week", topic: "content", strategy: :fulltext)

    # Delete node - should invalidate cache
    @htm.forget("cache_test_3", confirm: :confirmed)

    # Cache should be cleared
    cache_stats = @htm.long_term_memory.stats[:cache]
    assert_equal 0, cache_stats[:size], "Cache should be empty after deleting node"
  end

  def test_query_cache_can_be_disabled
    # Create HTM with caching disabled
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss', cache_size: 0)

    htm_no_cache = HTM.new(
      robot_name: "No Cache Robot",
      embedding_service: mock_service,
      db_cache_size: 0  # Disable query cache
    )

    begin
      # Add test data
      htm_no_cache.add_node("cache_test_1", "test content", type: :fact)

      # Stats should not include cache
      stats = htm_no_cache.long_term_memory.stats
      refute_includes stats, :cache

      # Should still work without caching
      result = htm_no_cache.recall(timeframe: "last week", topic: "test", strategy: :fulltext)
      assert_instance_of Array, result
    ensure
      htm_no_cache.forget("cache_test_1", confirm: :confirmed) rescue nil
      htm_no_cache.shutdown
    end
  end

  # Integration Tests

  def test_memory_stats_includes_cache_statistics
    # Add test data
    @htm.add_node("cache_test_1", "test content", type: :fact)

    # Perform queries to populate caches
    @htm.recall(timeframe: "last week", topic: "test")

    # Get memory stats
    stats = @htm.memory_stats

    # Should include database cache stats
    assert_includes stats, :cache
    assert_instance_of Hash, stats[:cache]

    # Should include embedding cache stats
    assert_includes stats, :embedding_cache
    assert_instance_of Hash, stats[:embedding_cache]
  end

  def test_cache_hit_rate_calculation
    # Add test data
    @htm.add_node("cache_test_1", "test content", type: :fact)

    # Query 3 times (1 miss + 2 hits)
    3.times do
      @htm.recall(timeframe: "last week", topic: "test", strategy: :fulltext)
    end

    cache_stats = @htm.long_term_memory.stats[:cache]

    # Hit rate should be 66.67% (2 hits out of 3 total)
    assert cache_stats[:hit_rate] >= 66.0
    assert cache_stats[:hit_rate] <= 67.0
  end

  def test_cache_works_with_all_search_strategies
    # Add test data
    @htm.add_node("cache_test_1", "test content for all strategies", type: :fact)

    # Use a fixed timeframe Range
    now = Time.now
    timeframe = (now - 7 * 24 * 3600)..now

    strategies = [:vector, :fulltext, :hybrid]

    strategies.each do |strategy|
      # First query: miss
      result1 = @htm.recall(timeframe: timeframe, topic: "strategies", strategy: strategy)

      # Second query: hit
      result2 = @htm.recall(timeframe: timeframe, topic: "strategies", strategy: strategy)

      # Results should be identical
      assert_equal result1.length, result2.length
    end

    cache_stats = @htm.long_term_memory.stats[:cache]

    # Should have 3 hits (one for each strategy's second call)
    assert cache_stats[:hits] >= 3
  end

  def test_embedding_cache_reduces_api_calls
    text = "repeated text for caching"

    # First call generates embedding
    embedding1 = @mock_service.embed(text)
    stats1 = @mock_service.cache_stats

    assert_equal 0, stats1[:hits]
    assert_equal 1, stats1[:misses]

    # Subsequent calls use cache (no new API calls)
    5.times do
      embedding = @mock_service.embed(text)
      assert_equal embedding1, embedding
    end

    stats2 = @mock_service.cache_stats

    # Should have 5 cache hits
    assert_equal 5, stats2[:hits]
    assert_equal 1, stats2[:misses]
    assert_equal 83.33, stats2[:hit_rate].round(2)
  end

  def test_cache_size_is_tracked
    # Add multiple nodes
    10.times do |i|
      @htm.add_node("cache_test_#{i}", "content #{i}", type: :fact)
    end

    # Query with different topics to populate cache
    10.times do |i|
      @htm.recall(timeframe: "last week", topic: "content #{i}", strategy: :fulltext)
    end

    cache_stats = @htm.long_term_memory.stats[:cache]

    # Cache should contain entries
    assert cache_stats[:size] > 0
    assert cache_stats[:size] <= 100  # Max cache size

    # Clean up
    10.times do |i|
      @htm.forget("cache_test_#{i}", confirm: :confirmed) rescue nil
    end
  end
end
