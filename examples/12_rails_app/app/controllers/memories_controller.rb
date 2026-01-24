# frozen_string_literal: true

class MemoriesController < ApplicationController
  before_action :set_memory, only: [:show, :edit, :update, :destroy, :restore]

  def index
    # Default scope excludes deleted nodes, so no .active needed
    @memories = HTM::Models::Node.eager(:tags)
                                 .order(Sequel.desc(:created_at))

    if params[:tag].present?
      tag_node_ids = HTM::Models::NodeTag
        .join(:tags, id: :tag_id)
        .where(Sequel[:tags][:name] => params[:tag])
        .select_map(:node_id)
      @memories = @memories.where(id: tag_node_ids) if tag_node_ids.any?
    end

    if params[:search].present?
      search_pattern = "%#{Sequel.like_escape(params[:search])}%"
      @memories = @memories.where(Sequel.ilike(:content, search_pattern))
    end

    # Simple pagination without Kaminari
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @total_count = @memories.count
    @total_pages = (@total_count.to_f / @per_page).ceil
    @memories = @memories.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @related = htm.recall(@memory.content, limit: 5, strategy: :vector, raw: true)
                  .reject { |m| m['id'] == @memory.id }
  end

  def new
    @memory = HTM::Models::Node.new
  end

  def create
    content = params[:content] || params.dig(:node, :content)
    tags = params[:tags] || params.dig(:node, :tags)
    metadata = params[:metadata] || params.dig(:node, :metadata)

    if content.blank?
      flash[:alert] = 'Content is required'
      redirect_to new_memory_path
      return
    end

    tag_array = tags.present? ? tags.split(',').map(&:strip) : []
    metadata_hash = metadata.present? ? JSON.parse(metadata) : {}

    node_id = htm.remember(content, tags: tag_array, metadata: metadata_hash)
    flash[:notice] = 'Memory stored successfully'
    redirect_to memory_path(node_id)
  rescue JSON::ParserError
    flash[:alert] = 'Invalid metadata JSON format'
    redirect_to new_memory_path
  end

  def edit
  end

  def update
    content = params[:content] || params.dig(:node, :content)

    if content.blank?
      flash[:alert] = 'Content is required'
      redirect_to edit_memory_path(@memory.id)
      return
    end

    @memory.update(content: content)
    flash[:notice] = 'Memory updated successfully'
    redirect_to memory_path(@memory.id)
  end

  def destroy
    soft = params[:permanent] != 'true'
    if soft
      htm.forget(@memory.id)
      flash[:notice] = 'Memory moved to trash. You can restore it later.'
    else
      htm.forget(@memory.id, soft: false, confirm: :confirmed)
      flash[:notice] = 'Memory permanently deleted.'
    end
    redirect_to memories_path
  end

  def restore
    htm.restore(@memory.id)
    flash[:notice] = 'Memory restored successfully.'
    redirect_to memory_path(@memory.id)
  end

  def deleted
    @memories = HTM::Models::Node.deleted.order(Sequel.desc(:deleted_at))
  end

  private

  def set_memory
    @memory = HTM::Models::Node.with_deleted[params[:id].to_i]
    return if @memory

    flash[:alert] = 'Memory not found'
    redirect_to memories_path
  end
end
