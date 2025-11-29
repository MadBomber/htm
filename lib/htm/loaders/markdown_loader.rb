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
      def initialize(htm_instance)
        @htm = htm_instance
        @chunker = ParagraphChunker.new
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
        expanded_path = File.expand_path(path)

        unless File.exist?(expanded_path)
          raise ArgumentError, "File not found: #{path}"
        end

        unless File.file?(expanded_path)
          raise ArgumentError, "Not a file: #{path}"
        end

        # Validate file size before reading
        file_size = File.size(expanded_path)
        if file_size > MAX_FILE_SIZE
          raise ArgumentError, "File too large: #{path} (#{file_size} bytes). Maximum size is #{MAX_FILE_SIZE} bytes (10 MB)."
        end

        # Read file with encoding detection and fallback
        # Try UTF-8 first, then fall back to binary if encoding errors occur
        begin
          content = File.read(expanded_path, encoding: 'UTF-8')
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
          # Try reading as binary and force encoding to UTF-8, replacing invalid chars
          content = File.read(expanded_path, encoding: 'BINARY')
          content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
          HTM.logger.warn "File #{path} has non-UTF-8 encoding, some characters may be replaced"
        end
        stat = File.stat(expanded_path)
        file_hash = Digest::SHA256.hexdigest(content)

        # Find or create source record
        source = HTM::Models::FileSource.find_or_initialize_by(file_path: expanded_path)

        # Check if sync needed
        unless force || source.new_record? || source.needs_sync?(stat.mtime)
          return {
            file_path: expanded_path,
            chunks_created: 0,
            chunks_updated: 0,
            chunks_deleted: 0,
            skipped: true
          }
        end

        # Parse frontmatter and body
        frontmatter, body = extract_frontmatter(content)

        # Chunk the body
        chunks = @chunker.chunk(body)

        # Prepend frontmatter to first chunk if present
        if frontmatter.any? && chunks.any?
          frontmatter_yaml = YAML.dump(frontmatter).sub(/\A---\n/, "---\n")
          chunks[0] = "#{frontmatter_yaml}---\n\n#{chunks[0]}"
        end

        # Save source first (need ID for node association)
        source.save! if source.new_record?

        # Sync chunks to database
        result = sync_chunks(source, chunks)

        # Update source record
        source.update!(
          file_hash: file_hash,
          mtime: stat.mtime,
          file_size: stat.size,
          frontmatter: frontmatter,
          last_synced_at: Time.current
        )

        result.merge(
          file_path: expanded_path,
          file_source_id: source.id,
          skipped: false
        )
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
          begin
            load_file(file_path, force: force)
          rescue StandardError => e
            { file_path: file_path, error: e.message, skipped: false }
          end
        end
      end

      private

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
      # @param chunks [Array<String>] New chunk contents
      # @return [Hash] Sync statistics
      #
      def sync_chunks(source, chunks)
        created = 0
        updated = 0
        deleted = 0

        # Get existing nodes for this source (include soft-deleted for potential restore)
        existing_nodes = source.persisted? ?
          HTM::Models::Node.unscoped.where(source_id: source.id).to_a : []
        existing_by_hash = existing_nodes.index_by(&:content_hash)

        # Track which existing nodes we've matched
        matched_hashes = Set.new

        # Process each new chunk
        chunks.each_with_index do |chunk_content, position|
          chunk_hash = HTM::Models::Node.generate_content_hash(chunk_content)

          if existing_by_hash[chunk_hash]
            # Chunk exists - update position if needed, restore if soft-deleted
            node = existing_by_hash[chunk_hash]
            matched_hashes << chunk_hash

            changes = {}
            changes[:chunk_position] = position if node.chunk_position != position
            changes[:deleted_at] = nil if node.deleted_at.present?

            if changes.any?
              node.update!(changes)
              updated += 1
            end
          else
            # New chunk - create node
            node = create_chunk_node(source, chunk_content, position)
            created += 1 if node
          end
        end

        # Soft-delete chunks that no longer exist in file
        existing_by_hash.each do |hash, node|
          next if matched_hashes.include?(hash)
          next if node.deleted_at.present?  # Already deleted

          node.soft_delete!
          deleted += 1
        end

        { chunks_created: created, chunks_updated: updated, chunks_deleted: deleted }
      end

      # Create a node for a chunk
      #
      # @param source [FileSource] The source record
      # @param content [String] Chunk content
      # @param position [Integer] Position in file (0-indexed)
      # @return [Node, nil] The created node or nil if duplicate
      #
      def create_chunk_node(source, content, position)
        # Use remember to get proper embedding/tag processing
        node_id = @htm.remember(content)

        # Update with source reference
        node = HTM::Models::Node.find(node_id)
        node.update!(source_id: source.id, chunk_position: position)

        node
      rescue ActiveRecord::RecordNotUnique
        # Duplicate content exists (different source or no source)
        # Find and link to this source
        existing = HTM::Models::Node.find_by_content(content)
        if existing && existing.source_id.nil?
          existing.update!(source_id: source.id, chunk_position: position)
        end
        existing
      end
    end
  end
end
