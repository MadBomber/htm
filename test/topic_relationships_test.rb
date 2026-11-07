# frozen_string_literal: true

require "test_helper"

class TopicRelationshipsTest < Minitest::Test
  def setup
    skip_without_database
    return if skipped?

    configure_htm_with_mocks
    @htm    = HTM.new(robot_name: "Topic Relationships Test Robot")
    @prefix = "trel-#{SecureRandom.hex(4)}"
    @alpha, @beta, @gamma = %w[alpha beta gamma].map { "#{@prefix}-#{it}" }
    @node_ids = []
  end

  def teardown
    return unless @htm

    HTM::Models::Node.with_deleted.where(id: @node_ids).delete if @node_ids.any?
    HTM::Models::Tag.with_deleted.where(Sequel.like(:name, "#{@prefix}-%")).delete
    reset_htm_configuration
  end

  def test_counts_shared_nodes_once_per_unordered_pair
    remember_with(@alpha, @beta, @gamma)
    remember_with(@alpha, @beta)

    assert_equal(
      { [@alpha, @beta] => 2, [@alpha, @gamma] => 1, [@beta, @gamma] => 1 },
      own_pairs(@htm.long_term_memory.topic_relationships(min_shared_nodes: 1, limit: 1000))
    )
  end

  def test_rows_use_string_keys
    remember_with(@alpha, @beta)

    row = @htm.long_term_memory.topic_relationships(min_shared_nodes: 1, limit: 1000)
              .find { it["topic1"] == @alpha }

    assert_equal({ "topic1" => @alpha, "topic2" => @beta, "shared_nodes" => 1 }, row)
  end

  def test_default_min_shared_nodes_is_two
    remember_with(@alpha, @beta, @gamma)
    remember_with(@alpha, @beta)

    assert_equal({ [@alpha, @beta] => 2 }, own_pairs(@htm.long_term_memory.topic_relationships(limit: 1000)))
  end

  def test_min_shared_nodes_below_one_is_raised_to_one
    remember_with(@alpha, @beta)

    assert_equal({ [@alpha, @beta] => 1 }, own_pairs(@htm.long_term_memory.topic_relationships(min_shared_nodes: 0, limit: 1000)))
  end

  def test_limit_below_one_is_raised_to_one
    remember_with(@alpha, @beta, @gamma)

    assert_equal 1, @htm.long_term_memory.topic_relationships(min_shared_nodes: 1, limit: 0).size
  end

  def test_limit_is_capped_at_max_tag_query_limit
    bound = nil
    fetch = lambda do |_sql, *args|
      bound = args
      HTM.db.dataset.with_sql("SELECT 1 WHERE false")
    end

    HTM.db.stub(:fetch, fetch) { @htm.long_term_memory.topic_relationships(limit: 1_000_000) }

    assert_equal [2, HTM::LongTermMemory::TagOperations::MAX_TAG_QUERY_LIMIT], bound
  end

  def test_forgotten_nodes_are_not_counted
    remember_with(@alpha, @beta)
    @htm.forget(remember_with(@alpha, @beta))

    assert_equal({ [@alpha, @beta] => 1 }, own_pairs(@htm.long_term_memory.topic_relationships(min_shared_nodes: 1, limit: 1000)))
  end

  private

  def remember_with(*tags)
    node_id = @htm.remember("topic relationships fixture #{SecureRandom.hex(8)}", tags: tags)
    @node_ids << node_id
    node_id
  end

  def own_pairs(rows)
    rows.select { it["topic1"].start_with?(@prefix) }
        .to_h { [[it["topic1"], it["topic2"]], it["shared_nodes"]] }
  end
end
