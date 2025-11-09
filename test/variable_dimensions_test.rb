# frozen_string_literal: true

require "test_helper"

class VariableDimensionsTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run variable dimensions tests."
    end
  end

  def test_database_max_dimension_constant
    assert_equal 2000, HTM::LongTermMemory::MAX_VECTOR_DIMENSION
  end







end
