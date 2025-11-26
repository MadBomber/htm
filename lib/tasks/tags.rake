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
    desc "Display tags as a hierarchical tree"
    task :tree do
      require 'htm'

      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      tags = HTM::Models::Tag.order(:name).pluck(:name)

      if tags.empty?
        puts "No tags found in database."
        next
      end

      # Build tree structure from hierarchical tags
      tree = build_tag_tree(tags)

      # Display tree
      puts "\nHTM Tags Tree"
      puts "=" * 40
      print_tag_tree(tree)
      puts "\nTotal tags: #{tags.size}"
    end
  end
end

# Build a nested hash from colon-separated tag names
def build_tag_tree(tags)
  tree = {}

  tags.each do |tag_name|
    parts = tag_name.split(':')
    current = tree

    parts.each do |part|
      current[part] ||= {}
      current = current[part]
    end
  end

  tree
end

# Print tree structure with directory-style formatting
def print_tag_tree(tree, prefix = "", is_last_array = [])
  sorted_keys = tree.keys.sort
  sorted_keys.each_with_index do |key, index|
    is_last = (index == sorted_keys.size - 1)

    # Build the prefix for this line
    line_prefix = prefix
    is_last_array.each_with_index do |was_last, depth|
      line_prefix += was_last ? "    " : "│   " if depth < is_last_array.size
    end

    # Add the branch character
    branch = is_last ? "└── " : "├── "
    puts "#{line_prefix}#{branch}#{key}"

    # Recurse into children
    children = tree[key]
    unless children.empty?
      print_tag_tree(children, prefix, is_last_array + [is_last])
    end
  end
end
