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
      @tags = HTM::Models::Tag
              .left_joins(:nodes)
              .group('tags.id')
              .select('tags.*, COUNT(nodes.id) as node_count')
              .order(:name)

      if params[:prefix].present?
        @tags = @tags.where('tags.name LIKE ?', "#{params[:prefix]}%")
      end
    end
  end

  def show
    @tag = HTM::Models::Tag.find(params[:id])
    @memories = @tag.nodes.active.includes(:tags).order(created_at: :desc)
  end
end
