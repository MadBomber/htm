# frozen_string_literal: true

require "test_helper"

class TimeframeTest < Minitest::Test
  # Test valid? method
  def test_valid_nil
    assert HTM::Timeframe.valid?(nil)
  end

  def test_valid_auto_symbol
    assert HTM::Timeframe.valid?(:auto)
  end

  def test_valid_range
    assert HTM::Timeframe.valid?(Time.now - 3600..Time.now)
  end

  def test_valid_date
    assert HTM::Timeframe.valid?(Date.today)
  end

  def test_valid_datetime
    assert HTM::Timeframe.valid?(DateTime.now)
  end

  def test_valid_time
    assert HTM::Timeframe.valid?(Time.now)
  end

  def test_valid_string
    assert HTM::Timeframe.valid?("last week")
  end

  def test_valid_array_of_ranges
    ranges = [
      (Time.now - 7200)..(Time.now - 3600),
      (Time.now - 1800)..Time.now
    ]
    assert HTM::Timeframe.valid?(ranges)
  end

  def test_invalid_integer
    refute HTM::Timeframe.valid?(123)
  end

  def test_invalid_hash
    refute HTM::Timeframe.valid?({ start: Time.now })
  end

  # Test normalize with nil
  def test_normalize_nil_returns_nil
    assert_nil HTM::Timeframe.normalize(nil)
  end

  # Test normalize with Range
  def test_normalize_range_passes_through
    range = Time.now - 3600..Time.now
    assert_equal range, HTM::Timeframe.normalize(range)
  end

  # Test normalize with Date
  def test_normalize_date_returns_day_range
    date = Date.new(2025, 11, 28)
    result = HTM::Timeframe.normalize(date)

    assert_kind_of Range, result
    assert_equal 2025, result.begin.year
    assert_equal 11, result.begin.month
    assert_equal 28, result.begin.day
    assert_equal 0, result.begin.hour
    assert_equal 0, result.begin.min

    assert_equal 2025, result.end.year
    assert_equal 11, result.end.month
    assert_equal 28, result.end.day
    assert_equal 23, result.end.hour
    assert_equal 59, result.end.min
  end

  # Test normalize with DateTime (treated same as Date)
  def test_normalize_datetime_returns_day_range
    datetime = DateTime.new(2025, 11, 28, 14, 30, 0)
    result = HTM::Timeframe.normalize(datetime)

    assert_kind_of Range, result
    # Should be entire day, not just from the datetime
    assert_equal 0, result.begin.hour
    assert_equal 23, result.end.hour
  end

  # Test normalize with Time (treated same as Date)
  def test_normalize_time_returns_day_range
    time = Time.new(2025, 11, 28, 10, 15, 30)
    result = HTM::Timeframe.normalize(time)

    assert_kind_of Range, result
    assert_equal 0, result.begin.hour
    assert_equal 23, result.end.hour
  end

  # Test normalize with String
  def test_normalize_string_parses_natural_language
    result = HTM::Timeframe.normalize("last week")

    refute_nil result
    # Should be a range approximately 7 days back
    assert_kind_of Range, result
    assert result.begin < result.end
  end

  def test_normalize_string_yesterday
    result = HTM::Timeframe.normalize("yesterday")

    refute_nil result
  end

  def test_normalize_string_few_days_ago
    result = HTM::Timeframe.normalize("few days ago")

    refute_nil result
    # Should be approximately 3 days ago
    expected = Time.now - (3 * 24 * 60 * 60)
    timeframe_point = result.is_a?(Range) ? result.begin : result
    assert_in_delta expected.to_i, timeframe_point.to_i, 120
  end

  # Test normalize with :auto
  def test_normalize_auto_returns_result_struct
    result = HTM::Timeframe.normalize(:auto, query: "what did we discuss last week about PostgreSQL")

    assert_kind_of HTM::Timeframe::Result, result
    assert_respond_to result, :timeframe
    assert_respond_to result, :query
    assert_respond_to result, :extracted
  end

  def test_normalize_auto_extracts_timeframe_and_cleans_query
    result = HTM::Timeframe.normalize(:auto, query: "what did we discuss last week about PostgreSQL")

    refute_nil result.timeframe
    assert_equal "what did we discuss about PostgreSQL", result.query
    assert_equal "last week", result.extracted
  end

  def test_normalize_auto_with_no_timeframe_in_query
    result = HTM::Timeframe.normalize(:auto, query: "show me notes about PostgreSQL")

    assert_nil result.timeframe
    assert_equal "show me notes about PostgreSQL", result.query
    assert_nil result.extracted
  end

  def test_normalize_auto_requires_query
    assert_raises(ArgumentError) do
      HTM::Timeframe.normalize(:auto)
    end
  end

  def test_normalize_auto_requires_non_empty_query
    assert_raises(ArgumentError) do
      HTM::Timeframe.normalize(:auto, query: "")
    end
  end

  # Test normalize with Array
  def test_normalize_array_of_ranges
    range1 = Time.now - 7200..Time.now - 3600
    range2 = Time.now - 1800..Time.now
    result = HTM::Timeframe.normalize([range1, range2])

    assert_kind_of Array, result
    assert_equal 2, result.length
    assert_equal range1, result[0]
    assert_equal range2, result[1]
  end

  def test_normalize_array_of_dates
    dates = [Date.new(2025, 11, 25), Date.new(2025, 11, 28)]
    result = HTM::Timeframe.normalize(dates)

    assert_kind_of Array, result
    assert_equal 2, result.length
    assert_kind_of Range, result[0]
    assert_kind_of Range, result[1]
  end

  def test_normalize_array_mixed_types
    items = [Date.new(2025, 11, 25), Time.now - 3600..Time.now]
    result = HTM::Timeframe.normalize(items)

    assert_kind_of Array, result
    assert_equal 2, result.length
  end

  def test_normalize_empty_array_raises
    assert_raises(ArgumentError) do
      HTM::Timeframe.normalize([])
    end
  end

  # Test error handling
  def test_normalize_invalid_type_raises
    assert_raises(ArgumentError) do
      HTM::Timeframe.normalize(123)
    end
  end

  def test_normalize_invalid_range_raises
    assert_raises(ArgumentError) do
      HTM::Timeframe.normalize(1..10)  # Not time-compatible
    end
  end
end
