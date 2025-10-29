# frozen_string_literal: true

class HTM
  module Models
    # Node model - represents a memory node (conversation message)
    class Node < ActiveRecord::Base
      self.table_name = 'nodes'
      self.inheritance_column = nil  # Disable STI - 'type' column is for memory type, not class inheritance

      # Associations
      belongs_to :robot, class_name: 'HTM::Models::Robot', foreign_key: 'robot_id', primary_key: 'id'
      has_many :node_tags, class_name: 'HTM::Models::NodeTag', dependent: :destroy
      has_many :tags, through: :node_tags, class_name: 'HTM::Models::Tag'

      # Validations
      validates :content, presence: true
      validates :speaker, presence: true
      validates :robot_id, presence: true
      validates :importance, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
      validates :embedding_dimension, numericality: { greater_than: 0, less_than_or_equal_to: 2000 }, allow_nil: true

      # Callbacks
      before_create :set_defaults
      before_save :update_timestamps

      # Scopes
      scope :by_robot, ->(robot_id) { where(robot_id: robot_id) }
      scope :by_speaker, ->(speaker) { where(speaker: speaker) }
      scope :by_type, ->(type) { where(type: type) }
      scope :in_working_memory, -> { where(in_working_memory: true) }
      scope :recent, -> { order(created_at: :desc) }
      scope :important, -> { order(importance: :desc) }
      scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
      scope :with_embeddings, -> { where.not(embedding: nil) }

      # Instance methods
      def similarity_to(query_embedding)
        return nil unless embedding.present? && query_embedding.present?

        # Calculate cosine similarity: 1 - (embedding <=> query_embedding)
        # This requires raw SQL since pgvector operators aren't directly exposed to ActiveRecord
        result = self.class.connection.select_value(
          "SELECT 1 - (embedding <=> $1::vector) FROM nodes WHERE id = $2",
          nil,
          [[nil, query_embedding], [nil, id]]
        )
        result&.to_f
      end

      def tag_names
        tags.pluck(:name)
      end

      def add_tags(tag_names)
        Array(tag_names).each do |tag_name|
          tag = HTM::Models::Tag.find_or_create_by(name: tag_name)
          node_tags.find_or_create_by(tag_id: tag.id)
        end
      end

      def remove_tag(tag_name)
        tag = HTM::Models::Tag.find_by(name: tag_name)
        return unless tag

        node_tags.where(tag_id: tag.id).destroy_all
      end

      private

      def set_defaults
        self.importance ||= 1.0
        self.in_working_memory ||= false
        self.created_at ||= Time.current
        self.updated_at ||= Time.current
        self.last_accessed ||= Time.current
      end

      def update_timestamps
        self.updated_at = Time.current if changed?
      end
    end
  end
end
