# frozen_string_literal: true

require "test_helper"

class IntegrationTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run integration tests."
    end

    # Use mock embedding service for tests (real Ollama not required)
        # Initialize HTM with mock embedding service
    @htm = HTM.new(
      robot_name: "Test Robot",
      working_memory_size: 128_000)
  end

  def teardown
    # Clean up test data if HTM was initialized
    return unless @htm

    begin
      # Forget test nodes (use all possible test keys)
      test_keys = [
        'test_decision_001', 'test_fact_001', 'test_code_001',
        'test_forget_001', 'test_forget_confirmation_001'
      ]
      test_keys.each do |key|
        @htm.forget(key, confirm: :confirmed) rescue nil
      end
    rescue => e
      # Ignore errors during cleanup
      puts "Cleanup warning: #{e.message}"
    ensure
      # Always shutdown to release connection pool
          end
  end

  def test_htm_initializes_with_ollama
    assert_instance_of HTM, @htm
    refute_nil @htm.robot_id
    assert_equal "Test Robot", @htm.robot_name
  end




  def test_working_memory_tracking
    # Add a node and check working memory
    @htm.remember("Working memory test with Ollama embeddings", source: "test")

    # Check working memory stats
    assert @htm.working_memory.node_count > 0
    assert @htm.working_memory.token_count > 0
    assert @htm.working_memory.utilization_percentage >= 0
  end




end
