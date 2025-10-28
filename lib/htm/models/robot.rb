# frozen_string_literal: true

class HTM
  module Models
    # Robot model - represents an LLM agent using the HTM system
    class Robot < ActiveRecord::Base
      self.table_name = 'robots'

      # Associations
      has_many :nodes, class_name: 'HTM::Models::Node', dependent: :destroy
      has_many :operation_logs, class_name: 'HTM::Models::OperationLog', dependent: :destroy

      # Validations
      validates :name, presence: true

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :active, -> { where(active: true) }
      scope :recent, -> { order(created_at: :desc) }
      scope :by_name, ->(name) { where(name: name) }

      # Class methods
      def self.find_or_create_by_name(robot_name)
        find_or_create_by(name: robot_name) do |robot|
          robot.active = true
        end
      end

      # Instance methods
      def node_count
        nodes.count
      end

      def recent_nodes(limit = 10)
        nodes.recent.limit(limit)
      end

      def memory_summary
        {
          total_nodes: nodes.count,
          in_working_memory: nodes.in_working_memory.count,
          with_embeddings: nodes.with_embeddings.count,
          by_type: nodes.group(:type).count
        }
      end

      private

      def set_created_at
        self.created_at ||= Time.current
        self.active = true if active.nil?
      end
    end
  end
end
