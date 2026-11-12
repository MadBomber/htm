# frozen_string_literal: true

class HTM
  module Models
    # NodeTag model - join table for many-to-many relationship between nodes and tags
    class NodeTag < Sequel::Model(:node_tags)
      # Associations
      many_to_one :node, class: 'HTM::Models::Node', key: :node_id
      many_to_one :tag, class: 'HTM::Models::Tag', key: :tag_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence %i[node_id tag_id]
        validates_unique %i[node_id tag_id], message: "already associated with this node"
      end

      # Dataset methods (scopes)
      dataset_module do
        def active
          where(deleted_at: nil)
        end

        def for_node(node_id)
          where(node_id: node_id)
        end

        def for_tag(tag_id)
          where(tag_id: tag_id)
        end

        def recent
          order(Sequel.desc(:created_at))
        end

        def deleted
          exclude(deleted_at: nil)
        end

        def with_deleted
          unfiltered
        end
      end

      # Apply default scope for active records
      set_dataset(dataset.where(Sequel[:node_tags][:deleted_at] => nil))

      # Link a node to a tag, restoring a soft-deleted link if one exists
      #
      # The unique index on (node_id, tag_id) covers soft-deleted rows, which
      # the default scope hides, so find_or_create would try to INSERT a duplicate.
      #
      # @param node_id [Integer] Node database ID
      # @param tag_id [Integer] Tag database ID
      # @return [NodeTag] the active link
      #
      def self.link(node_id:, tag_id:)
        node_tag = with_deleted.first(node_id: node_id, tag_id: tag_id)
        return create(node_id: node_id, tag_id: tag_id) unless node_tag

        node_tag.restore! if node_tag.deleted?
        node_tag
      end

      # Hooks
      def before_create
        self.created_at ||= Time.now
        super
      end

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
        # Use unfiltered dataset to bypass the default scope that excludes deleted records
        self.class.dataset.unfiltered.where(id: id).update(deleted_at: nil)
        self.deleted_at = nil
        true
      end

      # Check if entry is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        !deleted_at.nil?
      end
    end
  end
end
