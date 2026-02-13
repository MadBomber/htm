# frozen_string_literal: true

require_relative "test_helper"

class RelevanceScorerTest < Minitest::Test
  def setup
    skip "Database not available" unless database_available?

    @mock_service = configure_htm_with_mocks(dimensions: 768)

    @robot_name = "scorer_test_#{Time.now.to_i}_#{rand(1000)}"
    @htm = HTM.new(robot_name: @robot_name)
    @ltm = @htm.instance_variable_get(:@long_term_memory)
  end

  def teardown
    cleanup_scorer_test_data if database_available?
    reset_htm_configuration
  end

  def cleanup_scorer_test_data
    return unless @robot_name

    robot = HTM::Models::Robot.first(name: @robot_name)
    if robot
      HTM::Models::RobotNode.where(robot_id: robot.id).delete
      robot.delete
    end
  rescue StandardError
    # Ignore cleanup errors
  end

  # ==========================================================================
  # normalize_scores_batch Tests
  # ==========================================================================

  def test_normalize_varied_similarity_scores
    candidates = [
      { 'id' => 1, 'similarity' => 0.2 },
      { 'id' => 2, 'similarity' => 0.6 },
      { 'id' => 3, 'similarity' => 1.0 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    assert_in_delta 0.0, candidates[0]['similarity'], 0.001
    assert_in_delta 0.5, candidates[1]['similarity'], 0.001
    assert_in_delta 1.0, candidates[2]['similarity'], 0.001
  end

  def test_normalize_varied_text_rank_scores
    candidates = [
      { 'id' => 1, 'text_rank' => 1.0 },
      { 'id' => 2, 'text_rank' => 3.0 },
      { 'id' => 3, 'text_rank' => 5.0 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    assert_in_delta 0.0, candidates[0]['text_rank'], 0.001
    assert_in_delta 0.5, candidates[1]['text_rank'], 0.001
    assert_in_delta 1.0, candidates[2]['text_rank'], 0.001
  end

  def test_normalize_identical_scores_maps_to_one
    candidates = [
      { 'id' => 1, 'similarity' => 0.7 },
      { 'id' => 2, 'similarity' => 0.7 },
      { 'id' => 3, 'similarity' => 0.7 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    candidates.each do |c|
      assert_in_delta 1.0, c['similarity'], 0.001
    end
  end

  def test_normalize_single_element_unchanged
    candidates = [
      { 'id' => 1, 'similarity' => 0.42, 'text_rank' => 2.5 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    assert_in_delta 0.42, candidates[0]['similarity'], 0.001
    assert_in_delta 2.5, candidates[0]['text_rank'], 0.001
  end

  def test_normalize_missing_keys_no_crash
    candidates = [
      { 'id' => 1, 'similarity' => 0.3 },
      { 'id' => 2 },
      { 'id' => 3, 'similarity' => 0.9 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    assert_in_delta 0.0, candidates[0]['similarity'], 0.001
    refute candidates[1].key?('similarity')
    assert_in_delta 1.0, candidates[2]['similarity'], 0.001
  end

  def test_normalize_empty_candidates
    candidates = []
    result = @ltm.send(:normalize_scores_batch, candidates)
    assert_equal [], result
  end

  def test_normalize_mixed_keys
    candidates = [
      { 'id' => 1, 'similarity' => 0.2, 'text_rank' => 1.0 },
      { 'id' => 2, 'similarity' => 0.8, 'text_rank' => 5.0 },
      { 'id' => 3, 'text_rank' => 3.0 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    # similarity: 0.2 -> 0.0, 0.8 -> 1.0, missing stays missing
    assert_in_delta 0.0, candidates[0]['similarity'], 0.001
    assert_in_delta 1.0, candidates[1]['similarity'], 0.001
    refute candidates[2].key?('similarity')

    # text_rank: 1.0 -> 0.0, 5.0 -> 1.0, 3.0 -> 0.5
    assert_in_delta 0.0, candidates[0]['text_rank'], 0.001
    assert_in_delta 1.0, candidates[1]['text_rank'], 0.001
    assert_in_delta 0.5, candidates[2]['text_rank'], 0.001
  end

  def test_normalize_nil_values_skipped
    candidates = [
      { 'id' => 1, 'similarity' => nil },
      { 'id' => 2, 'similarity' => 0.5 },
      { 'id' => 3, 'similarity' => 0.9 }
    ]

    @ltm.send(:normalize_scores_batch, candidates)

    assert_nil candidates[0]['similarity']
    assert_in_delta 0.0, candidates[1]['similarity'], 0.001
    assert_in_delta 1.0, candidates[2]['similarity'], 0.001
  end
end
