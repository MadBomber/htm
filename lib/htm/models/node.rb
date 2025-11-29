# frozen_string_literal: true

require 'digest'

class HTM
  module Models
    # Node model - represents a memory node (conversation message)
    #
    # Nodes are globally unique by content (via content_hash) and can be
    # linked to multiple robots through the robot_nodes join table.
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

      # Associations - Many-to-many with robots via robot_nodes
      has_many :robot_nodes, class_name: 'HTM::Models::RobotNode', dependent: :destroy
      has_many :robots, through: :robot_nodes, class_name: 'HTM::Models::Robot'
      has_many :node_tags, class_name: 'HTM::Models::NodeTag', dependent: :destroy
      has_many :tags, through: :node_tags, class_name: 'HTM::Models::Tag'

      # Optional source file association (for nodes loaded from files)
      belongs_to :file_source, class_name: 'HTM::Models::FileSource',
                 foreign_key: :source_id, optional: true

      # Neighbor - vector similarity search
      has_neighbors :embedding

      # Validations
      validates :content, presence: true
      validates :content_hash, presence: true, uniqueness: true

      # Callbacks
      before_validation :set_content_hash, if: -> { content_hash.blank? && content.present? }
      before_create :set_defaults
      before_save :update_timestamps

      # Scopes
      # Soft delete - by default, only show non-deleted nodes
      default_scope { where(deleted_at: nil) }

      scope :by_robot, ->(robot_id) { joins(:robot_nodes).where(robot_nodes: { robot_id: robot_id }) }
      scope :recent, -> { order(created_at: :desc) }
      scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
      scope :with_embeddings, -> { where.not(embedding: nil) }
      scope :from_source, ->(source_id) { where(source_id: source_id).order(:chunk_position) }

      # Soft delete scopes
      scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
      scope :with_deleted, -> { unscoped }
      scope :deleted_before, ->(time) { deleted.where('deleted_at < ?', time) }

      # Class methods

      # Permanently delete all soft-deleted nodes older than the specified time
      #
      # @param older_than [Time, ActiveSupport::Duration] Delete nodes soft-deleted before this time
      #   Can be a Time object or a duration like 30.days.ago
      # @return [Integer] Number of nodes permanently deleted
      #
      def self.purge_deleted(older_than:)
        deleted_before(older_than).destroy_all.count
      end

      # Find a node by content hash, or return nil
      #
      # @param content [String] The content to search for
      # @return [Node, nil] The existing node or nil
      #
      def self.find_by_content(content)
        hash = generate_content_hash(content)
        find_by(content_hash: hash)
      end

      # Generate SHA-256 hash for content
      #
      # @param content [String] Content to hash
      # @return [String] 64-character hex hash
      #
      def self.generate_content_hash(content)
        Digest::SHA256.hexdigest(content.to_s)
      end

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

        # Validate embedding is an array of finite numeric values
        unless query_embedding.is_a?(Array) && query_embedding.all? { |v| v.is_a?(Numeric) && v.finite? }
          return nil
        end

        # Calculate cosine similarity: 1 - (embedding <=> query_embedding)
        # Safely format the array as a PostgreSQL vector literal
        vector_str = "[#{query_embedding.map { |v| v.to_f }.join(',')}]"
        conn = self.class.connection
        quoted_vector = conn.quote(vector_str)
        quoted_id = conn.quote(id)

        result = conn.select_value(
          "SELECT 1 - (embedding <=> #{quoted_vector}::vector) FROM nodes WHERE id = #{quoted_id}"
        )
        result&.to_f
      end

      # Get all tag names associated with this node
      #
      # @return [Array<String>] Array of hierarchical tag names (e.g., ["database:postgresql", "ai:llm"])
      #
      def tag_names
        tags.pluck(:name)
      end

      # Add tags to this node (creates tags if they don't exist)
      #
      # @param tag_names [Array<String>, String] Tag name(s) to add
      # @return [void]
      #
      # @example Add a single tag
      #   node.add_tags("database:postgresql")
      #
      # @example Add multiple tags
      #   node.add_tags(["database:postgresql", "ai:embeddings"])
      #
      def add_tags(tag_names)
        Array(tag_names).each do |tag_name|
          tag = HTM::Models::Tag.find_or_create_by(name: tag_name)
          node_tags.find_or_create_by(tag_id: tag.id)
        end
      end

      # Remove a tag from this node
      #
      # @param tag_name [String] Tag name to remove
      # @return [void]
      #
      def remove_tag(tag_name)
        tag = HTM::Models::Tag.find_by(name: tag_name)
        return unless tag

        node_tags.where(tag_id: tag.id).destroy_all
      end

      # Soft delete - mark node as deleted without removing from database
      #
      # @return [Boolean] true if soft deleted successfully
      #
      def soft_delete!
        update!(deleted_at: Time.current)
      end

      # Restore a soft-deleted node
      #
      # @return [Boolean] true if restored successfully
      #
      def restore!
        update!(deleted_at: nil)
      end

      # Check if node is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        deleted_at.present?
      end

      private

      def set_content_hash
        self.content_hash = self.class.generate_content_hash(content)
      end

      def set_defaults
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
