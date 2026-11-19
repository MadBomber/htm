# frozen_string_literal: true

require_relative '../test_helper'
require 'securerandom'

# Tag.with_prefix must treat LIKE wildcards (% and _) in the prefix as
# literal characters, not patterns.
class TagPrefixTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    @root = "tagprefixtest-#{SecureRandom.hex(4)}"
    @names = %W[#{@root}:data-base:pg #{@root}:dataxbase:pg].each { |name| HTM::Models::Tag.create(name: name) }
  end

  def teardown
    return unless database_available?

    HTM::Models::Tag.with_deleted.where(name: @names).delete if @names
  end

  def test_with_prefix_matches_plain_prefix
    assert_equal @names.sort, HTM::Models::Tag.with_prefix(@root).select_map(:name).sort
  end

  def test_with_prefix_treats_underscore_literally
    assert_empty HTM::Models::Tag.with_prefix("#{@root}:data_base").select_map(:name)
  end

  def test_with_prefix_treats_percent_literally
    assert_empty HTM::Models::Tag.with_prefix("#{@root}:%").select_map(:name)
  end
end
