# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    # Note: HTM::Models::Node has a default_scope that excludes deleted nodes
    # so we don't need to call .active explicitly
    @stats = {
      total_nodes: HTM::Models::Node.count,
      nodes_with_embeddings: HTM::Models::Node.with_embeddings.count,
      deleted_nodes: HTM::Models::Node.deleted.count,
      total_tags: HTM::Models::Tag.count,
      total_robots: HTM::Models::Robot.count,
      total_file_sources: HTM::Models::FileSource.count
    }

    @recent_memories = HTM::Models::Node.recent.limit(5)

    @top_tags = HTM::Models::Tag
                .joins(:nodes)
                .group('tags.id')
                .order('COUNT(nodes.id) DESC')
                .limit(10)
                .select('tags.*, COUNT(nodes.id) as node_count')

    @robots = HTM::Models::Robot.order(created_at: :desc).limit(5)
  end
end
