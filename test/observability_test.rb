# frozen_string_literal: true

require "test_helper"

class ObservabilityTest < Minitest::Test
  def setup
    HTM::Observability.reset_metrics!
  end

  def test_connection_pool_stats_when_connected
    skip_without_database
    return if skipped?

    stats = HTM::Observability.connection_pool_stats

    assert_includes [:healthy, :warning, :critical, :exhausted], stats[:status]
    assert stats[:size] > 0, "Pool size should be positive"
    assert stats[:connections] >= 0, "Connections should be non-negative"
    assert stats[:in_use] >= 0, "In-use connections should be non-negative"
    assert stats[:available] >= 0, "Available connections should be non-negative"
    assert stats[:utilization] >= 0, "Utilization should be non-negative"
  end

  def test_circuit_breaker_stats
    # Reset circuit breakers to known state
    HTM::EmbeddingService.reset_circuit_breaker!
    HTM::TagService.reset_circuit_breaker!

    stats = HTM::Observability.circuit_breaker_stats

    assert_equal :closed, stats[:embedding_service][:state]
    assert_equal 0, stats[:embedding_service][:failure_count]

    assert_equal :closed, stats[:tag_service][:state]
    assert_equal 0, stats[:tag_service][:failure_count]
  end

  def test_record_and_retrieve_query_timings
    # Record some timings
    HTM::Observability.record_query_timing(10.5, query_type: :vector)
    HTM::Observability.record_query_timing(20.3, query_type: :fulltext)
    HTM::Observability.record_query_timing(15.7, query_type: :hybrid)

    stats = HTM::Observability.query_timing_stats

    assert_equal 3, stats[:sample_count]
    assert stats[:avg_ms] > 0
    assert stats[:min_ms] > 0
    assert stats[:max_ms] >= stats[:min_ms]
    assert stats[:p50_ms] > 0
    assert stats[:p95_ms] > 0
  end

  def test_record_embedding_timings
    HTM::Observability.record_embedding_timing(100.5)
    HTM::Observability.record_embedding_timing(150.3)

    stats = HTM::Observability.service_timing_stats

    assert_equal 2, stats[:embedding][:sample_count]
    assert stats[:embedding][:avg_ms] > 0
  end

  def test_record_tag_timings
    HTM::Observability.record_tag_timing(200.0)
    HTM::Observability.record_tag_timing(250.0)

    stats = HTM::Observability.service_timing_stats

    assert_equal 2, stats[:tag_extraction][:sample_count]
    assert stats[:tag_extraction][:avg_ms] > 0
  end

  def test_memory_stats
    stats = HTM::Observability.memory_stats

    assert stats.key?(:process_rss_mb)
    assert stats.key?(:gc_stats)
  end

  def test_health_check_when_connected
    skip_without_database
    return if skipped?

    # Reset circuit breakers for clean test
    HTM::EmbeddingService.reset_circuit_breaker!
    HTM::TagService.reset_circuit_breaker!

    health = HTM::Observability.health_check

    assert health.key?(:healthy)
    assert health.key?(:checks)
    assert health.key?(:issues)
    assert health.key?(:checked_at)

    # If database is connected, should pass basic checks
    assert health[:checks][:database], "Database check should pass"
  end

  def test_healthy_returns_boolean
    skip_without_database
    return if skipped?

    result = HTM::Observability.healthy?
    assert [true, false].include?(result), "healthy? should return boolean"
  end

  def test_collect_all_returns_comprehensive_stats
    skip_without_database
    return if skipped?

    stats = HTM::Observability.collect_all

    assert stats.key?(:connection_pool)
    assert stats.key?(:cache)
    assert stats.key?(:circuit_breakers)
    assert stats.key?(:query_timings)
    assert stats.key?(:service_timings)
    assert stats.key?(:memory_usage)
    assert stats.key?(:collected_at)
  end

  def test_reset_metrics_clears_all_timings
    # Record some data
    HTM::Observability.record_query_timing(10.0)
    HTM::Observability.record_embedding_timing(100.0)
    HTM::Observability.record_tag_timing(200.0)

    # Verify data exists
    assert HTM::Observability.query_timing_stats[:sample_count] > 0

    # Reset
    HTM::Observability.reset_metrics!

    # Verify data cleared
    assert_equal 0, HTM::Observability.query_timing_stats[:sample_count]
    assert_equal 0, HTM::Observability.service_timing_stats[:embedding][:sample_count]
    assert_equal 0, HTM::Observability.service_timing_stats[:tag_extraction][:sample_count]
  end

  def test_timing_stats_handles_empty_data
    stats = HTM::Observability.query_timing_stats

    assert_equal 0, stats[:sample_count]
    refute stats.key?(:avg_ms)
  end
end
