# frozen_string_literal: true

class HTM
  module Models
    # RobotNode Join Model - Links robots to nodes (many-to-many)
    #
    # This model represents the relationship between a robot and a node,
    # tracking when and how many times a robot has "remembered" a piece of content.
    #
    class RobotNode < Sequel::Model(:robot_nodes)
      # Associations
      many_to_one :robot, class: 'HTM::Models::Robot', key: :robot_id
      many_to_one :node, class: 'HTM::Models::Node', key: :node_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence [:robot_id, :node_id]
        validates_unique [:robot_id, :node_id], message: 'already linked to this node'
      end

      # Dataset methods (scopes)
      dataset_module do
        def active
          where(deleted_at: nil)
        end

        def recent
          order(Sequel.desc(:last_remembered_at))
        end

        def by_robot(robot_id)
          where(robot_id: robot_id)
        end

        def by_node(node_id)
          where(node_id: node_id)
        end

        def frequently_remembered
          where { remember_count > 1 }.order(Sequel.desc(:remember_count))
        end

        def in_working_memory
          where(working_memory: true)
        end

        def deleted
          exclude(deleted_at: nil)
        end

        def with_deleted
          unfiltered
        end
      end

      # Apply default scope for active records
      set_dataset(dataset.where(Sequel[:robot_nodes][:deleted_at] => nil))

      # Soft delete - mark as deleted without removing from database
      #
      # @return [Boolean] true if soft deleted successfully
      #
      def soft_delete!
        update(deleted_at: Time.now)
        true
      end

      # Restore a soft-deleted entry
      #
      # @return [Boolean] true if restored successfully
      #
      def restore!
        update(deleted_at: nil)
        true
      end

      # Check if entry is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        !deleted_at.nil?
      end

      # Check if this node is in working memory
      #
      # @return [Boolean] true if working_memory is set
      #
      def working_memory?
        !!working_memory
      end

      # Record that a robot remembered this content again
      #
      # @return [RobotNode] Updated record
      #
      def record_remember!
        self.remember_count += 1
        self.last_remembered_at = Time.now
        save
        self
      end
    end
  end
end
