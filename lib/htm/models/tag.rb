# frozen_string_literal: true

class HTM
  module Models
    # Tag model - represents hierarchical topic tags for nodes
    class Tag < ActiveRecord::Base
      self.table_name = 'tags'

      # Associations
      belongs_to :node, class_name: 'HTM::Models::Node'

      # Validations
      validates :node_id, presence: true
      validates :tag, presence: true
      validates :tag, format: {
        with: /\A[a-z0-9\-]+(:[a-z0-9\-]+)*\z/,
        message: "must be lowercase with hyphens, using colons for hierarchy (e.g., 'database:postgresql:performance')"
      }
      validates :tag, uniqueness: { scope: :node_id, message: "already exists for this node" }

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :by_tag, ->(tag) { where(tag: tag) }
      scope :with_prefix, ->(prefix) { where("tag LIKE ?", "#{prefix}%") }
      scope :hierarchical, -> { where("tag LIKE '%:%'") }
      scope :root_level, -> { where("tag NOT LIKE '%:%'") }

      # Class methods
      def self.find_by_topic_prefix(prefix)
        where("tag LIKE ?", "#{prefix}%")
      end

      def self.popular_tags(limit = 10)
        select('tag, COUNT(*) as usage_count')
          .group(:tag)
          .order('usage_count DESC')
          .limit(limit)
      end

      # Instance methods
      def root_topic
        tag.split(':').first
      end

      def topic_levels
        tag.split(':')
      end

      def depth
        topic_levels.length
      end

      def hierarchical?
        tag.include?(':')
      end

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
