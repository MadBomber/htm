# frozen_string_literal: true

require_relative '../test_helper'
require 'securerandom'

# Re-linking a tag whose node_tags row was soft-deleted (issue #19)
class NodeTagTest < Minitest::Test
  TAG_PREFIX = 'nodetagtest'

  def setup
    skip_without_database
    configure_htm_with_mocks

    @node = HTM::Models::Node.create(content: "node tag test #{SecureRandom.hex(8)}", token_count: 4)
    @tag_name = "#{TAG_PREFIX}:#{SecureRandom.hex(4)}"
  end

  def teardown
    return unless database_available?

    HTM::Models::NodeTag.with_deleted.where(node_id: @node.id).delete if @node
    HTM::Models::Node.dataset.unfiltered.where(id: @node.id).delete if @node
    HTM::Models::Tag.dataset.unfiltered.where(Sequel.like(:name, "#{TAG_PREFIX}%")).delete
  end

  def active_links
    HTM::Models::NodeTag.where(node_id: @node.id).count
  end

  def all_links
    HTM::Models::NodeTag.with_deleted.where(node_id: @node.id).count
  end

  def soft_delete_links
    HTM::Models::NodeTag.where(node_id: @node.id).each(&:soft_delete!)
    assert_equal 0, active_links
  end

  def test_restore_reactivates_soft_deleted_link
    tag = HTM::Models::Tag.create(name: @tag_name)
    node_tag = HTM::Models::NodeTag.create(node_id: @node.id, tag_id: tag.id)
    node_tag.soft_delete!

    assert node_tag.restore!
    refute node_tag.deleted?
    assert_equal 1, active_links
  end

  def test_link_restores_soft_deleted_row_instead_of_inserting
    tag = HTM::Models::Tag.create(name: @tag_name)
    original = HTM::Models::NodeTag.create(node_id: @node.id, tag_id: tag.id)
    original.soft_delete!

    linked = HTM::Models::NodeTag.link(node_id: @node.id, tag_id: tag.id)

    assert_equal original.id, linked.id
    refute linked.deleted?
    assert_equal 1, active_links
    assert_equal 1, all_links
  end

  def test_node_add_tags_relinks_soft_deleted_tags
    @node.add_tags(@tag_name)
    assert_equal 2, active_links
    soft_delete_links

    @node.add_tags(@tag_name)

    assert_equal 2, active_links
    assert_equal 2, all_links
  end

  def test_node_add_tags_twice_is_idempotent
    @node.add_tags(@tag_name)
    @node.add_tags(@tag_name)

    assert_equal 2, active_links
    assert_equal 2, all_links
  end

  def test_long_term_memory_add_tag_relinks_soft_deleted_tags
    ltm = HTM::LongTermMemory.allocate
    ltm.add_tag(node_id: @node.id, tag: @tag_name)
    soft_delete_links

    ltm.add_tag(node_id: @node.id, tag: @tag_name)

    assert_equal 2, active_links
    assert_equal 2, all_links
  end
end
