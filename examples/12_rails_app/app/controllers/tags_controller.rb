# frozen_string_literal: true

require 'ostruct'

class TagsController < ApplicationController
  def index
    @view_type = params[:view] || 'list'

    case @view_type
    when 'tree'
      @tree_string = HTM::Models::Tag.tree_string
      @tree_svg = HTM::Models::Tag.tree_svg(title: 'HTM Tag Hierarchy')
    when 'mermaid'
      @tree_mermaid = HTM::Models::Tag.tree_mermaid
    else
      # Build tag list with node counts using Sequel
      tags_with_counts = HTM.db[:tags]
        .left_join(:node_tags, tag_id: Sequel[:tags][:id])
        .group(Sequel[:tags][:id], Sequel[:tags][:name], Sequel[:tags][:created_at])
        .select(Sequel[:tags][:id], Sequel[:tags][:name], Sequel[:tags][:created_at])
        .select_append(Sequel.function(:count, Sequel[:node_tags][:node_id]).as(:node_count))
        .order(Sequel[:tags][:name])

      if params[:prefix].present?
        tags_with_counts = tags_with_counts.where(Sequel.like(:name, "#{params[:prefix]}%"))
      end

      @tags = tags_with_counts.map { |row| OpenStruct.new(row) }
    end
  end

  def show
    @tag = HTM::Models::Tag[params[:id]]
    unless @tag
      flash[:alert] = 'Tag not found'
      redirect_to tags_path
      return
    end
    @memories = @tag.nodes_dataset.active.eager(:tags).order(Sequel.desc(:created_at)).all
  end
end
