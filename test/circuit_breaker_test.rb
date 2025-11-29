# frozen_string_literal: true

require "test_helper"

class CircuitBreakerTest < Minitest::Test
  def setup
    @breaker = HTM::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 3,
      reset_timeout: 1,
      half_open_max_calls: 2
    )
  end

  # State tests

  def test_initial_state_is_closed
    assert @breaker.closed?
    refute @breaker.open?
    refute @breaker.half_open?
  end

  def test_state_after_reset
    # Force some failures
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    @breaker.reset!

    assert @breaker.closed?
    assert_equal 0, @breaker.failure_count
  end

  # Success/failure tracking tests

  def test_successful_calls_pass_through
    result = @breaker.call { "success" }

    assert_equal "success", result
    assert @breaker.closed?
  end

  def test_failures_increment_count
    @breaker.call { raise "error" } rescue nil

    assert_equal 1, @breaker.failure_count
  end

  def test_opens_after_failure_threshold
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    assert @breaker.open?
    assert_equal 3, @breaker.failure_count
  end

  def test_open_circuit_fails_fast
    # Open the circuit
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    # Should raise CircuitBreakerOpenError without executing block
    call_count = 0
    error = assert_raises(HTM::CircuitBreakerOpenError) do
      @breaker.call { call_count += 1 }
    end

    assert_equal 0, call_count
    assert_match(/Circuit breaker.*is open/, error.message)
  end

  # Half-open state tests

  def test_transitions_to_half_open_after_timeout
    # Open the circuit
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    # Wait for reset timeout
    sleep(1.1)

    # Next call should be allowed (circuit transitions to half-open)
    # But we need to trigger the check first
    begin
      @breaker.call { "test" }
    rescue HTM::CircuitBreakerOpenError
      # May still be open if check hasn't run
    end

    # After attempt, should be half-open or closed
    refute @breaker.open?
  end

  def test_half_open_closes_after_successes
    # Open the circuit
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    # Wait for timeout
    sleep(1.1)

    # Successful calls should close circuit
    2.times do
      @breaker.call { "success" }
    end

    assert @breaker.closed?
  end

  def test_half_open_reopens_on_failure
    # Open the circuit
    3.times do
      @breaker.call { raise "error" } rescue nil
    end

    # Wait for timeout
    sleep(1.1)

    # Make a call to transition to half-open
    @breaker.call { "success" } rescue nil

    # Failure should reopen
    @breaker.call { raise "error" } rescue nil

    assert @breaker.open?
  end

  # Stats tests

  def test_stats_returns_correct_data
    @breaker.call { "success" }
    @breaker.call { raise "error" } rescue nil

    stats = @breaker.stats

    assert_equal 'test', stats[:name]
    assert_equal :closed, stats[:state]
    assert_equal 1, stats[:failure_count]
    assert_equal 3, stats[:failure_threshold]
    assert_equal 1, stats[:reset_timeout]
  end

  # Thread safety tests

  def test_thread_safe_operations
    threads = 10.times.map do
      Thread.new do
        10.times do
          begin
            @breaker.call { rand > 0.5 ? "success" : raise("fail") }
          rescue
            # Ignore errors
          end
        end
      end
    end

    # Should not raise any thread-related errors
    threads.each(&:join)
  end

  # Edge cases

  def test_success_resets_failure_count_in_closed_state
    2.times do
      @breaker.call { raise "error" } rescue nil
    end

    assert_equal 2, @breaker.failure_count

    @breaker.call { "success" }

    assert_equal 0, @breaker.failure_count
  end

  def test_constructor_defaults
    default_breaker = HTM::CircuitBreaker.new(name: 'default')

    assert_equal 5, default_breaker.stats[:failure_threshold]
    assert_equal 60, default_breaker.stats[:reset_timeout]
  end
end
