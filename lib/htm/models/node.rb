# frozen_string_literal: true

require 'digest'

class HTM
  module Models
    # Node model - represents a memory node (conversation message)
    #
    # Nodes are globally unique by content (via content_hash) and can be
    # linked to multiple robots through the robot_nodes join table.
    #
    class Node < Sequel::Model(:nodes)
      # Associations
      one_to_many :robot_nodes, class: 'HTM::Models::RobotNode', key: :node_id
      many_to_many :robots, class: 'HTM::Models::Robot',
                   join_table: :robot_nodes, left_key: :node_id, right_key: :robot_id
      one_to_many :node_tags, class: 'HTM::Models::NodeTag', key: :node_id
      many_to_many :tags, class: 'HTM::Models::Tag',
                   join_table: :node_tags, left_key: :node_id, right_key: :tag_id

      # Optional source file association (for nodes loaded from files)
      many_to_one :file_source, class: 'HTM::Models::FileSource', key: :source_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Override embedding getter to return Array instead of String
      # pgvector stores as string format "[0.1,0.2,...]" and we need Array<Float>
      def embedding
        raw = super
        return nil if raw.nil?
        return raw if raw.is_a?(Array)

        # Parse string format: "[0.1,0.2,0.3]"
        if raw.is_a?(String)
          raw.gsub(/[\[\]]/, '').split(',').map(&:to_f)
        else
          raw.to_a
        end
      end

      # Validations
      def validate
        super
        validates_presence [:content, :content_hash]
        validates_unique :content_hash
      end

      # Dataset methods (scopes)
      dataset_module do
        def active
          where(deleted_at: nil)
        end

        def by_robot(robot_id)
          join(:robot_nodes, node_id: :id).where(robot_nodes__robot_id: robot_id)
        end

        def recent
          order(Sequel.desc(:created_at))
        end

        def in_timeframe(start_time, end_time)
          where(created_at: start_time..end_time)
        end

        def with_embeddings
          exclude(embedding: nil)
        end

        def from_source(source_id)
          where(source_id: source_id).order(:chunk_position)
        end

        # Proposition scopes
        def propositions
          where(Sequel.lit("metadata->>'is_proposition' = 'true'"))
        end

        def non_propositions
          where(Sequel.lit("metadata IS NULL OR metadata->>'is_proposition' IS NULL OR metadata->>'is_proposition' != 'true'"))
        end

        # Soft delete scopes
        def deleted
          exclude(deleted_at: nil)
        end

        def with_deleted
          unfiltered
        end

        def deleted_before(time)
          deleted.where { deleted_at < time }
        end

        # Find nearest neighbors by vector similarity
        #
        # @param column [Symbol] Column containing the embedding (typically :embedding)
        # @param query_embedding [Array<Numeric>] Query vector to find neighbors for
        # @param distance [String] Distance metric ("cosine", "euclidean", "inner_product")
        # @return [Sequel::Dataset] Dataset ordered by distance with neighbor_distance column
        #
        def nearest_neighbors(column, query_embedding, distance: "cosine")
          return where(Sequel.lit('1=0')) unless query_embedding.is_a?(Array) && query_embedding.any?

          # Convert embedding to vector string format
          vector_str = "[#{query_embedding.map(&:to_f).join(',')}]"

          # Select distance operator based on metric
          operator = case distance.to_s
                     when "cosine" then "<=>"
                     when "euclidean", "l2" then "<->"
                     when "inner_product" then "<#>"
                     else "<=>"
                     end

          # Return dataset with distance calculation
          select_all(:nodes)
            .select_append(Sequel.lit("(#{column} #{operator} ?::vector) AS neighbor_distance", vector_str))
            .exclude(column => nil)
            .order(Sequel.lit("#{column} #{operator} ?::vector", vector_str))
        end
      end

      # Apply default scope for active records
      set_dataset(dataset.where(Sequel[:nodes][:deleted_at] => nil))

      # Hooks
      def before_validation
        if content_hash.nil? && content
          self.content_hash = self.class.generate_content_hash(content)
        end
        super
      end

      def before_create
        self.created_at ||= Time.now
        self.updated_at ||= Time.now
        self.last_accessed ||= Time.now
        super
      end

      def before_save
        self.updated_at = Time.now if changed_columns.any?
        super
      end

      # Class methods

      # Permanently delete all soft-deleted nodes older than the specified time
      #
      # @param older_than [Time] Delete nodes soft-deleted before this time
      # @return [Integer] Number of nodes permanently deleted
      #
      def self.purge_deleted(older_than:)
        dataset.unfiltered.where { deleted_at < older_than }.delete
      end

      # Find a node by content hash, or return nil
      #
      # @param content [String] The content to search for
      # @return [Node, nil] The existing node or nil
      #
      def self.find_by_content(content)
        hash = generate_content_hash(content)
        first(content_hash: hash)
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
      #
      # @param limit [Integer] number of neighbors to return (default: 10)
      # @param distance [String] distance metric (default: "cosine")
      # @return [Array<Node>] ordered by distance (closest first)
      #
      def nearest_neighbors(limit: 10, distance: "cosine")
        return [] unless embedding

        # Use raw SQL for vector similarity search
        db = self.class.db

        # Handle embedding - might be String or Array depending on Sequel pg extension
        emb = embedding_array
        return [] if emb.nil? || emb.empty?

        vector_str = "[#{emb.join(',')}]"

        sql = <<-SQL
          SELECT nodes.*, (embedding <=> '#{vector_str}'::vector) AS neighbor_distance
          FROM nodes
          WHERE embedding IS NOT NULL
            AND deleted_at IS NULL
            AND id != #{id}
          ORDER BY embedding <=> '#{vector_str}'::vector
          LIMIT #{limit}
        SQL

        # Use call() to create instances from raw hashes without mass assignment restrictions
        db.fetch(sql).all.map do |row|
          node = self.class.call(row)
          # Store neighbor_distance as an instance variable
          node.instance_variable_set(:@neighbor_distance, row[:neighbor_distance])
          node
        end
      end

      # Accessor for neighbor_distance from nearest_neighbors query
      # Works with both:
      # - Instance method (stores in @neighbor_distance)
      # - Dataset method (stores in values hash from SELECT)
      def neighbor_distance
        @neighbor_distance || values[:neighbor_distance]
      end

      # Get embedding as an Array (handles both String and Array storage)
      # Note: The `embedding` getter already returns Array, this is an alias for compatibility
      #
      # @return [Array<Float>, nil] The embedding vector as an array
      #
      def embedding_array
        embedding
      end

      # Calculate cosine similarity to another embedding or node
      #
      # @param other [Array, Node] query embedding vector or another Node
      # @return [Float] similarity score (0.0 to 1.0, higher is more similar)
      #
      def similarity_to(other)
        query_embedding = other.is_a?(Node) ? other.embedding_array : other
        return nil unless embedding_array && query_embedding

        # Handle query_embedding that might be a String
        if query_embedding.is_a?(String)
          query_embedding = query_embedding.gsub(/[\[\]]/, '').split(',').map(&:to_f)
        end

        unless query_embedding.is_a?(Array) && query_embedding.all? { |v| v.is_a?(Numeric) && v.finite? }
          return nil
        end

        vector_str = "[#{query_embedding.map(&:to_f).join(',')}]"

        result = self.class.db.fetch(
          "SELECT 1 - (embedding <=> ?::vector) AS similarity FROM nodes WHERE id = ?",
          vector_str, id
        ).first

        result&.[](:similarity)&.to_f
      end

      # Get all tag names associated with this node
      #
      # @return [Array<String>] Array of hierarchical tag names
      #
      def tag_names
        tags_dataset.select_map(:name)
      end

      # Add tags to this node (creates tags and all parent tags if they don't exist)
      #
      # @param tag_names [Array<String>, String] Tag name(s) to add
      # @return [void]
      #
      def add_tags(tag_names)
        Array(tag_names).each do |tag_name|
          HTM::Models::Tag.find_or_create_with_ancestors(tag_name).each do |tag|
            HTM::Models::NodeTag.find_or_create(node_id: id, tag_id: tag.id)
          end
        end
      end

      # Remove a tag from this node
      #
      # @param tag_name [String] Tag name to remove
      # @return [void]
      #
      def remove_tag(tag_name)
        tag = HTM::Models::Tag.first(name: tag_name)
        return unless tag

        node_tags_dataset.where(tag_id: tag.id).delete
      end

      # Soft delete - mark node as deleted without removing from database
      #
      # @return [Boolean] true if soft deleted successfully
      #
      def soft_delete!
        db.transaction do
          now = Time.now
          update(deleted_at: now)

          # Cascade soft delete to associated robot_nodes
          HTM::Models::RobotNode.where(node_id: id).update(deleted_at: now)

          # Cascade soft delete to associated node_tags
          HTM::Models::NodeTag.where(node_id: id).update(deleted_at: now)
        end
        true
      end

      # Restore a soft-deleted node
      #
      # @return [Boolean] true if restored successfully
      #
      def restore!
        db.transaction do
          # Use unfiltered dataset to bypass the default scope that excludes deleted records
          self.class.dataset.unfiltered.where(id: id).update(deleted_at: nil)

          # Cascade restoration to associated robot_nodes
          HTM::Models::RobotNode.dataset.unfiltered.where(node_id: id).update(deleted_at: nil)

          # Cascade restoration to associated node_tags
          HTM::Models::NodeTag.dataset.unfiltered.where(node_id: id).update(deleted_at: nil)

          # Refresh this instance to reflect the change
          self.deleted_at = nil
        end
        true
      end

      # Check if node is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        !deleted_at.nil?
      end

      # Check if node is a proposition (extracted atomic fact)
      #
      # @return [Boolean] true if metadata['is_proposition'] is true
      #
      def proposition?
        metadata&.dig('is_proposition') == true
      end

      # Convert to hash (for compatibility with existing code)
      #
      # @return [Hash] Hash representation of the node
      #
      def to_hash
        values.transform_keys(&:to_s)
      end
      alias_method :attributes, :to_hash
    end
  end
end
