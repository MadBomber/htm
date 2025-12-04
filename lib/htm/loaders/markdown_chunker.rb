# frozen_string_literal: true

require 'baran'

class HTM
  module Loaders
    # Markdown-aware text chunker using Baran
    #
    # Wraps Baran::MarkdownSplitter to provide intelligent text chunking
    # that respects markdown structure (headers, code blocks, etc.).
    #
    # @example Basic usage
    #   chunker = MarkdownChunker.new
    #   chunks = chunker.chunk("# Header\n\nParagraph text.\n\n## Subheader\n\nMore text.")
    #   # => ["# Header\n\nParagraph text.", "## Subheader\n\nMore text."]
    #
    # @example With custom chunk size
    #   chunker = MarkdownChunker.new(chunk_size: 512, chunk_overlap: 50)
    #   chunks = chunker.chunk(long_text)
    #
    # @example With full metadata (includes cursor positions)
    #   chunker = MarkdownChunker.new
    #   chunks = chunker.chunk_with_metadata(text)
    #   # => [{ text: "...", cursor: 0, metadata: nil }, { text: "...", cursor: 156, metadata: nil }]
    #
    class MarkdownChunker
      # @param chunk_size [Integer] Maximum characters per chunk (default: from config or 1024)
      # @param chunk_overlap [Integer] Character overlap between chunks (default: from config or 64)
      def initialize(chunk_size: nil, chunk_overlap: nil)
        @chunk_size = chunk_size || HTM.configuration.chunk_size
        @chunk_overlap = chunk_overlap || HTM.configuration.chunk_overlap

        @splitter = Baran::MarkdownSplitter.new(
          chunk_size: @chunk_size,
          chunk_overlap: @chunk_overlap
        )
      end

      # Split text into markdown-aware chunks (text only)
      #
      # @param text [String] Text to chunk
      # @return [Array<String>] Array of text chunks
      #
      def chunk(text)
        return [] if text.nil? || text.strip.empty?

        # Normalize line endings
        normalized = text.gsub(/\r\n?/, "\n")

        # Use Baran's MarkdownSplitter
        result = @splitter.chunks(normalized)

        # Extract text from chunk hashes, filter empty
        result.map { |chunk| chunk[:text].strip }.reject(&:empty?)
      end

      # Split text and return full chunk data (with cursor positions)
      #
      # Returns Baran's full output including:
      # - :text [String] The chunk content
      # - :cursor [Integer] Character offset where chunk starts in original text
      #
      # @param text [String] Text to chunk
      # @return [Array<Hash>] Array of chunk hashes with :text and :cursor
      #
      def chunk_with_metadata(text)
        return [] if text.nil? || text.strip.empty?

        # Normalize line endings
        normalized = text.gsub(/\r\n?/, "\n")

        # Use Baran's MarkdownSplitter - returns [{text:, cursor:}, ...]
        @splitter.chunks(normalized)
      end

      attr_reader :chunk_size, :chunk_overlap
    end
  end
end
