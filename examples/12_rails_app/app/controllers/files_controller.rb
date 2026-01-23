# frozen_string_literal: true

class FilesController < ApplicationController
  def index
    @file_sources = HTM::Models::FileSource.order(updated_at: :desc)
  end

  def show
    @file_source = HTM::Models::FileSource[params[:id]]
    @chunks = @file_source.chunks.order(:id)
  end

  def new
  end

  def create
    path = params[:path]&.strip

    if path.blank?
      flash[:alert] = 'File path is required'
      redirect_to new_file_path
      return
    end

    unless File.exist?(path)
      flash[:alert] = "File not found: #{path}"
      redirect_to new_file_path
      return
    end

    force = params[:force] == 'true'

    begin
      result = htm.load_file(path, force: force)
      flash[:notice] = "File loaded: #{result[:chunks_created]} chunks created, #{result[:chunks_updated]} updated, #{result[:chunks_deleted]} deleted"
      redirect_to file_path(result[:file_source_id])
    rescue StandardError => e
      flash[:alert] = "Error loading file: #{e.message}"
      redirect_to new_file_path
    end
  end

  def load_directory
    path = params[:path]&.strip
    pattern = params[:pattern] || '**/*.md'

    if path.blank?
      flash[:alert] = 'Directory path is required'
      redirect_to new_file_path
      return
    end

    unless Dir.exist?(path)
      flash[:alert] = "Directory not found: #{path}"
      redirect_to new_file_path
      return
    end

    begin
      results = htm.load_directory(path, pattern: pattern)
      total_chunks = results.sum { |r| r[:chunks_created] }
      flash[:notice] = "Loaded #{results.length} files with #{total_chunks} total chunks"
      redirect_to files_path
    rescue StandardError => e
      flash[:alert] = "Error loading directory: #{e.message}"
      redirect_to new_file_path
    end
  end

  def upload
    files = params[:files]
    force = params[:force] == 'true'

    if files.blank?
      flash[:alert] = 'Please select at least one file'
      redirect_to new_file_path
      return
    end

    results = process_uploaded_files(files, force: force)

    if results[:errors].any?
      flash[:alert] = "Loaded #{results[:success_count]} files with #{results[:errors].length} errors: #{results[:errors].first}"
    else
      flash[:notice] = "Loaded #{results[:success_count]} files with #{results[:total_chunks]} total chunks"
    end

    if results[:last_file_source_id] && results[:success_count] == 1
      redirect_to file_path(results[:last_file_source_id])
    else
      redirect_to files_path
    end
  end

  def upload_directory
    files = params[:files]
    extension = params[:extension]

    if files.blank?
      flash[:alert] = 'Please select a directory'
      redirect_to new_file_path
      return
    end

    # Filter files by extension if specified
    filtered_files = if extension.present?
                       files.select { |f| f.original_filename.end_with?(extension) }
                     else
                       files.select { |f| f.original_filename.match?(/\.(md|markdown|txt)$/i) }
                     end

    if filtered_files.empty?
      flash[:alert] = 'No matching files found in the selected directory'
      redirect_to new_file_path
      return
    end

    results = process_uploaded_files(filtered_files, force: false)

    if results[:errors].any?
      flash[:alert] = "Loaded #{results[:success_count]} files with #{results[:errors].length} errors"
    else
      flash[:notice] = "Loaded #{results[:success_count]} files with #{results[:total_chunks]} total chunks"
    end

    redirect_to files_path
  end

  def sync
    @file_source = HTM::Models::FileSource[params[:id]]

    begin
      result = htm.load_file(@file_source.file_path, force: true)
      flash[:notice] = "File synced: #{result[:chunks_created]} created, #{result[:chunks_updated]} updated, #{result[:chunks_deleted]} deleted"
    rescue StandardError => e
      flash[:alert] = "Error syncing file: #{e.message}"
    end

    redirect_to file_path(@file_source)
  end

  def destroy
    @file_source = HTM::Models::FileSource[params[:id]]

    begin
      htm.unload_file(@file_source.file_path)
      flash[:notice] = 'File unloaded successfully'
    rescue StandardError => e
      flash[:alert] = "Error unloading file: #{e.message}"
    end

    redirect_to files_path
  end

  def sync_all
    synced = 0
    errors = 0

    HTM::Models::FileSource.paged_each do |source|
      if source.needs_sync?
        begin
          htm.load_file(source.file_path, force: true)
          synced += 1
        rescue StandardError
          errors += 1
        end
      end
    end

    if errors.zero?
      flash[:notice] = "Synced #{synced} files"
    else
      flash[:alert] = "Synced #{synced} files with #{errors} errors"
    end

    redirect_to files_path
  end

  private

  def process_uploaded_files(files, force: false)
    results = { success_count: 0, total_chunks: 0, errors: [], last_file_source_id: nil }

    # Create uploads directory if it doesn't exist
    uploads_dir = Rails.root.join('tmp', 'uploads')
    FileUtils.mkdir_p(uploads_dir)

    files.each do |file|
      # Save uploaded file to temp location
      temp_path = uploads_dir.join(file.original_filename)
      File.open(temp_path, 'wb') { |f| f.write(file.read) }

      begin
        result = htm.load_file(temp_path.to_s, force: force)
        results[:success_count] += 1
        results[:total_chunks] += result[:chunks_created]
        results[:last_file_source_id] = result[:file_source_id]
      rescue StandardError => e
        results[:errors] << "#{file.original_filename}: #{e.message}"
      end
    end

    results
  end
end
