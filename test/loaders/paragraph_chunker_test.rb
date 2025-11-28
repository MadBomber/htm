# frozen_string_literal: true

require_relative '../test_helper'

class ParagraphChunkerTest < Minitest::Test
  def setup
    @chunker = HTM::Loaders::ParagraphChunker.new
  end

  def test_chunks_by_blank_lines
    text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
    chunks = @chunker.chunk(text)

    assert_equal 3, chunks.size
    assert_equal "First paragraph.", chunks[0]
    assert_equal "Second paragraph.", chunks[1]
    assert_equal "Third paragraph.", chunks[2]
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

    assert_equal 3, chunks.size
    assert_equal "Introduction paragraph.", chunks[0]
    assert_includes chunks[1], "```ruby"
    assert_includes chunks[1], "def foo"
    assert_equal "Conclusion paragraph.", chunks[2]
  end

  def test_handles_empty_input
    assert_equal [], @chunker.chunk(nil)
    assert_equal [], @chunker.chunk("")
    assert_equal [], @chunker.chunk("   ")
  end

  def test_merges_short_chunks
    text = "Hi\n\nWorld hello!\n\nThis is a longer paragraph that should stand alone."
    chunks = @chunker.chunk(text)

    # "Hi" (2 chars) should be merged with "World hello!" (12 chars)
    # Once merged (16 chars > 10), the longer paragraph stands alone
    assert_equal 2, chunks.size
    assert_includes chunks[0], "Hi"
    assert_includes chunks[0], "World"
    assert_includes chunks[1], "longer paragraph"
  end

  def test_normalizes_line_endings
    text = "First.\r\n\r\nSecond.\r\rThird."
    chunks = @chunker.chunk(text)

    # All should be normalized and split properly
    assert chunks.size >= 1
  end

  def test_handles_multiple_blank_lines
    text = "First paragraph here.\n\n\n\nSecond paragraph here."
    chunks = @chunker.chunk(text)

    assert_equal 2, chunks.size
    assert_equal "First paragraph here.", chunks[0]
    assert_equal "Second paragraph here.", chunks[1]
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

    assert_equal 3, chunks.size
    assert_equal "Before the code block.", chunks[0]
    assert_includes chunks[1], "~~~python"
    assert_equal "After the code block.", chunks[2]
  end
end
