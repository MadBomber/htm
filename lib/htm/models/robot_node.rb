# frozen_string_literal: true

class HTM
  module Models
    # RobotNode Join Model - Links robots to nodes (many-to-many)
    #
    # This model represents the relationship between a robot and a node,
    # tracking when and how many times a robot has "remembered" a piece of content.
    #
    # @example Find all robots that remember a node
    #   node.robots
    #
    # @example Find all nodes a robot remembers
    #   robot.nodes
    #
    # @example Track remember activity
    #   link = RobotNode.find_by(robot: robot, node: node)
    #   link.remember_count  # => 3
    #   link.first_remembered_at
    #   link.last_remembered_at
    #
    class RobotNode < ActiveRecord::Base
      self.table_name = 'robot_nodes'

      belongs_to :robot, class_name: 'HTM::Models::Robot'
      belongs_to :node, class_name: 'HTM::Models::Node'

      validates :robot_id, presence: true
      validates :node_id, presence: true
      validates :robot_id, uniqueness: { scope: :node_id, message: 'already linked to this node' }

      # Scopes
      # Soft delete - by default, only show non-deleted entries
      default_scope { where(deleted_at: nil) }

      scope :recent, -> { order(last_remembered_at: :desc) }
      scope :by_robot, ->(robot_id) { where(robot_id: robot_id) }
      scope :by_node, ->(node_id) { where(node_id: node_id) }
      scope :frequently_remembered, -> { where('remember_count > 1').order(remember_count: :desc) }
      scope :in_working_memory, -> { where(working_memory: true) }

      # Soft delete scopes
      scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
      scope :with_deleted, -> { unscoped }

      # Soft delete - mark as deleted without removing from database
      #
      # @return [Boolean] true if soft deleted successfully
      #
      def soft_delete!
        update!(deleted_at: Time.current)
      end

      # Restore a soft-deleted entry
      #
      # @return [Boolean] true if restored successfully
      #
      def restore!
        update!(deleted_at: nil)
      end

      # Check if entry is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        deleted_at.present?
      end

      # Record that a robot remembered this content again
      #
      # @return [RobotNode] Updated record
      #
      def record_remember!
        self.remember_count += 1
        self.last_remembered_at = Time.current
        save!
        self
      end
    end
  end
end
