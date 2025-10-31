# frozen_string_literal: true

class HTM
  module Models
    # Node model - represents a memory node (conversation message)
    #
    # Nearest Neighbor Search (via neighbor gem):
    #   # Find 5 nearest neighbors by cosine distance
    #   neighbors = Node.nearest_neighbors(:embedding, query_vector, distance: "cosine").limit(5)
    #
    #   # Get distance to query for each result
    #   neighbors.each do |node|
    #     puts "Node #{node.id}: distance = #{node.neighbor_distance}"
    #   end
    #
    # Distance metrics: "cosine", "euclidean", "inner_product", "taxicab"
    #
    class Node < ActiveRecord::Base
      self.table_name = 'nodes'

      # Associations
      belongs_to :robot, class_name: 'HTM::Models::Robot', foreign_key: 'robot_id', primary_key: 'id'
      has_many :node_tags, class_name: 'HTM::Models::NodeTag', dependent: :destroy
      has_many :tags, through: :node_tags, class_name: 'HTM::Models::Tag'

      # Neighbor - vector similarity search
      has_neighbors :embedding

      # Validations
      validates :content, presence: true
      validates :robot_id, presence: true
      validates :embedding_dimension, numericality: { greater_than: 0, less_than_or_equal_to: 2000 }, allow_nil: true

      # Callbacks
      before_create :set_defaults
      before_save :update_timestamps

      # Scopes
      scope :by_robot, ->(robot_id) { where(robot_id: robot_id) }
      scope :by_source, ->(source) { where(source: source) }
      scope :in_working_memory, -> { where(in_working_memory: true) }
      scope :recent, -> { order(created_at: :desc) }
      scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
      scope :with_embeddings, -> { where.not(embedding: nil) }

      # Instance methods

      # Find nearest neighbors to this node's embedding
      # @param limit [Integer] number of neighbors to return (default: 10)
      # @param distance [String] distance metric: "cosine", "euclidean", "inner_product", "taxicab" (default: "cosine")
      # @return [ActiveRecord::Relation] ordered by distance (closest first)
      def nearest_neighbors(limit: 10, distance: "cosine")
        return self.class.none unless embedding.present?

        self.class.with_embeddings
          .where.not(id: id)  # Exclude self
          .nearest_neighbors(:embedding, embedding, distance: distance)
          .limit(limit)
      end

      # Calculate cosine similarity to another embedding or node
      # @param other [Array, Node] query embedding vector or another Node
      # @return [Float] similarity score (0.0 to 1.0, higher is more similar)
      def similarity_to(other)
        query_embedding = other.is_a?(Node) ? other.embedding : other
        return nil unless embedding.present? && query_embedding.present?

        # Calculate cosine similarity: 1 - (embedding <=> query_embedding)
        # Format the array as a PostgreSQL vector literal: '[0.1,0.2,0.3]'
        vector_str = "[#{query_embedding.join(',')}]"
        result = self.class.connection.select_value(
          "SELECT 1 - (embedding <=> '#{vector_str}'::vector) FROM nodes WHERE id = #{id}"
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
