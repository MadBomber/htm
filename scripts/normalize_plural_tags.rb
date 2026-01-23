#!/usr/bin/env ruby
# frozen_string_literal: true

# Normalize Plural Tags
#
# This one-off script scans the existing tags table and normalizes
# plural tag level names to their singular forms. It merges plural
# tags into existing singular tags when both exist.
#
# Run with --help for usage information.

require 'optparse'
require 'ruby-progressbar'
require_relative '../lib/htm'

class PluralTagNormalizer
  VERSION = '0.0.1'

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
      plural_tags_found: 0,
      tags_renamed: 0,
      tags_merged: 0,
      node_tags_reassigned: 0,
      errors: []
    }
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
        puts "normalize_plural_tags v#{VERSION}"
        exit 0
      end

      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  # Preview what would be done (default)"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/normalize_plural_tags.rb --dryrun"
      opts.separator ""
      opts.separator "  # Preview with detailed output"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/normalize_plural_tags.rb --dryrun --verbose"
      opts.separator ""
      opts.separator "  # Apply changes to database"
      opts.separator "  HTM_DATABASE__URL=\"...\" ruby scripts/normalize_plural_tags.rb --no-dryrun"
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
      Usage: ruby scripts/normalize_plural_tags.rb [options]

      Normalizes plural tag level names to singular forms in the HTM database.

      For a tag like "users:frameworks:models", this script:
        1. Singularizes each level: "user:framework:model"
        2. If singular tag exists, merges node associations
        3. If singular tag doesn't exist, renames the plural tag

      By default, runs in dry-run mode (no changes made). Use --no-dryrun to apply.
    BANNER
  end

  def print_header
    puts "=" * 70
    puts "Plural Tag Normalizer v#{VERSION}"
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
    puts "  • Rename plural tags to singular forms"
    puts "  • Merge node associations when both plural and singular exist"
    puts "  • Delete redundant plural tags after merging"
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
    all_tags = HTM::Models::Tag.order(:name)
    total_count = all_tags.count

    puts "Found #{total_count} tags to scan"
    puts

    if total_count == 0
      puts "No tags found. Nothing to do."
      return
    end

    progressbar = ProgressBar.create(
      title: options[:dryrun] ? "Analyzing" : "Processing",
      total: total_count,
      format: "%t: |%B| %c/%C (%P%%) %e",
      output: $stdout
    )

    all_tags.paged_each do |tag|
      process_tag(tag)
      progressbar.increment
    end

    puts
  end

  def process_tag(tag)
    @stats[:tags_scanned] += 1

    # Singularize all levels of the tag
    singular_name = singularize_tag(tag.name)

    # If no change needed, skip
    return if singular_name == tag.name

    @stats[:plural_tags_found] += 1
    log_verbose "Found plural tag: '#{tag.name}' -> '#{singular_name}'"

    # Check if singular version already exists
    existing_singular = HTM::Models::Tag.first(name: singular_name)

    if existing_singular
      # Merge: reassign node_tags from plural to singular, then delete plural
      merge_tags(tag, existing_singular)
    else
      # Rename: just update the tag name
      rename_tag(tag, singular_name)
    end
  end

  def singularize_tag(tag_name)
    # Use the TagService's singularization logic for consistency
    HTM::TagService.singularize_tag_levels(tag_name)
  end

  def merge_tags(plural_tag, singular_tag)
    log_verbose "  Merging '#{plural_tag.name}' into '#{singular_tag.name}'"

    # Get node IDs associated with plural tag
    plural_node_ids = HTM::Models::NodeTag.where(tag_id: plural_tag.id).select_map(:node_id)

    if plural_node_ids.empty?
      log_verbose "    No nodes to reassign"
    else
      # Find which nodes already have the singular tag
      existing_node_ids = HTM::Models::NodeTag
        .where(tag_id: singular_tag.id, node_id: plural_node_ids)
        .select_map(:node_id)

      new_node_ids = plural_node_ids - existing_node_ids

      if options[:dryrun]
        log_verbose "    [DRY RUN] Would reassign #{new_node_ids.count} nodes from plural to singular"
        log_verbose "    [DRY RUN] Would delete #{existing_node_ids.count} duplicate node_tags"
        log_verbose "    [DRY RUN] Would delete plural tag '#{plural_tag.name}'"
        @stats[:node_tags_reassigned] += new_node_ids.count
        @stats[:tags_merged] += 1
      else
        begin
          HTM.db.transaction do
            # Reassign new nodes to singular tag
            if new_node_ids.any?
              HTM::Models::NodeTag.where(tag_id: plural_tag.id, node_id: new_node_ids)
                .update(tag_id: singular_tag.id)
              log_verbose "    Reassigned #{new_node_ids.count} nodes to '#{singular_tag.name}'"
              @stats[:node_tags_reassigned] += new_node_ids.count
            end

            # Delete duplicate node_tags (nodes that had both tags)
            if existing_node_ids.any?
              HTM::Models::NodeTag.where(tag_id: plural_tag.id, node_id: existing_node_ids).delete
              log_verbose "    Deleted #{existing_node_ids.count} duplicate node_tags"
            end

            # Delete the plural tag
            plural_tag.destroy
            log_verbose "    Deleted plural tag '#{plural_tag.name}'"
            @stats[:tags_merged] += 1
          end
        rescue Sequel::Error => e
          error_msg = "Failed to merge '#{plural_tag.name}' into '#{singular_tag.name}': #{e.message}"
          log_verbose "    ERROR: #{error_msg}"
          @stats[:errors] << error_msg
        end
      end
    end
  end

  def rename_tag(tag, new_name)
    if options[:dryrun]
      log_verbose "  [DRY RUN] Would rename '#{tag.name}' to '#{new_name}'"
      @stats[:tags_renamed] += 1
    else
      begin
        tag.update(name: new_name)
        log_verbose "  Renamed '#{tag.name}' to '#{new_name}'"
        @stats[:tags_renamed] += 1
      rescue Sequel::Error => e
        error_msg = "Failed to rename '#{tag.name}' to '#{new_name}': #{e.message}"
        log_verbose "  ERROR: #{error_msg}"
        @stats[:errors] << error_msg
      end
    end
  end

  def log_verbose(message)
    puts message if options[:verbose]
  end

  def print_summary
    puts "=" * 70
    puts "Summary"
    puts "=" * 70
    puts "Tags scanned:          #{@stats[:tags_scanned]}"
    puts "Plural tags found:     #{@stats[:plural_tags_found]}"
    puts "Tags renamed:          #{@stats[:tags_renamed]}"
    puts "Tags merged:           #{@stats[:tags_merged]}"
    puts "Node tags reassigned:  #{@stats[:node_tags_reassigned]}"

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
      puts "\033[1;32m✓ Normalization complete!\033[0m"
    end
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  begin
    PluralTagNormalizer.run
  rescue Interrupt
    puts "\n\nAborted by user."
    exit 130
  rescue => e
    warn "\033[1;31mFATAL ERROR: #{e.class.name} - #{e.message}\033[0m"
    warn e.backtrace.first(10).join("\n") if ENV['DEBUG']
    exit 1
  end
end
