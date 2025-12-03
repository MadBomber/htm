# frozen_string_literal: true

class HTM
  module Models
    # NodeTag model - join table for many-to-many relationship between nodes and tags
    class NodeTag < ActiveRecord::Base
      self.table_name = 'node_tags'

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
      # Soft delete - by default, only show non-deleted entries
      default_scope { where(deleted_at: nil) }

      scope :for_node, ->(node_id) { where(node_id: node_id) }
      scope :for_tag, ->(tag_id) { where(tag_id: tag_id) }
      scope :recent, -> { order(created_at: :desc) }

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

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
