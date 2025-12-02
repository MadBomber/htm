# frozen_string_literal: true

class HTM
  module Models
    # Robot model - represents an LLM agent using the HTM system
    #
    # Robots can share memories through the many-to-many relationship with nodes.
    # When a robot is deleted, only the robot_nodes links are removed; shared
    # nodes remain in the database for other robots.
    #
    class Robot < ActiveRecord::Base
      self.table_name = 'robots'

      # Associations - Many-to-many with nodes via robot_nodes
      # dependent: :destroy removes links only, NOT the shared nodes
      has_many :robot_nodes, class_name: 'HTM::Models::RobotNode', dependent: :destroy
      has_many :nodes, through: :robot_nodes, class_name: 'HTM::Models::Node'

      # Validations
      validates :name, presence: true

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :recent, -> { order(created_at: :desc) }
      scope :by_name, ->(name) { where(name: name) }

      # Class methods

      # Find or create a robot by name
      #
      # @param robot_name [String] Name of the robot
      # @return [Robot] The found or created robot
      #
      def self.find_or_create_by_name(robot_name)
        find_or_create_by(name: robot_name)
      end

      # Instance methods

      # Get the total number of nodes associated with this robot
      #
      # @return [Integer] Number of nodes
      #
      def node_count
        nodes.count
      end

      # Get the most recent nodes for this robot
      #
      # @param limit [Integer] Maximum number of nodes to return (default: 10)
      # @return [ActiveRecord::Relation] Recent nodes ordered by created_at desc
      #
      def recent_nodes(limit = 10)
        nodes.recent.limit(limit)
      end

      # Get nodes with their remember metadata for this robot
      #
      # @param limit [Integer] Max nodes to return
      # @return [Array<Hash>] Nodes with remember_count, first/last_remembered_at
      #
      def nodes_with_metadata(limit = 10)
        robot_nodes
          .includes(:node)
          .order(last_remembered_at: :desc)
          .limit(limit)
          .map do |rn|
            {
              node: rn.node,
              remember_count: rn.remember_count,
              first_remembered_at: rn.first_remembered_at,
              last_remembered_at: rn.last_remembered_at
            }
          end
      end

      # Get a summary of this robot's memory state
      #
      # @return [Hash] Summary including:
      #   - :total_nodes [Integer] Total nodes associated with this robot
      #   - :in_working_memory [Integer] Nodes currently in working memory
      #   - :with_embeddings [Integer] Nodes that have embeddings generated
      #
      def memory_summary
        {
          total_nodes: nodes.count,
          in_working_memory: robot_nodes.in_working_memory.count,
          with_embeddings: nodes.with_embeddings.count
        }
      end

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
