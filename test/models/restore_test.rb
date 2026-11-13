# frozen_string_literal: true

require_relative '../test_helper'
require 'securerandom'

# Tag#restore!, RobotNode#restore! and reuse of soft-deleted tag names (issue #28)
class RestoreTest < Minitest::Test
  TAG_PREFIX = 'restoretest'

  def setup
    skip_without_database
    configure_htm_with_mocks

    @robot = HTM::Models::Robot.create(name: "restore-test-#{SecureRandom.hex(6)}")
    @node = HTM::Models::Node.create(content: "restore test #{SecureRandom.hex(8)}", token_count: 3)
    @tag_name = "#{TAG_PREFIX}:#{SecureRandom.hex(4)}"
  end

  def teardown
    return unless database_available?

    HTM::Models::RobotNode.with_deleted.where(robot_id: @robot.id).delete if @robot
    HTM::Models::Node.dataset.unfiltered.where(id: @node.id).delete if @node
    HTM::Models::Robot.where(id: @robot.id).delete if @robot
    HTM::Models::Tag.dataset.unfiltered.where(Sequel.like(:name, "#{TAG_PREFIX}%")).delete
  end

  def test_robot_node_restore
    robot_node = HTM::Models::RobotNode.create(robot_id: @robot.id, node_id: @node.id)
    robot_node.soft_delete!

    assert robot_node.restore!
    refute robot_node.deleted?
    assert HTM::Models::RobotNode.first(id: robot_node.id)
  end

  def test_tag_restore
    tag = HTM::Models::Tag.create(name: @tag_name)
    tag.soft_delete!

    assert tag.restore!
    refute tag.deleted?
    assert HTM::Models::Tag.first(id: tag.id)
  end

  def test_find_or_create_with_ancestors_restores_soft_deleted_tags
    original = HTM::Models::Tag.find_or_create_with_ancestors(@tag_name)
    original.each(&:soft_delete!)

    tags = HTM::Models::Tag.find_or_create_with_ancestors(@tag_name)

    assert_equal original.map(&:id), tags.map(&:id)
    assert(tags.none?(&:deleted?))
    assert_equal 2, HTM::Models::Tag.where(id: tags.map(&:id)).count
  end
end
