# frozen_string_literal: true

class HTM
  module Models
    # WorkingMemoryEntry - Tracks which nodes are in each robot's working memory
    #
    # This provides optional database persistence for working memory state.
    # Useful for:
    # - Restoring working memory after process restart
    # - Querying what nodes robots are actively working with
    # - Debugging/monitoring working memory across robots
    #
    # Note: The in-memory WorkingMemory class remains the primary interface.
    # This table is for persistence/observability, not required for operation.
    #
    class WorkingMemoryEntry < ActiveRecord::Base
      self.table_name = 'working_memories'

      belongs_to :robot, class_name: 'HTM::Models::Robot'
      belongs_to :node, class_name: 'HTM::Models::Node'

      validates :robot_id, presence: true
      validates :node_id, presence: true
      validates :robot_id, uniqueness: { scope: :node_id, message: 'already has this node in working memory' }

      # Scopes
      scope :by_robot, ->(robot_id) { where(robot_id: robot_id) }
      scope :recent, -> { order(added_at: :desc) }

      # Class methods

      # Sync working memory state from in-memory hash to database
      #
      # @param robot_id [Integer] Robot ID
      # @param node_entries [Hash] Hash of node_id => { token_count:, ... }
      #
      def self.sync_from_memory(robot_id, node_entries)
        transaction do
          # Clear existing entries for this robot
          where(robot_id: robot_id).delete_all

          # Insert current entries
          node_entries.each do |node_id, data|
            create!(
              robot_id: robot_id,
              node_id: node_id,
              token_count: data[:token_count],
              added_at: data[:added_at] || Time.current
            )
          end
        end
      end

      # Load working memory state from database
      #
      # @param robot_id [Integer] Robot ID
      # @return [Hash] Hash suitable for WorkingMemory restoration
      #
      def self.load_for_robot(robot_id)
        by_robot(robot_id).includes(:node).each_with_object({}) do |entry, hash|
          hash[entry.node_id] = {
            content: entry.node.content,
            token_count: entry.token_count,
            added_at: entry.added_at,
            access_count: entry.node.access_count
          }
        end
      end

      # Clear working memory for a robot
      #
      # @param robot_id [Integer] Robot ID
      #
      def self.clear_for_robot(robot_id)
        where(robot_id: robot_id).delete_all
      end

      # Get total token count for a robot's working memory
      #
      # @param robot_id [Integer] Robot ID
      # @return [Integer] Total tokens
      #
      def self.total_tokens_for_robot(robot_id)
        where(robot_id: robot_id).sum(:token_count)
      end
    end
  end
end
