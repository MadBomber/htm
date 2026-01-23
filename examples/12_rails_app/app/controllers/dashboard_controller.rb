# frozen_string_literal: true

require 'ostruct'

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

    @top_tags = HTM.db[:tags]
                .join(:node_tags, tag_id: Sequel[:tags][:id])
                .group(Sequel[:tags][:id], Sequel[:tags][:name], Sequel[:tags][:created_at])
                .order(Sequel.desc(Sequel.function(:count, Sequel[:node_tags][:node_id])))
                .limit(10)
                .select(Sequel[:tags][:id], Sequel[:tags][:name], Sequel[:tags][:created_at])
                .select_append(Sequel.function(:count, Sequel[:node_tags][:node_id]).as(:node_count))
                .map { |row| OpenStruct.new(row) }

    @robots = HTM::Models::Robot.order(Sequel.desc(:created_at)).limit(5)
  end
end
