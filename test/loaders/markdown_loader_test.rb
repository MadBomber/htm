# frozen_string_literal: true

require_relative '../test_helper'
require 'tempfile'
require 'fileutils'
require 'securerandom'

class MarkdownLoaderTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    @htm = HTM.new(robot_name: "MarkdownLoaderTest")

    # Create temp directory for test files
    @temp_dir = Dir.mktmpdir('htm_loader_test')

    # Clean up any existing test file sources
    HTM::Models::FileSource.where("file_path LIKE ?", "%#{@temp_dir}%").each do |fs|
      fs.nodes.update_all(source_id: nil)
      fs.destroy
    end
  end

  def teardown
    return unless database_available?

    # Clean up test file sources and associated nodes
    if @temp_dir && Dir.exist?(@temp_dir)
      HTM::Models::FileSource.where("file_path LIKE ?", "%#{@temp_dir}%").each do |fs|
        fs.nodes.update_all(source_id: nil)
        fs.destroy
      end
      FileUtils.rm_rf(@temp_dir)
    end
  end

  # Helper to create a test markdown file
  def create_test_file(name, content)
    path = File.join(@temp_dir, name)
    File.write(path, content)
    path
  end

  # Basic loading tests

  def test_load_file_creates_file_source
    path = create_test_file('basic.md', "# Hello\n\nThis is a test paragraph.")

    result = @htm.load_file(path, force: true)

    assert result[:file_source_id]
    refute result[:skipped]

    source = HTM::Models::FileSource.find(result[:file_source_id])
    assert_equal File.expand_path(path), source.file_path
  end

  def test_load_file_creates_chunks
    content = <<~MD
      First paragraph here.

      Second paragraph here.

      Third paragraph here.
    MD
    path = create_test_file('chunks.md', content)

    result = @htm.load_file(path, force: true)

    assert_equal 3, result[:chunks_created]
    assert_equal 0, result[:chunks_updated]
    assert_equal 0, result[:chunks_deleted]
  end

  def test_load_file_extracts_frontmatter
    content = <<~MD
      ---
      title: My Document
      author: Test Author
      tags:
        - ruby
        - testing
      ---

      Document content here.
    MD
    path = create_test_file('frontmatter.md', content)

    result = @htm.load_file(path, force: true)
    source = HTM::Models::FileSource.find(result[:file_source_id])

    assert_equal 'My Document', source.frontmatter['title']
    assert_equal 'Test Author', source.frontmatter['author']
    assert_equal ['ruby', 'testing'], source.frontmatter['tags']
  end

  def test_load_file_prepends_frontmatter_to_first_chunk
    content = <<~MD
      ---
      title: Test Doc
      ---

      First paragraph.

      Second paragraph.
    MD
    path = create_test_file('fm_chunk.md', content)

    result = @htm.load_file(path, force: true)
    source = HTM::Models::FileSource.find(result[:file_source_id])
    first_chunk = source.chunks.first

    assert_includes first_chunk.content, 'title: Test Doc'
    assert_includes first_chunk.content, 'First paragraph'
  end

  # Skip unchanged files

  def test_load_file_skips_unchanged_file
    path = create_test_file('unchanged.md', "Content here.")

    # First load
    result1 = @htm.load_file(path)
    refute result1[:skipped]

    # Second load without changes (wait for DELTA_TIME to pass)
    # Since we can't easily wait 5 seconds, we test with force instead
    result2 = @htm.load_file(path)
    assert result2[:skipped]
  end

  def test_load_file_force_reloads_unchanged_file
    path = create_test_file('force.md', "Content here.")

    # First load
    @htm.load_file(path)

    # Force reload
    result = @htm.load_file(path, force: true)
    refute result[:skipped]
  end

  # Re-sync tests

  def test_load_file_updates_file_metadata
    path = create_test_file('metadata.md', "Initial content.")

    result = @htm.load_file(path, force: true)
    source = HTM::Models::FileSource.find(result[:file_source_id])

    assert source.mtime
    assert source.file_size
    assert source.file_hash
    assert source.last_synced_at
  end

  # Error handling

  def test_load_file_raises_for_missing_file
    assert_raises(ArgumentError) do
      @htm.load_file('/nonexistent/path/file.md')
    end
  end

  def test_load_file_raises_for_directory
    assert_raises(ArgumentError) do
      @htm.load_file(@temp_dir)
    end
  end

  # load_directory tests

  def test_load_directory_loads_all_markdown_files
    create_test_file('doc1.md', "Document one content.")
    create_test_file('doc2.md', "Document two content.")
    create_test_file('doc3.txt', "Not markdown.")

    results = @htm.load_directory(@temp_dir, force: true)

    # Should load 2 .md files
    md_results = results.reject { |r| r[:error] }
    assert_equal 2, md_results.size
  end

  def test_load_directory_uses_custom_pattern
    create_test_file('doc.md', "Markdown doc.")
    create_test_file('doc.txt', "Text doc.")

    results = @htm.load_directory(@temp_dir, pattern: '*.txt', force: true)

    # Should only load .txt file
    assert_equal 1, results.size
    assert_includes results.first[:file_path], 'doc.txt'
  end

  def test_load_directory_raises_for_missing_directory
    assert_raises(ArgumentError) do
      @htm.load_directory('/nonexistent/directory')
    end
  end

  def test_load_directory_raises_for_file_path
    path = create_test_file('not_dir.md', "Content.")

    assert_raises(ArgumentError) do
      @htm.load_directory(path)
    end
  end

  # nodes_from_file tests

  def test_nodes_from_file_returns_chunks
    # Use unique content to avoid matching existing nodes
    content = "Unique paragraph one #{SecureRandom.hex(4)}.\n\nUnique paragraph two #{SecureRandom.hex(4)}.\n\nUnique paragraph three #{SecureRandom.hex(4)}."
    path = create_test_file('nodes.md', content)

    @htm.load_file(path, force: true)
    nodes = @htm.nodes_from_file(path)

    assert_equal 3, nodes.size
    assert nodes.all? { |n| n.is_a?(HTM::Models::Node) }
  end

  def test_nodes_from_file_returns_empty_for_unknown_file
    nodes = @htm.nodes_from_file('/nonexistent/file.md')

    assert_equal [], nodes
  end

  # unload_file tests

  def test_unload_file_removes_file_source
    path = create_test_file('unload.md', "Content to unload.")

    @htm.load_file(path, force: true)
    assert HTM::Models::FileSource.find_by(file_path: File.expand_path(path))

    result = @htm.unload_file(path)

    assert result
    refute HTM::Models::FileSource.find_by(file_path: File.expand_path(path))
  end

  def test_unload_file_soft_deletes_chunks
    path = create_test_file('unload_soft.md', "Content here.")

    result = @htm.load_file(path, force: true)
    source = HTM::Models::FileSource.find(result[:file_source_id])
    node_ids = source.chunks.pluck(:id)

    @htm.unload_file(path)

    # Nodes should be soft-deleted
    node_ids.each do |id|
      node = HTM::Models::Node.unscoped.find(id)
      assert node.deleted_at, "Node #{id} should be soft-deleted"
    end
  end

  def test_unload_file_returns_zero_for_unknown_file
    result = @htm.unload_file('/nonexistent/file.md')

    assert_equal 0, result
  end
end
