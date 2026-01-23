# frozen_string_literal: true

# HTM File Loading Tasks
#
# These tasks are available to any application using the HTM gem.
# Add to your application's Rakefile:
#
#   require 'htm/tasks'
#

namespace :htm do
  namespace :files do
    desc "Load a markdown file into long-term memory. Usage: rake htm:files:load[path/to/file.md]"
    task :load, [:path] do |_t, args|

      path = args[:path]
      unless path
        puts "Error: File path required."
        puts "Usage: rake 'htm:files:load[path/to/file.md]'"
        exit 1
      end

      unless File.exist?(path)
        puts "Error: File not found: #{path}"
        exit 1
      end

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      htm = HTM.new(robot_name: "FileLoader")
      force = ENV['FORCE'] == 'true'

      puts "Loading file: #{path}#{force ? ' (force)' : ''}"
      result = htm.load_file(path, force: force)

      if result[:skipped]
        puts "Skipped: File unchanged since last sync."
        puts "Use FORCE=true to reload anyway."
      else
        puts "Loaded successfully:"
        puts "  File source ID: #{result[:file_source_id]}"
        puts "  Chunks created: #{result[:chunks_created]}"
        puts "  Chunks updated: #{result[:chunks_updated]}"
        puts "  Chunks deleted: #{result[:chunks_deleted]}"
      end
    end

    desc "Load all markdown files from a directory. Usage: rake htm:files:load_dir[path/to/dir]"
    task :load_dir, [:path, :pattern] do |_t, args|

      path = args[:path]
      unless path
        puts "Error: Directory path required."
        puts "Usage: rake 'htm:files:load_dir[path/to/dir]'"
        puts "       rake 'htm:files:load_dir[path/to/dir,**/*.md]'"
        exit 1
      end

      unless File.directory?(path)
        puts "Error: Directory not found: #{path}"
        exit 1
      end

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      htm = HTM.new(robot_name: "FileLoader")
      pattern = args[:pattern] || '**/*.md'
      force = ENV['FORCE'] == 'true'

      puts "Loading files from: #{path}"
      puts "Pattern: #{pattern}#{force ? ' (force)' : ''}"
      puts

      results = htm.load_directory(path, pattern: pattern, force: force)

      total_created = 0
      total_updated = 0
      total_deleted = 0
      skipped = 0

      results.each do |result|
        if result[:skipped]
          skipped += 1
        else
          total_created += result[:chunks_created]
          total_updated += result[:chunks_updated]
          total_deleted += result[:chunks_deleted]
          puts "  #{result[:file_path]}: #{result[:chunks_created]} created, #{result[:chunks_updated]} updated, #{result[:chunks_deleted]} deleted"
        end
      end

      puts
      puts "Summary:"
      puts "  Files processed: #{results.size}"
      puts "  Files skipped (unchanged): #{skipped}"
      puts "  Total chunks created: #{total_created}"
      puts "  Total chunks updated: #{total_updated}"
      puts "  Total chunks deleted: #{total_deleted}"
    end

    desc "List all loaded file sources"
    task :list do

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      sources = HTM::Models::FileSource.order(:file_path)
      count = sources.count

      if count.zero?
        puts "No files loaded."
        next
      end

      puts "Loaded files (#{count}):"
      puts "-" * 80

      sources.each do |source|
        chunks = source.chunks.count
        sync_status = ""
        if File.exist?(source.file_path)
          current_mtime = File.mtime(source.file_path)
          sync_status = source.needs_sync?(current_mtime) ? " [needs sync]" : ""
        else
          sync_status = " [missing]"
        end
        puts "  #{source.file_path}"
        puts "    ID: #{source.id} | Chunks: #{chunks} | Last synced: #{source.last_synced_at&.strftime('%Y-%m-%d %H:%M')}#{sync_status}"
      end
    end

    desc "Show details for a loaded file. Usage: rake htm:files:info[path/to/file.md]"
    task :info, [:path] do |_t, args|

      path = args[:path]
      unless path
        puts "Error: File path required."
        puts "Usage: rake 'htm:files:info[path/to/file.md]'"
        exit 1
      end

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      # Try to find by exact path or expanded path
      source = HTM::Models::FileSource.first(file_path: path) ||
               HTM::Models::FileSource.first(file_path: File.expand_path(path))

      unless source
        puts "Error: File not loaded: #{path}"
        exit 1
      end

      puts "File: #{source.file_path}"
      puts "-" * 60
      puts "  ID: #{source.id}"
      puts "  File size: #{source.file_size} bytes"
      puts "  Last synced: #{source.last_synced_at}"

      if File.exist?(source.file_path)
        current_mtime = File.mtime(source.file_path)
        puts "  Needs sync: #{source.needs_sync?(current_mtime) ? 'Yes' : 'No'}"
      else
        puts "  Needs sync: File missing!"
      end

      puts "  Created: #{source.created_at}"
      puts

      if source.frontmatter.any?
        puts "Frontmatter:"
        source.frontmatter.each do |key, value|
          puts "  #{key}: #{value}"
        end
        puts
      end

      chunks = source.chunks
      puts "Chunks (#{chunks.count}):"
      chunks.each_with_index do |chunk, idx|
        preview = chunk.content[0..60].gsub("\n", " ")
        preview += "..." if chunk.content.length > 60
        puts "  [#{idx}] #{preview}"
      end
    end

    desc "Unload a file from memory. Usage: rake htm:files:unload[path/to/file.md]"
    task :unload, [:path] do |_t, args|

      path = args[:path]
      unless path
        puts "Error: File path required."
        puts "Usage: rake 'htm:files:unload[path/to/file.md]'"
        exit 1
      end

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      htm = HTM.new(robot_name: "FileLoader")
      result = htm.unload_file(path)

      if result
        puts "Unloaded: #{path}"
      else
        puts "File not found: #{path}"
      end
    end

    desc "Sync all loaded files (reload changed files)"
    task :sync do

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      htm = HTM.new(robot_name: "FileLoader")
      sources = HTM::Models::FileSource.all

      if sources.count.zero?
        puts "No files loaded."
        next
      end

      puts "Syncing #{sources.count} files..."
      puts

      synced = 0
      skipped = 0
      missing = 0

      sources.each do |source|
        unless File.exist?(source.file_path)
          puts "  [missing] #{source.file_path}"
          missing += 1
          next
        end

        current_mtime = File.mtime(source.file_path)
        unless source.needs_sync?(current_mtime)
          skipped += 1
          next
        end

        result = htm.load_file(source.file_path)
        puts "  [synced] #{source.file_path}: #{result[:chunks_created]} created, #{result[:chunks_updated]} updated, #{result[:chunks_deleted]} deleted"
        synced += 1
      end

      puts
      puts "Summary:"
      puts "  Synced: #{synced}"
      puts "  Skipped (unchanged): #{skipped}"
      puts "  Missing files: #{missing}"
    end

    desc "Show file loading statistics"
    task :stats do

      # Ensure database connection
      HTM::SequelConfig.establish_connection!

      total_sources = HTM::Models::FileSource.count
      total_chunks = HTM::Models::Node.exclude(source_id: nil).count

      # Count files needing sync (checking actual file mtime)
      needs_sync = 0
      missing = 0
      HTM::Models::FileSource.paged_each do |source|
        if File.exist?(source.file_path)
          current_mtime = File.mtime(source.file_path)
          needs_sync += 1 if source.needs_sync?(current_mtime)
        else
          missing += 1
        end
      end

      puts "File Loading Statistics"
      puts "=" * 40
      puts "  Total files loaded: #{total_sources}"
      puts "  Total chunks: #{total_chunks}"
      puts "  Files needing sync: #{needs_sync}"
      puts "  Missing files: #{missing}" if missing > 0

      if total_sources > 0
        avg_chunks = (total_chunks.to_f / total_sources).round(1)
        puts "  Average chunks per file: #{avg_chunks}"
      end
    end
  end
end
