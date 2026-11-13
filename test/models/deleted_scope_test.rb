# frozen_string_literal: true

require_relative '../test_helper'
require 'securerandom'

# The `deleted` dataset scopes must bypass the default `deleted_at IS NULL`
# scope, otherwise they can never match a row (issue #69)
class DeletedScopeTest < Minitest::Test
  TAG_PREFIX = 'deletedscopetest'

  def setup
    skip_without_database
    configure_htm_with_mocks

    @robot = HTM::Models::Robot.create(name: "deleted-scope-test-#{SecureRandom.hex(6)}")
    @node = HTM::Models::Node.create(content: "deleted scope test #{SecureRandom.hex(8)}", token_count: 4)
    @tag = HTM::Models::Tag.create(name: "#{TAG_PREFIX}:#{SecureRandom.hex(4)}")
  end

  def teardown
    return unless database_available?

    HTM::Models::RobotNode.with_deleted.where(robot_id: @robot.id).delete if @robot
    HTM::Models::NodeTag.with_deleted.where(node_id: @node.id).delete if @node
    HTM::Models::Node.with_deleted.where(id: @node.id).delete if @node
    HTM::Models::Robot.where(id: @robot.id).delete if @robot
    HTM::Models::Tag.with_deleted.where(Sequel.like(:name, "#{TAG_PREFIX}%")).delete
  end

  def test_deleted_scopes_do_not_include_the_default_scope
    [HTM::Models::Node, HTM::Models::NodeTag, HTM::Models::RobotNode, HTM::Models::Tag].each do |model|
      sql = model.deleted.sql

      refute_match(/IS NULL/, sql, "#{model}.deleted should not keep the default scope: #{sql}")
      assert_match(/IS NOT NULL/, sql)
    end
  end

  def test_node_deleted_finds_soft_deleted_node
    @node.soft_delete!

    assert_includes HTM::Models::Node.deleted.select_map(:id), @node.id
    refute_includes HTM::Models::Node.select_map(:id), @node.id
  end

  def test_node_deleted_before_finds_soft_deleted_node
    @node.soft_delete!

    assert_includes HTM::Models::Node.deleted_before(Time.now + 60).select_map(:id), @node.id
    refute_includes HTM::Models::Node.deleted_before(Time.now - 3600).select_map(:id), @node.id
  end

  def test_robot_node_deleted_finds_soft_deleted_link
    robot_node = HTM::Models::RobotNode.create(robot_id: @robot.id, node_id: @node.id)
    robot_node.soft_delete!

    assert_includes HTM::Models::RobotNode.deleted.select_map(:id), robot_node.id
  end

  def test_node_tag_deleted_finds_soft_deleted_link
    node_tag = HTM::Models::NodeTag.create(node_id: @node.id, tag_id: @tag.id)
    node_tag.soft_delete!

    assert_includes HTM::Models::NodeTag.deleted.select_map(:id), node_tag.id
  end

  def test_tag_deleted_finds_soft_deleted_tag
    @tag.soft_delete!

    assert_includes HTM::Models::Tag.deleted.select_map(:id), @tag.id
  end
end
