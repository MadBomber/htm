# frozen_string_literal: true

class HTM
  module Models
    # FileSource model - tracks loaded source files
    #
    # Represents a file that has been loaded into HTM with its metadata.
    # Each file can have multiple associated nodes (chunks).
    #
    class FileSource < Sequel::Model(:file_sources)
      # Tolerance for mtime comparison to avoid false positives from
      # precision differences between filesystem and database timestamps
      DELTA_TIME = 5  # seconds

      # Associations
      one_to_many :nodes, class: 'HTM::Models::Node', key: :source_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence :file_path
        validates_unique :file_path
      end

      # Dataset methods (scopes)
      dataset_module do
        def by_path(path)
          where(file_path: File.expand_path(path))
        end

        def stale
          where(Sequel.lit('mtime < last_synced_at'))
        end

        def recently_synced
          order(Sequel.desc(:last_synced_at))
        end
      end

      # Check if file needs re-sync based on mtime
      #
      # @param current_mtime [Time, nil] Current file modification time
      # @return [Boolean] true if file needs re-sync
      #
      def needs_sync?(current_mtime = nil)
        return true if mtime.nil?
        return true unless File.exist?(file_path)

        current_mtime ||= File.mtime(file_path)
        (current_mtime.to_i - mtime.to_i).abs > DELTA_TIME
      end

      # Get ordered chunks from this file
      #
      # @return [Array<Node>] Nodes ordered by chunk_position
      #
      def chunks
        nodes_dataset.order(:chunk_position).all
      end

      # Alias for nodes_dataset - used for consistency with "chunks" terminology
      #
      # @return [Sequel::Dataset] Dataset of nodes from this file
      #
      def chunks_dataset
        nodes_dataset
      end

      # Extract tags from frontmatter
      #
      # @return [Array<String>] Tag names from frontmatter 'tags' field
      #
      def frontmatter_tags
        return [] unless frontmatter_hash?

        tags = frontmatter['tags'] || frontmatter[:tags] || []
        Array(tags).map(&:to_s)
      end

      # Get title from frontmatter
      #
      # @return [String, nil] Title from frontmatter
      #
      def title
        return nil unless frontmatter_hash?
        frontmatter['title'] || frontmatter[:title]
      end

      # Get author from frontmatter
      #
      # @return [String, nil] Author from frontmatter
      #
      def author
        return nil unless frontmatter_hash?
        frontmatter['author'] || frontmatter[:author]
      end

      # Soft delete all chunks from this file
      #
      # @return [Integer] Number of chunks soft-deleted
      #
      def soft_delete_chunks!
        nodes_dataset.update(deleted_at: Time.now)
      end

      private

      # Check if frontmatter is a hash-like object
      # Sequel::Postgres::JSONBHash doesn't inherit from Hash but acts like one
      #
      # @return [Boolean]
      #
      def frontmatter_hash?
        frontmatter.respond_to?(:[]) && frontmatter.respond_to?(:key?)
      end
    end
  end
end
