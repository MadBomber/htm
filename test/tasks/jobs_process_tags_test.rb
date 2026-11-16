# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'
require 'minitest/mock'
require 'securerandom'

# Guards the regression where htm:jobs:process_tags linked only the leaf tag
# an extraction returned (a:b:c), never its parents (a, a:b), unlike every
# other tagging path.
class JobsProcessTagsTaskTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    @rake = Rake::Application.new
    Rake.application = @rake
    @rake.instance_eval { load File.expand_path('../../lib/tasks/jobs.rake', __dir__) }

    @prefix = "pt#{SecureRandom.hex(4)}"
    content = "process_tags task test #{SecureRandom.hex(8)}"
    @node = HTM::Models::Node.create(content: content, content_hash: Digest::SHA256.hexdigest(content))
  end

  def teardown
    return unless database_available?

    Rake.application = Rake::Application.new
    @node&.destroy
    HTM::Models::Tag.where(Sequel.like(:name, "#{@prefix}%")).delete
  end

  def test_process_tags_links_parent_tags
    leaf = "#{@prefix}:b:c"
    run_process_tags(returning: [leaf])

    assert_equal [@prefix, "#{@prefix}:b", leaf], @node.reload.tag_names.sort
  end

  private

  # Limit the task to this test's node and keep the shared connection open
  def run_process_tags(returning:)
    node_where = HTM::Models::Node.method(:where)
    only_this_node = ->(*args) { node_where.call(*args).where(Sequel[:nodes][:id] => @node.id) }

    HTM::Models::Node.stub(:where, only_this_node) do
      HTM::TagService.stub(:extract, returning) do
        HTM::SequelConfig.stub(:disconnect!, nil) do
          capture_io { Rake::Task['htm:jobs:process_tags'].execute }
        end
      end
    end
  end
end
