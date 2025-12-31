#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill Parent Tags
#
# This one-off script scans the existing tags table and creates missing
# parent tags for hierarchical tag names. It also ensures that nodes
# associated with child tags are also associated with all parent tags.
#
# Run with --help for usage information.

require 'optparse'
require 'ruby-progressbar'
require_relative '../lib/htm'

class ParentTagBackfill
  VERSION = '0.0.2'

  attr_reader :options, :stats

  def self.run(argv = ARGV)
    if argv.empty?
      new(['--help']).run
      exit 0
    end
    new(argv).run
  end

  def initialize(argv)
    @options = {
      dryrun: true,
      verbose: false
    }
    @stats = {
      tags_scanned: 0,
      parent_tags_created: 0,
      node_tags_created: 0,
      cache_hits: 0,
      errors: []
    }
    @tag_cache = {}  # Cache for tags we've already found/created
    parse_options(argv)
  end

  def run
    print_header
    return unless confirm_execution

    HTM::Database.setup
    process_tags
    print_summary
  end

  private

  def parse_options(argv)
    parser = OptionParser.new do |opts|
      opts.banner = usage_banner

      opts.separator ""
      opts.separator "Options:"

      opts.on("--[no-]dryrun", "Dry run mode (default: true). Use --no-dryrun to apply changes.") do |v|
        @options[:dryrun] = v
      end

      opts.on("-v", "--verbose", "Show detailed output for each tag processed") do
        @options[:verbose] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit 0
      end

      opts.on("--version", "Show version") do
        puts "backfill_parent_tags v#{VERSION}"
        exit 0
      end

      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  # Preview what would be done (default)"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/backfill_parent_tags.rb --dryrun"
      opts.separator ""
      opts.separator "  # Preview with detailed output"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/backfill_parent_tags.rb --dryrun --verbose"
      opts.separator ""
      opts.separator "  # Apply changes to database"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/backfill_parent_tags.rb --no-dryrun"
      opts.separator ""
      opts.separator "Environment Variables:"
      opts.separator "  HTM_DATABASE__URL  PostgreSQL connection URL (required)"
      opts.separator ""
    end

    remaining = parser.parse!(argv)

    # Check for unexpected positional arguments
    if remaining.any?
      warn "\033[1;31mError: unexpected argument(s): #{remaining.join(', ')}\033[0m"
      warn
      puts parser
      exit 1
    end
  rescue OptionParser::InvalidOption => e
    warn "\033[1;31mError: #{e.message}\033[0m"
    warn
    puts parser
    exit 1
  end

  def usage_banner
    <<~BANNER
      Usage: ruby scripts/backfill_parent_tags.rb [options]

      Backfills missing parent tags for hierarchical tag names in the HTM database.

      For a tag like "database:postgresql:extensions", this script:
        1. Creates parent tags: "database", "database:postgresql" (if missing)
        2. Associates nodes with all parent tags via node_tags records

      By default, runs in dry-run mode (no changes made). Use --no-dryrun to apply.
    BANNER
  end

  def print_header
    puts "=" * 70
    puts "Parent Tag Backfill Script v#{VERSION}"
    puts "=" * 70
    puts "Mode:     #{options[:dryrun] ? 'DRY RUN (no changes will be made)' : 'LIVE (will modify database)'}"
    puts "Verbose:  #{options[:verbose] ? 'Yes' : 'No'}"
    puts "Database: #{masked_database_url}"
    puts "=" * 70
    puts
  end

  def masked_database_url
    HTM.config.database.url&.gsub(/:[^:@]+@/, ':***@') || '(not configured)'
  end

  def confirm_execution
    return true if options[:dryrun]

    puts "\033[1;33m⚠️  WARNING: This will modify the database!\033[0m"
    puts
    puts "This script will:"
    puts "  • Create new tag records for missing parent tags"
    puts "  • Create new node_tag records to associate nodes with parent tags"
    puts
    print "Are you sure you want to continue? [y/N] "

    response = $stdin.gets&.strip&.downcase
    unless response == 'y' || response == 'yes'
      puts
      puts "Aborted. No changes were made."
      return false
    end

    puts
    true
  end

  def process_tags
    hierarchical_tags = HTM::Models::Tag.where("name LIKE '%:%'").order(:name)
    total_count = hierarchical_tags.count

    puts "Found #{total_count} hierarchical tags to process"
    puts

    if total_count == 0
      puts "No hierarchical tags found. Nothing to do."
      return
    end

    progressbar = ProgressBar.create(
      title: options[:dryrun] ? "Analyzing" : "Processing",
      total: total_count,
      format: "%t: |%B| %c/%C (%P%%) %e",
      output: $stdout
    )

    hierarchical_tags.find_each do |tag|
      process_tag(tag)
      progressbar.increment
    end

    puts
  end

  def process_tag(tag)
    @stats[:tags_scanned] += 1

    # Get parent names only (excludes the tag itself since it already exists)
    parent_names = parent_tag_names(tag.name)
    return if parent_names.empty?

    log_verbose "Processing: #{tag.name}"
    log_verbose "  Parents needed: #{parent_names.join(', ')}"

    # OPTIMIZATION: Batch lookup - find all existing parents in one query
    parent_tags = find_or_create_parent_tags_batch(parent_names)

    # Get nodes associated with this tag
    node_ids = HTM::Models::NodeTag.where(tag_id: tag.id).pluck(:node_id)

    if node_ids.any?
      log_verbose "  Nodes with this tag: #{node_ids.count}"

      # Associate nodes with all parent tags
      parent_tags.each do |parent_tag|
        next unless parent_tag
        create_missing_node_tags(parent_tag, node_ids)
      end
    end

    log_verbose "" if options[:verbose]
  end

  # Extract parent tag names from a hierarchical tag
  # For "a:b:c:d" returns ["a", "a:b", "a:b:c"] (excludes "a:b:c:d" since it already exists)
  def parent_tag_names(tag_name)
    levels = tag_name.split(':')
    return [] if levels.size <= 1

    # Generate all parent paths (exclusive of the full tag name)
    (1...levels.size).map { |i| levels[0, i].join(':') }
  end

  # OPTIMIZATION: Find or create multiple parent tags with batched queries
  def find_or_create_parent_tags_batch(names)
    return [] if names.empty?

    # Check cache first
    uncached_names = names.reject { |name| @tag_cache.key?(name) }
    cached_names = names - uncached_names

    cached_names.each do |name|
      @stats[:cache_hits] += 1
      log_verbose "  Tag '#{name}' (cached, id: #{@tag_cache[name]&.id || 'pending'})"
    end

    if uncached_names.any?
      # Single query to find all existing tags
      existing_tags = HTM::Models::Tag.where(name: uncached_names).index_by(&:name)

      # Process each uncached name
      uncached_names.each do |name|
        if existing_tags[name]
          @tag_cache[name] = existing_tags[name]
          log_verbose "  Tag '#{name}' already exists (id: #{existing_tags[name].id})"
        else
          # Tag doesn't exist - create it
          @tag_cache[name] = create_parent_tag(name)
        end
      end
    end

    # Return tags in original order
    names.map { |name| @tag_cache[name] }
  end

  def create_parent_tag(name)
    if options[:dryrun]
      log_verbose "  [DRY RUN] Would create tag: '#{name}'"
      @stats[:parent_tags_created] += 1
      return nil
    end

    begin
      tag = HTM::Models::Tag.create!(name: name)
      log_verbose "  Created tag: '#{name}' (id: #{tag.id})"
      @stats[:parent_tags_created] += 1
      tag
    rescue ActiveRecord::RecordInvalid => e
      error_msg = "Failed to create tag '#{name}': #{e.message}"
      log_verbose "  ERROR: #{error_msg}"
      @stats[:errors] << error_msg
      nil
    rescue ActiveRecord::RecordNotUnique
      # Race condition - tag was created by another process, fetch it
      tag = HTM::Models::Tag.find_by(name: name)
      log_verbose "  Tag '#{name}' created by concurrent process (id: #{tag&.id})"
      tag
    end
  end

  def create_missing_node_tags(parent_tag, node_ids)
    # Find which nodes are NOT already associated with this parent tag
    existing_node_ids = HTM::Models::NodeTag
      .where(tag_id: parent_tag.id, node_id: node_ids)
      .pluck(:node_id)

    missing_node_ids = node_ids - existing_node_ids
    return if missing_node_ids.empty?

    if options[:dryrun]
      log_verbose "  [DRY RUN] Would create #{missing_node_ids.count} node_tags for '#{parent_tag.name}'"
      @stats[:node_tags_created] += missing_node_ids.count
      return
    end

    # OPTIMIZATION: Batch insert node_tags
    records = missing_node_ids.map do |node_id|
      { node_id: node_id, tag_id: parent_tag.id }
    end

    begin
      # Use insert_all to batch insert (ignores duplicates)
      result = HTM::Models::NodeTag.insert_all(records)
      created_count = result.count
      @stats[:node_tags_created] += created_count
      log_verbose "  Created #{created_count} node_tags for '#{parent_tag.name}'" if created_count > 0
    rescue ActiveRecord::RecordInvalid => e
      # Fallback to individual inserts if batch fails
      created_count = 0
      missing_node_ids.each do |node_id|
        begin
          HTM::Models::NodeTag.create!(node_id: node_id, tag_id: parent_tag.id)
          created_count += 1
          @stats[:node_tags_created] += 1
        rescue ActiveRecord::RecordNotUnique
          # Already exists, skip
        rescue ActiveRecord::RecordInvalid => e
          error_msg = "Failed to create node_tag (node: #{node_id}, tag: #{parent_tag.id}): #{e.message}"
          log_verbose "  ERROR: #{error_msg}"
          @stats[:errors] << error_msg
        end
      end
      log_verbose "  Created #{created_count} node_tags for '#{parent_tag.name}' (fallback)" if created_count > 0
    end
  end

  def log_verbose(message)
    puts message if options[:verbose]
  end

  def print_summary
    puts "=" * 70
    puts "Summary"
    puts "=" * 70
    puts "Tags scanned:        #{@stats[:tags_scanned]}"
    puts "Parent tags created: #{@stats[:parent_tags_created]}"
    puts "Node tags created:   #{@stats[:node_tags_created]}"
    puts "Cache hits:          #{@stats[:cache_hits]}"

    if @stats[:errors].any?
      puts
      puts "\033[1;31mErrors (#{@stats[:errors].count}):\033[0m"
      @stats[:errors].first(10).each { |e| puts "  • #{e}" }
      puts "  ... and #{@stats[:errors].count - 10} more" if @stats[:errors].count > 10
    end

    puts
    if options[:dryrun]
      puts "\033[1;36mThis was a DRY RUN. No changes were made.\033[0m"
      puts "Run with --no-dryrun to apply changes."
    else
      puts "\033[1;32m✓ Backfill complete!\033[0m"
    end
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  begin
    ParentTagBackfill.run
  rescue Interrupt
    puts "\n\nAborted by user."
    exit 130
  rescue => e
    warn "\033[1;31mFATAL ERROR: #{e.class.name} - #{e.message}\033[0m"
    warn e.backtrace.first(10).join("\n") if ENV['DEBUG']
    exit 1
  end
end
