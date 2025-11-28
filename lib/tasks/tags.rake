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
