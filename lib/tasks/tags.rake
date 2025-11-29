# frozen_string_literal: true

# HTM Tag Management Tasks
#
# These tasks are available to any application using the HTM gem.
# Add to your application's Rakefile:
#
#   require 'htm/tasks'
#

namespace :htm do
  namespace :tags do
    desc "Display tags as a hierarchical tree (text format). Optional prefix filter."
    task :tree, [:prefix] do |_t, args|
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      tags = args[:prefix] ? HTM::Models::Tag.with_prefix(args[:prefix]) : HTM::Models::Tag.all
      count = tags.count

      if count.zero?
        puts args[:prefix] ? "No tags found with prefix '#{args[:prefix]}'." : "No tags found in database."
        next
      end

      # Display tree using Tag model method
      puts "\nHTM Tags Tree#{args[:prefix] ? " (prefix: #{args[:prefix]})" : ''}"
      puts "=" * 40
      print tags.tree_string
      puts "\nTotal tags: #{count}"
    end

    desc "Export tags as Mermaid flowchart to tags.md. Optional prefix filter."
    task :mermaid, [:prefix] do |_t, args|
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      tags = args[:prefix] ? HTM::Models::Tag.with_prefix(args[:prefix]) : HTM::Models::Tag.all
      count = tags.count

      if count.zero?
        puts args[:prefix] ? "No tags found with prefix '#{args[:prefix]}'." : "No tags found in database."
        next
      end

      mermaid = tags.tree_mermaid(direction: 'TD')
      File.write('tags.md', mermaid)

      puts "Mermaid flowchart written to: tags.md"
      puts "Tags exported: #{count}#{args[:prefix] ? " (prefix: #{args[:prefix]})" : ''}"
    end

    desc "Export tags as SVG visualization to tags.svg. Optional prefix filter."
    task :svg, [:prefix] do |_t, args|
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      tags = args[:prefix] ? HTM::Models::Tag.with_prefix(args[:prefix]) : HTM::Models::Tag.all
      count = tags.count

      if count.zero?
        puts args[:prefix] ? "No tags found with prefix '#{args[:prefix]}'." : "No tags found in database."
        next
      end

      title = args[:prefix] ? "HTM Tags: #{args[:prefix]}*" : 'HTM Tag Hierarchy'
      svg = tags.tree_svg(title: title)
      File.write('tags.svg', svg)

      puts "SVG visualization written to: tags.svg"
      puts "Tags exported: #{count}#{args[:prefix] ? " (prefix: #{args[:prefix]})" : ''}"
    end

    desc "Rebuild all tags from node content. Clears existing tags and regenerates using LLM."
    task :rebuild do
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      # Node uses default_scope for active (non-deleted) nodes
      node_count = HTM::Models::Node.count
      tag_count = HTM::Models::Tag.count
      node_tag_count = HTM::Models::NodeTag.count

      puts "\nHTM Tags Rebuild"
      puts "=" * 40
      puts "This will:"
      puts "  - Delete #{node_tag_count} node-tag associations"
      puts "  - Delete #{tag_count} tags"
      puts "  - Regenerate tags for #{node_count} nodes using LLM"
      puts "\nThis operation cannot be undone."
      print "\nType 'yes' to confirm: "

      confirmation = $stdin.gets&.strip
      unless confirmation == 'yes'
        puts "Aborted."
        next
      end

      puts "\nClearing existing tags..."

      # Clear join table first (foreign key constraint)
      deleted_associations = HTM::Models::NodeTag.delete_all
      puts "  Deleted #{deleted_associations} node-tag associations"

      # Clear tags table
      deleted_tags = HTM::Models::Tag.delete_all
      puts "  Deleted #{deleted_tags} tags"

      puts "\nRegenerating tags for #{node_count} nodes..."
      puts "(This may take a while depending on your LLM provider)\n"

      require 'ruby-progressbar'

      # Create progress bar with ETA
      progressbar = ProgressBar.create(
        total: node_count,
        format: '%t: |%B| %c/%C (%p%%) %e',
        title: 'Processing',
        output: $stdout,
        smoothing: 0.5
      )

      # Process each active node (default_scope excludes deleted)
      errors = 0

      HTM::Models::Node.find_each do |node|
        begin
          HTM::Jobs::GenerateTagsJob.perform(node_id: node.id)
        rescue StandardError => e
          errors += 1
          progressbar.log "  Error on node #{node.id}: #{e.message}"
        end

        progressbar.increment
      end

      progressbar.finish

      # Final stats
      new_tag_count = HTM::Models::Tag.count
      new_association_count = HTM::Models::NodeTag.count

      puts "\nRebuild complete!"
      puts "  Nodes processed: #{node_count}"
      puts "  Errors: #{errors}"
      puts "  Tags created: #{new_tag_count}"
      puts "  Node-tag associations: #{new_association_count}"
    end

    desc "Export tags in all formats (tags.txt, tags.md, tags.svg). Optional prefix filter."
    task :export, [:prefix] do |_t, args|
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      tags = args[:prefix] ? HTM::Models::Tag.with_prefix(args[:prefix]) : HTM::Models::Tag.all
      count = tags.count

      if count.zero?
        puts args[:prefix] ? "No tags found with prefix '#{args[:prefix]}'." : "No tags found in database."
        next
      end

      prefix_note = args[:prefix] ? " (prefix: #{args[:prefix]})" : ''
      title = args[:prefix] ? "HTM Tags: #{args[:prefix]}*" : 'HTM Tag Hierarchy'

      # Export text tree
      text_content = "HTM Tags Tree#{prefix_note}\n" + ("=" * 40) + "\n"
      text_content += tags.tree_string
      text_content += "\nTotal tags: #{count}\n"
      File.write('tags.txt', text_content)
      puts "Text tree written to: tags.txt"

      # Export Mermaid
      File.write('tags.md', tags.tree_mermaid)
      puts "Mermaid flowchart written to: tags.md"

      # Export SVG
      File.write('tags.svg', tags.tree_svg(title: title))
      puts "SVG visualization written to: tags.svg"

      puts "\nTags exported: #{count}#{prefix_note}"
    end
  end
end
