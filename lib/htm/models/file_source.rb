# frozen_string_literal: true

class HTM
  module Models
    # FileSource model - tracks loaded source files
    #
    # Represents a file that has been loaded into HTM with its metadata.
    # Each file can have multiple associated nodes (chunks).
    #
    # @example Find source by path
    #   source = FileSource.by_path('/path/to/doc.md').first
    #   source.chunks  # => [Node, Node, ...]
    #
    # @example Check if re-sync needed
    #   current_mtime = File.mtime('/path/to/doc.md')
    #   source.needs_sync?(current_mtime)  # => true/false
    #
    class FileSource < ActiveRecord::Base
      self.table_name = 'file_sources'

      # Tolerance for mtime comparison to avoid false positives from
      # precision differences between filesystem and database timestamps
      DELTA_TIME = 5  # seconds

      # Associations
      has_many :nodes, class_name: 'HTM::Models::Node',
               foreign_key: :source_id, dependent: :nullify

      # Validations
      validates :file_path, presence: true, uniqueness: true

      # Scopes
      scope :by_path, ->(path) { where(file_path: File.expand_path(path)) }
      scope :stale, -> { where('mtime < last_synced_at') }
      scope :recently_synced, -> { order(last_synced_at: :desc) }

      # Check if file needs re-sync based on mtime
      #
      # Uses DELTA_TIME tolerance to avoid false positives from:
      # - Nanosecond/microsecond precision differences (filesystem vs PostgreSQL)
      # - Floating-point rounding errors
      # - Minor timestamp discrepancies across systems
      #
      # @param current_mtime [Time, nil] Current file modification time (defaults to reading from filesystem)
      # @return [Boolean] true if file modification time differs by more than DELTA_TIME, or file doesn't exist
      #
      def needs_sync?(current_mtime = nil)
        return true if mtime.nil?
        return true unless File.exist?(file_path)

        current_mtime ||= File.mtime(file_path)
        (current_mtime.to_i - mtime.to_i).abs > DELTA_TIME
      end

      # Get ordered chunks from this file
      #
      # @return [ActiveRecord::Relation] Nodes ordered by chunk_position
      #
      def chunks
        nodes.order(:chunk_position)
      end

      # Extract tags from frontmatter
      #
      # @return [Array<String>] Tag names from frontmatter 'tags' field
      #
      def frontmatter_tags
        return [] unless frontmatter.is_a?(Hash)

        tags = frontmatter['tags'] || frontmatter[:tags] || []
        Array(tags).map(&:to_s)
      end

      # Get title from frontmatter
      #
      # @return [String, nil] Title from frontmatter
      #
      def title
        return nil unless frontmatter.is_a?(Hash)
        frontmatter['title'] || frontmatter[:title]
      end

      # Get author from frontmatter
      #
      # @return [String, nil] Author from frontmatter
      #
      def author
        return nil unless frontmatter.is_a?(Hash)
        frontmatter['author'] || frontmatter[:author]
      end

      # Soft delete all chunks from this file
      #
      # @return [Integer] Number of chunks soft-deleted
      #
      def soft_delete_chunks!
        nodes.update_all(deleted_at: Time.current)
      end
    end
  end
end
