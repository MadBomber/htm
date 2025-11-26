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

      count = HTM::Models::Tag.count

      if count.zero?
        puts "No tags found in database."
        next
      end

      # Display tree using Tag model method
      puts "\nHTM Tags Tree"
      puts "=" * 40
      print HTM::Models::Tag.all.tree_string
      puts "\nTotal tags: #{count}"
    end
  end
end
