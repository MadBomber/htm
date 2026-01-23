# frozen_string_literal: true

class HTM
  module Models
    # Robot model - represents an LLM agent using the HTM system
    #
    # Robots can share memories through the many-to-many relationship with nodes.
    # When a robot is deleted, only the robot_nodes links are removed; shared
    # nodes remain in the database for other robots.
    #
    class Robot < Sequel::Model(:robots)
      # Associations - Many-to-many with nodes via robot_nodes
      # dependent: :destroy removes links only, NOT the shared nodes
      one_to_many :robot_nodes, class: 'HTM::Models::RobotNode', key: :robot_id
      many_to_many :nodes, class: 'HTM::Models::Node',
                   join_table: :robot_nodes, left_key: :robot_id, right_key: :node_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence :name
      end

      # Dataset methods (scopes)
      dataset_module do
        def recent
          order(Sequel.desc(:created_at))
        end

        def by_name(name)
          where(name: name)
        end
      end

      # Hooks
      def before_create
        self.created_at ||= Time.now
        super
      end

      # Class methods

      # Find or create a robot by name
      #
      # @param robot_name [String] Name of the robot
      # @return [Robot] The found or created robot
      #
      def self.find_or_create_by_name(robot_name)
        find_or_create(name: robot_name)
      end

      # Instance methods

      # Get the total number of nodes associated with this robot
      #
      # @return [Integer] Number of nodes
      #
      def node_count
        nodes_dataset.count
      end

      # Get the most recent nodes for this robot
      #
      # @param limit [Integer] Maximum number of nodes to return (default: 10)
      # @return [Array<Node>] Recent nodes ordered by created_at desc
      #
      def recent_nodes(limit = 10)
        nodes_dataset.order(Sequel.desc(:created_at)).limit(limit).all
      end

      # Get nodes with their remember metadata for this robot
      #
      # @param limit [Integer] Max nodes to return
      # @return [Array<Hash>] Nodes with remember_count, first/last_remembered_at
      #
      def nodes_with_metadata(limit = 10)
        robot_nodes_dataset
          .eager(:node)
          .order(Sequel.desc(:last_remembered_at))
          .limit(limit)
          .all
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
          total_nodes: nodes_dataset.count,
          in_working_memory: robot_nodes_dataset.where(working_memory: true).count,
          with_embeddings: nodes_dataset.exclude(embedding: nil).count
        }
      end
    end
  end
end
