# frozen_string_literal: true

class TagsController < ApplicationController
  def index
    @view_type = params[:view] || 'list'

    case @view_type
    when 'tree'
      @tree_string = HTM::Models::Tag.all.tree_string
      @tree_svg = HTM::Models::Tag.all.tree_svg(title: 'HTM Tag Hierarchy')
    when 'mermaid'
      @tree_mermaid = HTM::Models::Tag.all.tree_mermaid
    else
      # Build tag list with node counts using Sequel
      tags_with_counts = HTM.db[:tags]
        .left_join(:nodes_tags, tag_id: :id)
        .group(:id, :name, :created_at, :updated_at)
        .select_append(Sequel.function(:count, Sequel[:nodes_tags][:node_id]).as(:node_count))
        .order(:name)

      if params[:prefix].present?
        tags_with_counts = tags_with_counts.where(Sequel.like(:name, "#{params[:prefix]}%"))
      end

      @tags = tags_with_counts.map { |row| OpenStruct.new(row) }
    end
  end

  def show
    @tag = HTM::Models::Tag[params[:id]]
    @memories = @tag.nodes_dataset.active.eager(:tags).order(Sequel.desc(:created_at)).all
  end
end
