# frozen_string_literal: true

require_relative '../test_helper'

class FileSourceTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    # Clean up any existing test file sources
    HTM::Models::FileSource.where(Sequel.like(:file_path, "%test_file_source%")).delete
  end

  def teardown
    return unless database_available?

    # Clean up test data
    HTM::Models::FileSource.where(Sequel.like(:file_path, "%test_file_source%")).delete

    # Clean up any temp files created during tests
    @temp_files&.each { |f| File.delete(f) if File.exist?(f) }
  end

  # Helper to create a temp file that exists on disk
  def create_temp_file(path)
    @temp_files ||= []
    @temp_files << path
    File.write(path, "test content")
    path
  end

  # DELTA_TIME constant tests

  def test_delta_time_constant_exists
    assert_equal 5, HTM::Models::FileSource::DELTA_TIME
  end

  # needs_sync? tests

  def test_needs_sync_returns_true_when_mtime_is_nil
    source = HTM::Models::FileSource.new(file_path: '/tmp/test_file_source.md')

    assert_nil source.mtime
    assert source.needs_sync?(Time.now)
  end

  def test_needs_sync_returns_false_when_difference_within_delta
    file_path = create_temp_file('/tmp/test_file_source_delta.md')
    source = HTM::Models::FileSource.create(
      file_path: file_path,
      mtime: Time.now
    )

    # 3 seconds difference (within DELTA_TIME of 5)
    current_mtime = source.mtime + 3

    refute source.needs_sync?(current_mtime)
  end

  def test_needs_sync_returns_false_when_difference_exactly_at_delta
    file_path = create_temp_file('/tmp/test_file_source_exact.md')
    source = HTM::Models::FileSource.create(
      file_path: file_path,
      mtime: Time.now
    )

    # Exactly 5 seconds difference (not greater than DELTA_TIME)
    current_mtime = source.mtime + 5

    refute source.needs_sync?(current_mtime)
  end

  def test_needs_sync_returns_true_when_difference_exceeds_delta
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_exceeds.md',
      mtime: Time.now
    )

    # 6 seconds difference (greater than DELTA_TIME of 5)
    current_mtime = source.mtime + 6

    assert source.needs_sync?(current_mtime)
  end

  def test_needs_sync_uses_absolute_value_for_negative_difference
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_negative.md',
      mtime: Time.now
    )

    # Current mtime is 6 seconds BEFORE stored (negative diff, abs > DELTA_TIME)
    current_mtime = source.mtime - 6

    assert source.needs_sync?(current_mtime)
  end

  def test_needs_sync_returns_false_for_small_negative_difference
    file_path = create_temp_file('/tmp/test_file_source_small_neg.md')
    source = HTM::Models::FileSource.create(
      file_path: file_path,
      mtime: Time.now
    )

    # Current mtime is 2 seconds BEFORE stored (abs within DELTA_TIME)
    current_mtime = source.mtime - 2

    refute source.needs_sync?(current_mtime)
  end

  # Validation tests

  def test_requires_file_path
    source = HTM::Models::FileSource.new

    refute source.valid?
    # Sequel uses "is not present" for presence validation
    assert_includes source.errors[:file_path], "is not present"
  end

  def test_file_path_must_be_unique
    HTM::Models::FileSource.create(file_path: '/tmp/test_file_source_unique.md')

    duplicate = HTM::Models::FileSource.new(file_path: '/tmp/test_file_source_unique.md')

    refute duplicate.valid?
    # Sequel uses "is already taken" for uniqueness validation
    assert_includes duplicate.errors[:file_path], "is already taken"
  end

  # Association tests

  def test_has_many_nodes
    source = HTM::Models::FileSource.create(file_path: '/tmp/test_file_source_nodes.md')

    assert_respond_to source, :nodes
    assert_equal 0, source.nodes.count
  end

  def test_chunks_returns_ordered_nodes
    source = HTM::Models::FileSource.create(file_path: '/tmp/test_file_source_chunks.md')

    assert_respond_to source, :chunks
    # chunks returns nodes ordered by chunk_position via the dataset
    assert_equal source.nodes_dataset.order(:chunk_position).all, source.chunks
  end

  # Frontmatter tests

  def test_frontmatter_tags_returns_empty_array_when_no_frontmatter
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_no_fm.md',
      frontmatter: {}
    )

    assert_equal [], source.frontmatter_tags
  end

  def test_frontmatter_tags_returns_tags_array
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_fm_tags.md',
      frontmatter: { 'tags' => ['ruby', 'testing'] }
    )

    assert_equal ['ruby', 'testing'], source.frontmatter_tags
  end

  def test_frontmatter_tags_handles_symbol_keys
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_fm_sym.md',
      frontmatter: { tags: ['symbol', 'keys'] }
    )

    assert_equal ['symbol', 'keys'], source.frontmatter_tags
  end

  def test_title_returns_nil_when_no_frontmatter
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_no_title.md',
      frontmatter: {}
    )

    assert_nil source.title
  end

  def test_title_returns_frontmatter_title
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_title.md',
      frontmatter: { 'title' => 'My Document' }
    )

    assert_equal 'My Document', source.title
  end

  def test_author_returns_frontmatter_author
    source = HTM::Models::FileSource.create(
      file_path: '/tmp/test_file_source_author.md',
      frontmatter: { 'author' => 'John Doe' }
    )

    assert_equal 'John Doe', source.author
  end

  # Scope tests

  def test_by_path_scope_expands_path
    source = HTM::Models::FileSource.create(file_path: '/tmp/test_file_source_scope.md')

    found = HTM::Models::FileSource.by_path('/tmp/test_file_source_scope.md').first

    assert_equal source.id, found.id
  end

end
