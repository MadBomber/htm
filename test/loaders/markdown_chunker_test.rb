# frozen_string_literal: true

require_relative '../test_helper'

class MarkdownChunkerTest < Minitest::Test
  def setup
    # Use small chunk size and overlap for testing
    @chunker = HTM::Loaders::MarkdownChunker.new(chunk_size: 100, chunk_overlap: 10)
  end

  def test_chunks_text_by_markdown_structure
    text = "# Header\n\nFirst paragraph.\n\n## Subheader\n\nSecond paragraph."
    chunks = @chunker.chunk(text)

    # Should produce at least one chunk
    assert chunks.size >= 1
    # All content should be preserved across chunks
    combined = chunks.join("\n")
    assert_includes combined, "Header"
    assert_includes combined, "First paragraph"
    assert_includes combined, "Second paragraph"
  end

  def test_preserves_code_blocks
    text = <<~MD
      Introduction paragraph.

      ```ruby
      def foo
        bar
      end
      ```

      Conclusion paragraph.
    MD

    chunks = @chunker.chunk(text)

    # Should produce multiple chunks
    assert chunks.size >= 1
    # Code should be preserved somewhere
    combined = chunks.join("\n")
    assert_includes combined, "```ruby"
    assert_includes combined, "def foo"
    assert_includes combined, "Introduction paragraph"
    assert_includes combined, "Conclusion paragraph"
  end

  def test_handles_empty_input
    assert_equal [], @chunker.chunk(nil)
    assert_equal [], @chunker.chunk("")
    assert_equal [], @chunker.chunk("   ")
  end

  def test_normalizes_line_endings
    text = "First.\r\n\r\nSecond."
    chunks = @chunker.chunk(text)

    # Should produce at least one chunk with normalized content
    assert chunks.size >= 1
    combined = chunks.join("\n")
    assert_includes combined, "First"
    assert_includes combined, "Second"
  end

  def test_handles_multiple_blank_lines
    text = "First paragraph here.\n\n\n\nSecond paragraph here."
    chunks = @chunker.chunk(text)

    # Should produce chunks with content
    assert chunks.size >= 1
    combined = chunks.join("\n")
    assert_includes combined, "First paragraph"
    assert_includes combined, "Second paragraph"
  end

  def test_preserves_tilde_code_blocks
    text = <<~MD
      Before the code block.

      ~~~python
      print("hello")
      ~~~

      After the code block.
    MD

    chunks = @chunker.chunk(text)

    # Code blocks should be preserved
    combined = chunks.join("\n")
    assert_includes combined, "~~~python"
    assert_includes combined, "print"
    assert_includes combined, "Before the code block"
    assert_includes combined, "After the code block"
  end

  def test_respects_chunk_size
    # Create a chunker with a small chunk size
    small_chunker = HTM::Loaders::MarkdownChunker.new(chunk_size: 50, chunk_overlap: 5)

    # Long text that should be split
    text = "This is a paragraph that is definitely longer than fifty characters and should be split into multiple chunks."
    chunks = small_chunker.chunk(text)

    # Should be split into multiple chunks
    assert chunks.size > 1
    # Each chunk should be around the chunk size (allowing for flexibility at boundaries)
    chunks.each do |chunk|
      # Allow some flexibility for boundary finding
      assert chunk.length <= 100, "Chunk too large: #{chunk.length} chars"
    end
  end

  def test_chunk_with_metadata_returns_cursor_positions
    text = "# Title\n\nSome content here.\n\nAnother paragraph."

    chunks = @chunker.chunk_with_metadata(text)

    assert chunks.size >= 1
    # Each chunk should have text and cursor
    chunks.each do |chunk|
      assert chunk.key?(:text), "Chunk should have :text key"
      assert chunk.key?(:cursor), "Chunk should have :cursor key"
      assert_kind_of Integer, chunk[:cursor], "Cursor should be an integer"
    end

    # First chunk should start at position 0
    assert_equal 0, chunks.first[:cursor]
  end

  def test_cursor_positions_are_sequential
    text = "First paragraph here.\n\nSecond paragraph here.\n\nThird paragraph."
    small_chunker = HTM::Loaders::MarkdownChunker.new(chunk_size: 30, chunk_overlap: 5)

    chunks = small_chunker.chunk_with_metadata(text)

    # Cursor positions should increase (though not strictly due to overlap)
    if chunks.size > 1
      chunks.each_cons(2) do |a, b|
        assert b[:cursor] > a[:cursor], "Later chunks should have higher cursor positions"
      end
    end
  end

  def test_uses_config_defaults
    # Reset to default configuration
    HTM.configure do |config|
      config.chunking.chunk_size = 512
      config.chunking.chunk_overlap = 32
    end

    default_chunker = HTM::Loaders::MarkdownChunker.new
    assert_equal 512, default_chunker.chunk_size
    assert_equal 32, default_chunker.chunk_overlap
  end

  def test_custom_chunk_size_overrides_config
    HTM.configure do |config|
      config.chunking.chunk_size = 1000
      config.chunking.chunk_overlap = 100
    end

    custom_chunker = HTM::Loaders::MarkdownChunker.new(chunk_size: 200, chunk_overlap: 20)
    assert_equal 200, custom_chunker.chunk_size
    assert_equal 20, custom_chunker.chunk_overlap
  end
end
