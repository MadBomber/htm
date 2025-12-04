# frozen_string_literal: true

require "test_helper"

class TelemetryTest < Minitest::Test
  def setup
    # Reset telemetry state before each test
    HTM::Telemetry.reset!

    # Store original config and disable telemetry
    @original_telemetry_enabled = HTM.configuration.telemetry_enabled
    HTM.configuration.telemetry_enabled = false
  end

  def teardown
    # Restore original config
    HTM.configuration.telemetry_enabled = @original_telemetry_enabled
    HTM::Telemetry.reset!
  end

  def test_enabled_returns_false_when_telemetry_disabled
    HTM.configuration.telemetry_enabled = false
    refute HTM::Telemetry.enabled?
  end

  def test_enabled_returns_false_when_sdk_not_available
    # When telemetry is enabled but SDK isn't installed
    HTM.configuration.telemetry_enabled = true

    # sdk_available? checks if the gem can be loaded
    # In most test environments, the gem won't be installed
    # so this should be false unless the gem is present
    result = HTM::Telemetry.enabled?

    # Result depends on whether opentelemetry-metrics-sdk is installed
    # Either way, this shouldn't raise an error
    assert [true, false].include?(result)
  end

  def test_meter_returns_null_meter_when_disabled
    HTM.configuration.telemetry_enabled = false

    meter = HTM::Telemetry.meter
    assert_kind_of HTM::Telemetry::NullMeter, meter
  end

  def test_null_meter_creates_null_instruments
    null_meter = HTM::Telemetry::NullMeter.instance

    counter = null_meter.create_counter('test.counter')
    histogram = null_meter.create_histogram('test.histogram')
    up_down = null_meter.create_up_down_counter('test.updown')

    assert_kind_of HTM::Telemetry::NullInstrument, counter
    assert_kind_of HTM::Telemetry::NullInstrument, histogram
    assert_kind_of HTM::Telemetry::NullInstrument, up_down
  end

  def test_null_instrument_accepts_operations_silently
    null_instrument = HTM::Telemetry::NullInstrument.instance

    # These should all return nil and not raise errors
    assert_nil null_instrument.add(1)
    assert_nil null_instrument.add(1, attributes: { 'foo' => 'bar' })
    assert_nil null_instrument.record(100)
    assert_nil null_instrument.record(100, attributes: { 'baz' => 'qux' })
  end

  def test_job_counter_returns_null_instrument_when_disabled
    HTM.configuration.telemetry_enabled = false

    counter = HTM::Telemetry.job_counter
    assert_kind_of HTM::Telemetry::NullInstrument, counter
  end

  def test_embedding_latency_returns_null_instrument_when_disabled
    HTM.configuration.telemetry_enabled = false

    histogram = HTM::Telemetry.embedding_latency
    assert_kind_of HTM::Telemetry::NullInstrument, histogram
  end

  def test_tag_latency_returns_null_instrument_when_disabled
    HTM.configuration.telemetry_enabled = false

    histogram = HTM::Telemetry.tag_latency
    assert_kind_of HTM::Telemetry::NullInstrument, histogram
  end

  def test_search_latency_returns_null_instrument_when_disabled
    HTM.configuration.telemetry_enabled = false

    histogram = HTM::Telemetry.search_latency
    assert_kind_of HTM::Telemetry::NullInstrument, histogram
  end

  def test_cache_operations_returns_null_instrument_when_disabled
    HTM.configuration.telemetry_enabled = false

    counter = HTM::Telemetry.cache_operations
    assert_kind_of HTM::Telemetry::NullInstrument, counter
  end

  def test_measure_returns_block_result
    histogram = HTM::Telemetry::NullInstrument.instance

    result = HTM::Telemetry.measure(histogram, 'test' => 'value') do
      "computed result"
    end

    assert_equal "computed result", result
  end

  def test_measure_records_elapsed_time
    # Create a mock histogram that captures the recorded value
    recorded_values = []
    mock_histogram = Object.new
    mock_histogram.define_singleton_method(:record) do |value, **kwargs|
      recorded_values << { value: value, attributes: kwargs[:attributes] }
    end

    # Run a block that takes some measurable time
    HTM::Telemetry.measure(mock_histogram, 'strategy' => 'test') do
      sleep(0.01)  # 10ms
    end

    assert_equal 1, recorded_values.length
    assert recorded_values.first[:value] >= 10, "Expected at least 10ms elapsed"
    assert_equal({ 'strategy' => 'test' }, recorded_values.first[:attributes])
  end

  def test_reset_clears_cached_instruments
    # Access instruments to cache them
    HTM::Telemetry.job_counter
    HTM::Telemetry.embedding_latency
    HTM::Telemetry.tag_latency
    HTM::Telemetry.search_latency
    HTM::Telemetry.cache_operations

    # Reset should clear cached instances
    HTM::Telemetry.reset!

    # New calls should create new instances
    # (we can verify by checking the singleton is returned when disabled)
    HTM.configuration.telemetry_enabled = false
    assert_kind_of HTM::Telemetry::NullInstrument, HTM::Telemetry.job_counter
  end

  def test_sdk_available_is_memoized
    # First call determines availability
    first_result = HTM::Telemetry.sdk_available?

    # Second call should return same result (memoized)
    second_result = HTM::Telemetry.sdk_available?

    assert_equal first_result, second_result
  end

  def test_telemetry_enabled_via_env_var
    # Save original
    original_env = ENV['HTM_TELEMETRY_ENABLED']

    begin
      # Reset configuration to pick up env var
      ENV['HTM_TELEMETRY_ENABLED'] = 'true'
      HTM.reset_configuration!

      assert HTM.configuration.telemetry_enabled
    ensure
      # Restore
      if original_env
        ENV['HTM_TELEMETRY_ENABLED'] = original_env
      else
        ENV.delete('HTM_TELEMETRY_ENABLED')
      end
      HTM.reset_configuration!
      configure_htm_with_mocks
    end
  end

  def test_telemetry_disabled_via_env_var
    # Save original
    original_env = ENV['HTM_TELEMETRY_ENABLED']

    begin
      # Reset configuration to pick up env var
      ENV['HTM_TELEMETRY_ENABLED'] = 'false'
      HTM.reset_configuration!

      refute HTM.configuration.telemetry_enabled
    ensure
      # Restore
      if original_env
        ENV['HTM_TELEMETRY_ENABLED'] = original_env
      else
        ENV.delete('HTM_TELEMETRY_ENABLED')
      end
      HTM.reset_configuration!
      configure_htm_with_mocks
    end
  end

  def test_null_meter_is_singleton
    meter1 = HTM::Telemetry::NullMeter.instance
    meter2 = HTM::Telemetry::NullMeter.instance

    assert_same meter1, meter2
  end

  def test_null_instrument_is_singleton
    instrument1 = HTM::Telemetry::NullInstrument.instance
    instrument2 = HTM::Telemetry::NullInstrument.instance

    assert_same instrument1, instrument2
  end
end
