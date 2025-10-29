# frozen_string_literal: true

class HTM
  module Models
    # Tag model - represents unique tag names
    # Tags have a many-to-many relationship with nodes through node_tags
    class Tag < ActiveRecord::Base
      self.table_name = 'tags'

      # Associations
      has_many :node_tags, class_name: 'HTM::Models::NodeTag', dependent: :destroy
      has_many :nodes, through: :node_tags, class_name: 'HTM::Models::Node'

      # Validations
      validates :name, presence: true
      validates :name, format: {
        with: /\A[a-z0-9\-]+(:[a-z0-9\-]+)*\z/,
        message: "must be lowercase with hyphens, using colons for hierarchy (e.g., 'database:postgresql:performance')"
      }
      validates :name, uniqueness: { message: "already exists" }

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :by_name, ->(name) { where(name: name) }
      scope :with_prefix, ->(prefix) { where("name LIKE ?", "#{prefix}%") }
      scope :hierarchical, -> { where("name LIKE '%:%'") }
      scope :root_level, -> { where("name NOT LIKE '%:%'") }

      # Class methods
      def self.find_by_topic_prefix(prefix)
        where("name LIKE ?", "#{prefix}%")
      end

      def self.popular_tags(limit = 10)
        joins(:node_tags)
          .select('tags.*, COUNT(node_tags.id) as usage_count')
          .group('tags.id')
          .order('usage_count DESC')
          .limit(limit)
      end

      def self.find_or_create_by_name(name)
        find_or_create_by(name: name)
      end

      # Instance methods
      def root_topic
        name.split(':').first
      end

      def topic_levels
        name.split(':')
      end

      def depth
        topic_levels.length
      end

      def hierarchical?
        name.include?(':')
      end

      def usage_count
        node_tags.count
      end

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
