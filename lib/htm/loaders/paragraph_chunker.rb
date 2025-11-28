# frozen_string_literal: true

class HTM
  module Loaders
    # Paragraph-based text chunker
    #
    # Splits text into chunks based on paragraph boundaries (blank lines).
    # Preserves code blocks as single chunks to avoid breaking syntax.
    #
    # @example Basic usage
    #   chunker = ParagraphChunker.new
    #   chunks = chunker.chunk("First paragraph.\n\nSecond paragraph.")
    #   # => ["First paragraph.", "Second paragraph."]
    #
    # @example With code blocks
    #   text = "Intro\n\n```ruby\ndef foo\n  bar\nend\n```\n\nConclusion"
    #   chunks = chunker.chunk(text)
    #   # => ["Intro", "```ruby\ndef foo\n  bar\nend\n```", "Conclusion"]
    #
    class ParagraphChunker
      MIN_CHUNK_SIZE = 10  # Only merge very short fragments (single words)

      # Split text into paragraph chunks
      #
      # @param text [String] Text to chunk
      # @return [Array<String>] Array of paragraph chunks
      #
      def chunk(text)
        return [] if text.nil? || text.strip.empty?

        # Normalize line endings
        normalized = text.gsub(/\r\n?/, "\n")

        # Protect code blocks from splitting
        protected_text, code_blocks = protect_code_blocks(normalized)

        # Split by blank lines (2+ newlines)
        raw_chunks = protected_text.split(/\n\s*\n+/)

        # Restore code blocks and clean up
        chunks = raw_chunks.map do |chunk|
          restore_code_blocks(chunk.strip, code_blocks)
        end.reject(&:empty?)

        # Merge very short chunks with neighbors
        merge_short_chunks(chunks)
      end

      private

      # Replace code blocks with placeholders to prevent splitting
      #
      # @param text [String] Text containing code blocks
      # @return [Array(String, Hash)] Protected text and code block map
      #
      def protect_code_blocks(text)
        code_blocks = {}
        counter = 0

        # Match fenced code blocks (``` or ~~~)
        protected = text.gsub(/```[\s\S]*?```|~~~[\s\S]*?~~~/m) do |match|
          placeholder = "<<<CODE_BLOCK_#{counter}>>>"
          code_blocks[placeholder] = match
          counter += 1
          placeholder
        end

        [protected, code_blocks]
      end

      # Restore code blocks from placeholders
      #
      # @param text [String] Text with placeholders
      # @param code_blocks [Hash] Placeholder to code block mapping
      # @return [String] Text with code blocks restored
      #
      def restore_code_blocks(text, code_blocks)
        result = text
        code_blocks.each do |placeholder, block|
          result = result.gsub(placeholder, block)
        end
        result
      end

      # Merge chunks shorter than MIN_CHUNK_SIZE with neighbors
      #
      # @param chunks [Array<String>] Original chunks
      # @return [Array<String>] Merged chunks
      #
      def merge_short_chunks(chunks)
        return chunks if chunks.size <= 1

        result = []
        buffer = ''

        chunks.each do |chunk|
          if buffer.empty?
            buffer = chunk
          elsif buffer.length < MIN_CHUNK_SIZE
            buffer = "#{buffer}\n\n#{chunk}"
          else
            result << buffer
            buffer = chunk
          end
        end

        result << buffer unless buffer.empty?
        result
      end
    end
  end
end
