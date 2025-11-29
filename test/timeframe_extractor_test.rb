# frozen_string_literal: true

require "test_helper"

class TimeframeExtractorTest < Minitest::Test
  # Test the FEW constant
  def test_few_constant_is_3
    assert_equal 3, HTM::TimeframeExtractor::FEW
  end

  # Test temporal? detection
  def test_temporal_detects_yesterday
    assert HTM::TimeframeExtractor.temporal?("what did we discuss yesterday")
  end

  def test_temporal_detects_last_week
    assert HTM::TimeframeExtractor.temporal?("show me notes from last week")
  end

  def test_temporal_detects_recently
    assert HTM::TimeframeExtractor.temporal?("what did we recently discuss")
  end

  def test_temporal_detects_few_days_ago
    assert HTM::TimeframeExtractor.temporal?("show me notes from a few days ago")
  end

  def test_temporal_returns_false_for_no_timeframe
    refute HTM::TimeframeExtractor.temporal?("show me notes about PostgreSQL")
  end

  def test_temporal_handles_nil
    refute HTM::TimeframeExtractor.temporal?(nil)
  end

  def test_temporal_handles_empty_string
    refute HTM::TimeframeExtractor.temporal?("")
  end

  # Test extract with no timeframe
  def test_extract_returns_original_query_when_no_timeframe
    result = HTM::TimeframeExtractor.extract("show me notes about PostgreSQL")

    assert_equal "show me notes about PostgreSQL", result.query
    assert_nil result.timeframe
    assert_nil result.original_expression
  end

  # Test extract with "yesterday"
  def test_extract_yesterday
    result = HTM::TimeframeExtractor.extract("what did we discuss yesterday about databases")

    assert_equal "what did we discuss about databases", result.query
    assert_equal "yesterday", result.original_expression
    refute_nil result.timeframe
  end

  # Test extract with "last week"
  def test_extract_last_week
    result = HTM::TimeframeExtractor.extract("what did we discuss last week about PostgreSQL")

    assert_equal "what did we discuss about PostgreSQL", result.query
    assert_equal "last week", result.original_expression
    refute_nil result.timeframe
  end

  # Test extract with "last month"
  def test_extract_last_month
    result = HTM::TimeframeExtractor.extract("show me decisions from last month")

    assert_equal "show me decisions from", result.query
    assert_equal "last month", result.original_expression
    refute_nil result.timeframe
  end

  # Test extract with "X days ago"
  def test_extract_days_ago
    result = HTM::TimeframeExtractor.extract("show me notes from 5 days ago")

    assert_equal "show me notes from", result.query
    assert_match(/5 days ago/, result.original_expression)
    refute_nil result.timeframe
  end

  # Test "few days ago" maps to 3 days
  def test_extract_few_days_ago
    result = HTM::TimeframeExtractor.extract("show me notes from few days ago")

    assert_equal "show me notes from", result.query
    refute_nil result.timeframe

    # The timeframe should be approximately 3 days ago
    # May be a Range or Time depending on Chronic's parsing
    expected_time = Time.now - (3 * 24 * 60 * 60)
    timeframe_point = result.timeframe.is_a?(Range) ? result.timeframe.begin : result.timeframe
    assert_in_delta expected_time.to_i, timeframe_point.to_i, 120
  end

  # Test "a few days ago" maps to 3 days
  def test_extract_a_few_days_ago
    result = HTM::TimeframeExtractor.extract("show me notes from a few days ago")

    assert_equal "show me notes from", result.query
    refute_nil result.timeframe

    expected_time = Time.now - (3 * 24 * 60 * 60)
    timeframe_point = result.timeframe.is_a?(Range) ? result.timeframe.begin : result.timeframe
    assert_in_delta expected_time.to_i, timeframe_point.to_i, 120
  end

  # Test "few weeks ago"
  def test_extract_few_weeks_ago
    result = HTM::TimeframeExtractor.extract("what happened few weeks ago")

    refute_nil result.timeframe
    expected_time = Time.now - (3 * 7 * 24 * 60 * 60)
    timeframe_point = result.timeframe.is_a?(Range) ? result.timeframe.begin : result.timeframe
    assert_in_delta expected_time.to_i, timeframe_point.to_i, 120
  end

  # Test "recently" defaults to 3 days range
  def test_extract_recently_defaults_to_3_days
    result = HTM::TimeframeExtractor.extract("what did we recently discuss")

    assert_equal "what did we discuss", result.query
    assert_equal "recently", result.original_expression
    refute_nil result.timeframe

    # Should be a range
    assert_kind_of Range, result.timeframe

    # Range should span approximately 3 days
    now = Time.now
    three_days_ago = now - (3 * 24 * 60 * 60)

    assert_in_delta three_days_ago.to_i, result.timeframe.begin.to_i, 60
    assert_in_delta now.to_i, result.timeframe.end.to_i, 60
  end

  # Test "recent" (adjective form)
  def test_extract_recent_adjective
    result = HTM::TimeframeExtractor.extract("show me recent discussions about PostgreSQL")

    assert_equal "show me discussions about PostgreSQL", result.query
    assert_equal "recent", result.original_expression
    assert_kind_of Range, result.timeframe
  end

  # Test "in the last X days"
  def test_extract_in_the_last_days
    result = HTM::TimeframeExtractor.extract("what happened in the last 5 days about testing")

    assert_equal "what happened about testing", result.query
    refute_nil result.timeframe
  end

  # Test "in the past few hours"
  def test_extract_in_the_past_few_hours
    result = HTM::TimeframeExtractor.extract("show me changes in the past few hours")

    refute_nil result.timeframe
    # Should be approximately 3 hours ago
    expected_time = Time.now - (3 * 60 * 60)
    # Chronic may return a Time or Range, handle both
    timeframe_start = result.timeframe.is_a?(Range) ? result.timeframe.begin : result.timeframe
    assert_in_delta expected_time.to_i, timeframe_start.to_i, 120
  end

  # Test "since yesterday"
  def test_extract_since_yesterday
    result = HTM::TimeframeExtractor.extract("show me notes since yesterday about Ruby")

    assert_equal "show me notes about Ruby", result.query
    refute_nil result.timeframe
  end

  # Test "this morning"
  def test_extract_this_morning
    result = HTM::TimeframeExtractor.extract("what did we discuss this morning")

    assert_equal "what did we discuss", result.query
    assert_equal "this morning", result.original_expression
    refute_nil result.timeframe
  end

  # Test "today"
  def test_extract_today
    result = HTM::TimeframeExtractor.extract("show me today's notes")

    assert_equal "show me 's notes", result.query  # "today" removed
    assert_equal "today", result.original_expression
    refute_nil result.timeframe
  end

  # Test nil input
  def test_extract_handles_nil
    result = HTM::TimeframeExtractor.extract(nil)

    assert_nil result.query
    assert_nil result.timeframe
  end

  # Test empty string input
  def test_extract_handles_empty_string
    result = HTM::TimeframeExtractor.extract("")

    assert_equal "", result.query
    assert_nil result.timeframe
  end

  # Test Result struct
  def test_result_struct_has_expected_fields
    result = HTM::TimeframeExtractor.extract("test query yesterday")

    assert_respond_to result, :query
    assert_respond_to result, :timeframe
    assert_respond_to result, :original_expression
  end

  # Test case insensitivity
  def test_extract_case_insensitive
    result = HTM::TimeframeExtractor.extract("what happened YESTERDAY about POSTGRES")

    assert_equal "what happened about POSTGRES", result.query
    refute_nil result.timeframe
  end

  # Test multiple spaces are collapsed
  def test_extract_collapses_multiple_spaces
    result = HTM::TimeframeExtractor.extract("show me   yesterday   notes")

    refute_match(/\s{2,}/, result.query)
  end

  # Test "weekend before last"
  def test_extract_weekend_before_last
    result = HTM::TimeframeExtractor.extract("show me notes from weekend before last")

    assert_equal "show me notes from", result.query
    assert_equal "weekend before last", result.original_expression
    assert_kind_of Range, result.timeframe

    # Should be a Saturday to Monday range
    assert_equal 6, result.timeframe.begin.wday  # Saturday
    assert_equal 1, result.timeframe.end.wday    # Monday
  end

  # Test "the weekend before last"
  def test_extract_the_weekend_before_last
    result = HTM::TimeframeExtractor.extract("show me notes from the weekend before last")

    refute_nil result.timeframe
    assert_kind_of Range, result.timeframe
  end

  # Test "2 weekends ago"
  def test_extract_numeric_weekends_ago
    result = HTM::TimeframeExtractor.extract("what happened 2 weekends ago")

    assert_equal "what happened", result.query
    refute_nil result.timeframe
    assert_kind_of Range, result.timeframe

    # Should be Saturday to Monday range
    assert_equal 6, result.timeframe.begin.wday  # Saturday
    assert_equal 1, result.timeframe.end.wday    # Monday
  end

  # Test "two weekends ago" (written number)
  def test_extract_written_weekends_ago
    result = HTM::TimeframeExtractor.extract("what happened two weekends ago")

    refute_nil result.timeframe
    assert_kind_of Range, result.timeframe
  end

  # Test "few weekends ago"
  def test_extract_few_weekends_ago
    result = HTM::TimeframeExtractor.extract("show me notes from few weekends ago")

    refute_nil result.timeframe
    assert_kind_of Range, result.timeframe

    # "few" = 3, so should be 3 weekends ago
    assert_equal 6, result.timeframe.begin.wday  # Saturday
  end

  # Test "last weekend" still works via Chronic
  def test_extract_last_weekend
    result = HTM::TimeframeExtractor.extract("what did we do last weekend")

    assert_equal "what did we do", result.query
    refute_nil result.timeframe
    assert_kind_of Range, result.timeframe
  end

  # Test WORD_NUMBERS constant
  def test_word_numbers_constant
    assert_equal 1, HTM::TimeframeExtractor::WORD_NUMBERS['one']
    assert_equal 2, HTM::TimeframeExtractor::WORD_NUMBERS['two']
    assert_equal 10, HTM::TimeframeExtractor::WORD_NUMBERS['ten']
  end
end
