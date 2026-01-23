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
        validates_presence [:node_id, :tag_id]
        validates_unique [:node_id, :tag_id], message: "already associated with this node"
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
    end
  end
end
