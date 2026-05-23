# frozen_string_literal: true

require 'yaml'
require 'digest'

class HTM
  module Loaders
    # Markdown file loader
    #
    # Loads markdown files into HTM long-term memory with support for:
    # - YAML frontmatter parsing (stored as metadata on first chunk)
    # - Paragraph-based chunking
    # - Re-sync on file changes (via mtime comparison)
    # - Duplicate detection via content_hash
    #
    # @example Load a single file
    #   loader = MarkdownLoader.new(htm)
    #   result = loader.load_file('/path/to/doc.md')
    #   # => { file_path: '/path/to/doc.md', chunks_created: 5, ... }
    #
    # @example Load a directory
    #   results = loader.load_directory('/path/to/docs', pattern: '**/*.md')
    #
    class MarkdownLoader
      FRONTMATTER_REGEX = /\A---\s*\n(.*?)\n---\s*\n/m
      MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB maximum file size

      # @param htm_instance [HTM] The HTM instance to use for storing nodes
      # @param chunk_size [Integer] Maximum characters per chunk (default: from config)
      # @param chunk_overlap [Integer] Character overlap between chunks (default: from config)
      def initialize(htm_instance, chunk_size: nil, chunk_overlap: nil)
        @htm = htm_instance
        @chunker = MarkdownChunker.new(
          chunk_size: chunk_size,
          chunk_overlap: chunk_overlap
        )
      end

      # Load a single markdown file into long-term memory
      #
      # @param path [String] Path to markdown file
      # @param force [Boolean] Force re-sync even if mtime unchanged
      # @return [Hash] Load result with keys:
      #   - :file_path [String] Absolute path to file
      #   - :chunks_created [Integer] Number of new chunks created
      #   - :chunks_updated [Integer] Number of existing chunks updated
      #   - :chunks_deleted [Integer] Number of chunks soft-deleted
      #   - :skipped [Boolean] True if file was unchanged and skipped
      #
      def load_file(path, force: false)
        expanded_path = validate_file_path!(path)
        content       = read_file_content(expanded_path, path)
        stat          = File.stat(expanded_path)
        file_hash     = Digest::SHA256.hexdigest(content)

        source = HTM::Models::FileSource.first(file_path: expanded_path)
        is_new = source.nil?
        source ||= HTM::Models::FileSource.new(file_path: expanded_path)

        unless force || is_new || source.needs_sync?(stat.mtime)
          return { file_path: expanded_path, chunks_created: 0, chunks_updated: 0, chunks_deleted: 0, skipped: true }
        end

        frontmatter, body = extract_frontmatter(content)
        chunks = @chunker.chunk_with_metadata(body)
        prepend_frontmatter_to_chunk(frontmatter, chunks)

        source.save if is_new
        result = sync_chunks(source, chunks)
        source.update(file_hash: file_hash, mtime: stat.mtime, file_size: stat.size,
                      frontmatter: frontmatter, last_synced_at: Time.now)
        result.merge(file_path: expanded_path, file_source_id: source.id, skipped: false)
      end

      # Load all matching files from a directory
      #
      # @param path [String] Directory path
      # @param pattern [String] Glob pattern (default: '**/*.md')
      # @param force [Boolean] Force re-sync even if unchanged
      # @return [Array<Hash>] Results for each file
      #
      def load_directory(path, pattern: '**/*.md', force: false)
        expanded_path = File.expand_path(path)

        unless File.exist?(expanded_path)
          raise ArgumentError, "Directory not found: #{path}"
        end

        unless File.directory?(expanded_path)
          raise ArgumentError, "Not a directory: #{path}"
        end

        files = Dir.glob(File.join(expanded_path, pattern))

        files.map do |file_path|
          load_file(file_path, force: force)
        rescue StandardError => e
          { file_path: file_path, error: e.message, skipped: false }
        end
      end

      private

      def validate_file_path!(path)
        expanded = File.expand_path(path)
        raise ArgumentError, "File not found: #{path}"   unless File.exist?(expanded)
        raise ArgumentError, "Not a file: #{path}"       unless File.file?(expanded)
        size = File.size(expanded)
        if size > MAX_FILE_SIZE
          raise ArgumentError, "File too large: #{path} (#{size} bytes). Maximum size is #{MAX_FILE_SIZE} bytes (10 MB)."
        end
        expanded
      end

      def read_file_content(expanded_path, path)
        File.read(expanded_path, encoding: 'UTF-8')
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        content = File.read(expanded_path, encoding: 'BINARY')
        HTM.logger.warn "File #{path} has non-UTF-8 encoding, some characters may be replaced"
        content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end

      def prepend_frontmatter_to_chunk(frontmatter, chunks)
        return unless frontmatter.any? && chunks.any?
        frontmatter_yaml = YAML.dump(frontmatter).sub(/\A---\n/, "---\n")
        chunks[0][:text] = "#{frontmatter_yaml}---\n\n#{chunks[0][:text]}"
      end

      def update_existing_chunk(node, position, chunk_cursor)
        changes = {}
        changes[:chunk_position] = position              if node.chunk_position != position
        changes[:deleted_at]     = nil                   if node.deleted_at
        current_cursor = node.metadata&.dig('cursor')
        changes[:metadata] = (node.metadata || {}).merge('cursor' => chunk_cursor) if current_cursor != chunk_cursor
        return false unless changes.any?
        node.update(changes)
        true
      end

      def soft_delete_removed_chunks(existing_by_hash, matched_hashes)
        count = 0
        existing_by_hash.each_value do |node|
          next if matched_hashes.include?(node.content_hash) || node.deleted_at
          node.soft_delete!
          count += 1
        end
        count
      end

      # Extract YAML frontmatter from content
      #
      # @param content [String] File content
      # @return [Array(Hash, String)] Frontmatter hash and body string
      #
      def extract_frontmatter(content)
        match = content.match(FRONTMATTER_REGEX)

        if match
          yaml_content = match[1]
          body = content[match.end(0)..]

          begin
            frontmatter = YAML.safe_load(yaml_content, permitted_classes: [Date, Time, Symbol]) || {}
            # Convert symbol keys to strings
            frontmatter = frontmatter.transform_keys(&:to_s) if frontmatter.is_a?(Hash)
          rescue Psych::SyntaxError
            frontmatter = {}
          end
        else
          frontmatter = {}
          body = content
        end

        [frontmatter, body]
      end

      # Sync chunks to database, handling updates and deletions
      #
      # @param source [FileSource] The source record
      # @param chunks [Array<Hash>] New chunks with :text and :cursor keys
      # @return [Hash] Sync statistics
      #
      def sync_chunks(source, chunks)
        created = 0
        updated = 0
        existing_nodes   = source.id ? HTM::Models::Node.with_deleted.where(source_id: source.id).all : []
        existing_by_hash = existing_nodes.to_h { |n| [n.content_hash, n] }
        matched_hashes   = Set.new

        chunks.each_with_index do |chunk_data, position|
          chunk_content = chunk_data[:text].strip
          next if chunk_content.empty?

          chunk_hash = HTM::Models::Node.generate_content_hash(chunk_content)
          if existing_by_hash[chunk_hash]
            matched_hashes << chunk_hash
            updated += 1 if update_existing_chunk(existing_by_hash[chunk_hash], position, chunk_data[:cursor])
          elsif create_chunk_node(source, chunk_content, position, cursor: chunk_data[:cursor])
            created += 1
          end
        end

        deleted = soft_delete_removed_chunks(existing_by_hash, matched_hashes)
        { chunks_created: created, chunks_updated: updated, chunks_deleted: deleted }
      end

      # Create a node for a chunk
      #
      # @param source [FileSource] The source record
      # @param content [String] Chunk content
      # @param position [Integer] Position in file (0-indexed)
      # @param cursor [Integer] Character offset in original file
      # @return [Node, nil] The created node or nil if duplicate
      #
      def create_chunk_node(source, content, position, cursor: nil)
        # Build metadata with cursor position (file path is in source, not duplicated here)
        chunk_metadata = cursor ? { 'cursor' => cursor } : {}

        # Use remember to get proper embedding/tag processing
        node_id = @htm.remember(content, metadata: chunk_metadata)

        # Update with source reference
        node = HTM::Models::Node[node_id]
        node.update(source_id: source.id, chunk_position: position)

        node
      rescue Sequel::UniqueConstraintViolation
        # Duplicate content exists (different source or no source)
        # Find and link to this source
        existing = HTM::Models::Node.find_by_content(content)
        if existing && existing.source_id.nil?
          # Merge cursor into existing metadata
          new_metadata = (existing.metadata || {}).merge('cursor' => cursor) if cursor
          existing.update(
            source_id: source.id,
            chunk_position: position,
            metadata: new_metadata || existing.metadata
          )
        end
        existing
      end
    end
  end
end
