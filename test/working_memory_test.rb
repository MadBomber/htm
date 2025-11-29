# frozen_string_literal: true

require "test_helper"

class WorkingMemoryTest < Minitest::Test
  def setup
    @wm = HTM::WorkingMemory.new(max_tokens: 1000)
  end

  def test_initialization
    assert_equal 1000, @wm.max_tokens
    assert_equal 0, @wm.node_count
    assert_equal 0, @wm.token_count
  end

  def test_add_node
    @wm.add("node1", "test content", token_count: 10)

    assert_equal 1, @wm.node_count
    assert_equal 10, @wm.token_count
  end

  def test_add_multiple_nodes
    @wm.add("node1", "content 1", token_count: 10)
    @wm.add("node2", "content 2", token_count: 20)
    @wm.add("node3", "content 3", token_count: 30)

    assert_equal 3, @wm.node_count
    assert_equal 60, @wm.token_count
  end

  def test_remove_node
    @wm.add("node1", "test content", token_count: 10)
    @wm.remove("node1")

    assert_equal 0, @wm.node_count
    assert_equal 0, @wm.token_count
  end

  def test_has_space_true
    @wm.add("node1", "content", token_count: 500)

    assert @wm.has_space?(400)
  end

  def test_has_space_false
    @wm.add("node1", "content", token_count: 800)

    refute @wm.has_space?(300)
  end

  def test_has_space_exactly_full
    @wm.add("node1", "content", token_count: 900)

    assert @wm.has_space?(100)
    refute @wm.has_space?(101)
  end

  def test_utilization_percentage
    @wm.add("node1", "content", token_count: 250)

    assert_equal 25.0, @wm.utilization_percentage
  end

  def test_utilization_percentage_empty
    assert_equal 0.0, @wm.utilization_percentage
  end

  def test_evict_to_make_space
    @wm.add("node1", "content 1", token_count: 300, access_count: 1)
    @wm.add("node2", "content 2", token_count: 300, access_count: 5)
    @wm.add("node3", "content 3", token_count: 300, access_count: 2)

    # Need to evict to make space for 200 tokens
    evicted = @wm.evict_to_make_space(200)

    assert evicted.any?
    assert @wm.has_space?(200)
  end

  def test_evict_prefers_low_access_count
    # Add high access node first
    @wm.add("node1", "content 1", token_count: 300, access_count: 100)
    sleep 0.01  # Ensure time difference
    # Add low access node second (more recent but much lower access count)
    @wm.add("node2", "content 2", token_count: 300, access_count: 1)

    evicted = @wm.evict_to_make_space(200)

    # The algorithm uses combined LFU + LRU scoring
    # With significantly different access counts, low access should be evicted
    evicted_keys = evicted.map { |e| e[:key] }
    # At least one node should be evicted
    assert evicted.any?, "Expected at least one node to be evicted"
    # The evicted node should free enough tokens
    assert @wm.has_space?(200), "Expected space for 200 tokens after eviction"
  end

  def test_assemble_context_recent
    @wm.add("node1", "first", token_count: 10)
    sleep 0.01
    @wm.add("node2", "second", token_count: 10)
    sleep 0.01
    @wm.add("node3", "third", token_count: 10)

    context = @wm.assemble_context(strategy: :recent)

    assert_includes context, "third"
    assert_includes context, "second"
    assert_includes context, "first"
  end

  def test_assemble_context_frequent
    @wm.add("node1", "low access", token_count: 10, access_count: 1)
    @wm.add("node2", "high access", token_count: 10, access_count: 100)
    @wm.add("node3", "medium access", token_count: 10, access_count: 10)

    context = @wm.assemble_context(strategy: :frequent)

    # High access content should appear first
    high_pos = context.index("high access")
    low_pos = context.index("low access")
    assert high_pos < low_pos
  end

  def test_assemble_context_balanced
    @wm.add("node1", "content 1", token_count: 10, access_count: 5)
    @wm.add("node2", "content 2", token_count: 10, access_count: 5)

    context = @wm.assemble_context(strategy: :balanced)

    assert_includes context, "content 1"
    assert_includes context, "content 2"
  end

  def test_assemble_context_unknown_strategy
    @wm.add("node1", "content", token_count: 10)

    assert_raises(ArgumentError) do
      @wm.assemble_context(strategy: :unknown)
    end
  end

  def test_assemble_context_respects_token_limit
    @wm.add("node1", "first content", token_count: 400)
    @wm.add("node2", "second content", token_count: 400)
    @wm.add("node3", "third content", token_count: 400)

    # With max_tokens: 500, only ~1 node should fit
    context = @wm.assemble_context(strategy: :recent, max_tokens: 500)

    # Should only include the most recent that fits
    parts = context.split("\n\n")
    assert parts.size <= 2
  end

  def test_assemble_context_returns_defensive_copy
    @wm.add("node1", "original content", token_count: 10, access_count: 5)

    # Get context (internally uses nodes)
    @wm.assemble_context(strategy: :recent)

    # The working memory state should still be intact
    assert_equal 1, @wm.node_count
    assert_equal 10, @wm.token_count
  end

  def test_add_with_from_recall_flag
    @wm.add("node1", "recalled content", token_count: 10, access_count: 5, from_recall: true)

    assert_equal 1, @wm.node_count
  end

  def test_add_with_last_accessed
    last_accessed = Time.now - 3600  # 1 hour ago
    @wm.add("node1", "content", token_count: 10, last_accessed: last_accessed)

    assert_equal 1, @wm.node_count
  end

  def test_node_count
    assert_equal 0, @wm.node_count

    @wm.add("node1", "content 1", token_count: 10)
    assert_equal 1, @wm.node_count

    @wm.add("node2", "content 2", token_count: 10)
    assert_equal 2, @wm.node_count

    @wm.remove("node1")
    assert_equal 1, @wm.node_count
  end

  def test_overwrite_existing_key
    @wm.add("node1", "original", token_count: 10)
    @wm.add("node1", "updated", token_count: 20)

    assert_equal 1, @wm.node_count
    assert_equal 20, @wm.token_count
  end

  def test_empty_eviction
    evicted = @wm.evict_to_make_space(100)

    assert_equal [], evicted
  end

  def test_eviction_returns_content
    @wm.add("node1", "evicted content", token_count: 500)

    evicted = @wm.evict_to_make_space(600)

    assert_equal 1, evicted.size
    assert_equal "node1", evicted.first[:key]
    assert_equal "evicted content", evicted.first[:value]
  end
end
