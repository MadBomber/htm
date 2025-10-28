# frozen_string_literal: true

class HTM
  module Models
    # Relationship model - represents knowledge graph edges between nodes
    class Relationship < ActiveRecord::Base
      self.table_name = 'relationships'

      # Associations
      belongs_to :from_node, class_name: 'HTM::Models::Node', foreign_key: 'from_node_id'
      belongs_to :to_node, class_name: 'HTM::Models::Node', foreign_key: 'to_node_id'

      # Validations
      validates :from_node_id, presence: true
      validates :to_node_id, presence: true
      validates :strength, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
      validates :from_node_id, uniqueness: {
        scope: [:to_node_id, :relationship_type],
        message: "relationship already exists"
      }

      # Prevent self-references
      validate :cannot_relate_to_self

      # Callbacks
      before_create :set_defaults

      # Scopes
      scope :by_type, ->(type) { where(relationship_type: type) }
      scope :from_node, ->(node_id) { where(from_node_id: node_id) }
      scope :to_node, ->(node_id) { where(to_node_id: node_id) }
      scope :strong, -> { where("strength >= ?", 5.0) }
      scope :weak, -> { where("strength < ?", 5.0) }
      scope :recent, -> { order(created_at: :desc) }

      # Class methods
      def self.between_nodes(node_id_1, node_id_2)
        where(
          "(from_node_id = ? AND to_node_id = ?) OR (from_node_id = ? AND to_node_id = ?)",
          node_id_1, node_id_2, node_id_2, node_id_1
        )
      end

      def self.find_or_create_bidirectional(from_id, to_id, type: nil, strength: 1.0)
        # Create or update relationship in both directions
        rel1 = find_or_create_by(from_node_id: from_id, to_node_id: to_id, relationship_type: type) do |r|
          r.strength = strength
        end

        rel2 = find_or_create_by(from_node_id: to_id, to_node_id: from_id, relationship_type: type) do |r|
          r.strength = strength
        end

        [rel1, rel2]
      end

      # Instance methods
      def bidirectional?
        self.class.between_nodes(from_node_id, to_node_id).count > 1
      end

      def reverse
        self.class.find_by(from_node_id: to_node_id, to_node_id: from_node_id, relationship_type: relationship_type)
      end

      private

      def set_defaults
        self.strength ||= 1.0
        self.created_at ||= Time.current
      end

      def cannot_relate_to_self
        if from_node_id == to_node_id
          errors.add(:to_node_id, "cannot be the same as from_node_id")
        end
      end
    end
  end
end
