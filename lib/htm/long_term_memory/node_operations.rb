# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Node CRUD operations for LongTermMemory
    #
    # Handles creating, reading, updating, and deleting memory nodes with:
    # - Content deduplication via SHA-256 hash
    # - Soft delete restoration on duplicate content
    # - Robot-node linking with remember tracking
    # - Bulk access tracking
    #
    module NodeOperations
      # Add a node to long-term memory (with deduplication)
      #
      # If content already exists (by content_hash), links the robot to the existing
      # node and updates timestamps. Otherwise creates a new node.
      #
      # @param content [String] Conversation message/utterance
      # @param token_count [Integer] Token count
      # @param robot_id [Integer] Robot identifier
      # @param embedding [Array<Float>, nil] Pre-generated embedding vector
      # @param metadata [Hash] Flexible metadata for the node (default: {})
      # @return [Hash] { node_id:, is_new:, robot_node: }
      # @raise [ArgumentError] If metadata is not a Hash
      #
      def add(content:, token_count: 0, robot_id:, embedding: nil, metadata: {})
        # Validate metadata parameter
        unless metadata.is_a?(Hash)
          raise ArgumentError, "metadata must be a Hash, got #{metadata.class}"
        end
        content_hash = HTM::Models::Node.generate_content_hash(content)

        # Wrap in transaction to ensure data consistency
        HTM.db.transaction do
          # Check for existing node with same content (including soft-deleted)
          # This avoids unique constraint violations on content_hash
          existing_node = HTM::Models::Node.with_deleted.first(content_hash: content_hash)

          # If found but soft-deleted, restore it
          if existing_node&.deleted?
            existing_node.restore!
            HTM.logger.info "Restored soft-deleted node #{existing_node.id} for content match"
          end

          if existing_node
            # Link robot to existing node (or update if already linked)
            robot_node = link_robot_to_node(robot_id: robot_id, node: existing_node)

            # Update the node's updated_at timestamp
            existing_node.update(updated_at: Time.now)

            {
              node_id: existing_node.id,
              is_new: false,
              robot_node: robot_node
            }
          else
            # Prepare embedding if provided
            embedding_str = nil
            if embedding
              # Use centralized padding and sanitization
              padded_embedding = HTM::SqlBuilder.pad_embedding(embedding)
              embedding_str = HTM::SqlBuilder.sanitize_embedding(padded_embedding)
            end

            # Create new node
            node = HTM::Models::Node.create(
              content: content,
              content_hash: content_hash,
              token_count: token_count,
              embedding: embedding_str,
              metadata: metadata
            )

            # Link robot to new node
            robot_node = link_robot_to_node(robot_id: robot_id, node: node)

            # Selectively invalidate search-related cache entries only
            # (preserves unrelated cached data like tag queries)
            @cache&.invalidate_methods!(:search, :fulltext, :hybrid)

            {
              node_id: node.id,
              is_new: true,
              robot_node: robot_node
            }
          end
        end
      end

      # Link a robot to a node (create or update robot_node record)
      #
      # @param robot_id [Integer] Robot ID
      # @param node [HTM::Models::Node] Node to link
      # @param working_memory [Boolean] Whether node is in working memory (default: false)
      # @return [HTM::Models::RobotNode] The robot_node link record
      #
      def link_robot_to_node(robot_id:, node:, working_memory: false)
        robot_node = HTM::Models::RobotNode.first(robot_id: robot_id, node_id: node.id)

        if robot_node
          # Existing link - record that robot remembered this again
          robot_node.record_remember!
          robot_node.update(working_memory: working_memory) if working_memory
        else
          # New link
          robot_node = HTM::Models::RobotNode.create(
            robot_id: robot_id,
            node_id: node.id,
            first_remembered_at: Time.now,
            last_remembered_at: Time.now,
            remember_count: 1,
            working_memory: working_memory
          )
        end

        robot_node
      end

      # Retrieve a node by ID
      #
      # Automatically tracks access by incrementing access_count and updating last_accessed.
      # Uses a single UPDATE query instead of separate increment! and touch calls.
      #
      # @param node_id [Integer] Node database ID
      # @return [Hash, nil] Node data or nil
      #
      def retrieve(node_id)
        node = HTM::Models::Node.first(id: node_id)
        return nil unless node

        # Track access in a single UPDATE query (instead of separate operations)
        node.this.update(
          access_count: Sequel[:access_count] + 1,
          last_accessed: Time.now
        )

        # Reload to get updated values
        node.refresh.to_hash
      end

      # Update last_accessed timestamp
      #
      # @param node_id [Integer] Node database ID
      # @return [void]
      #
      def update_last_accessed(node_id)
        node = HTM::Models::Node.first(id: node_id)
        node&.update(last_accessed: Time.now)
      end

      # Delete a node
      #
      # @param node_id [Integer] Node database ID
      # @return [void]
      #
      def delete(node_id)
        node = HTM::Models::Node.first(id: node_id)
        node&.delete

        # Selectively invalidate search-related cache entries only
        @cache&.invalidate_methods!(:search, :fulltext, :hybrid)
      end

      # Check if a node exists
      #
      # @param node_id [Integer] Node database ID
      # @return [Boolean] True if node exists
      #
      def exists?(node_id)
        HTM::Models::Node.where(id: node_id).count > 0
      end

      # Mark nodes as evicted from working memory
      #
      # Sets working_memory = false on the robot_nodes join table for the specified
      # robot and node IDs.
      #
      # @param robot_id [Integer] Robot ID whose working memory is being evicted
      # @param node_ids [Array<Integer>] Node IDs to mark as evicted
      # @return [void]
      #
      def mark_evicted(robot_id:, node_ids:)
        return if node_ids.empty?

        HTM::Models::RobotNode
          .where(robot_id: robot_id, node_id: node_ids)
          .update(working_memory: false)
      end

      # Track access for multiple nodes (bulk operation)
      #
      # Updates access_count and last_accessed for all nodes in the array
      #
      # @param node_ids [Array<Integer>] Node IDs that were accessed
      # @return [void]
      #
      def track_access(node_ids)
        return if node_ids.empty?

        # Atomic batch update
        HTM::Models::Node.where(id: node_ids).update(
          access_count: Sequel[:access_count] + 1,
          last_accessed: Sequel.lit('NOW()')
        )
      end
    end
  end
end
