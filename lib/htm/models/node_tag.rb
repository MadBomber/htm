# frozen_string_literal: true

class HTM
  module Models
    # NodeTag model - join table for many-to-many relationship between nodes and tags
    class NodeTag < ActiveRecord::Base
      self.table_name = 'nodes_tags'

      # Associations
      belongs_to :node, class_name: 'HTM::Models::Node'
      belongs_to :tag, class_name: 'HTM::Models::Tag'

      # Validations
      validates :node_id, presence: true
      validates :tag_id, presence: true
      validates :tag_id, uniqueness: { scope: :node_id, message: "already associated with this node" }

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :for_node, ->(node_id) { where(node_id: node_id) }
      scope :for_tag, ->(tag_id) { where(tag_id: tag_id) }
      scope :recent, -> { order(created_at: :desc) }

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
