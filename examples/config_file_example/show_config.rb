#!/usr/bin/env ruby
# frozen_string_literal: true

# Show Config Example
#
# Demonstrates how anyway_config automatically loads configuration
# from standard locations and traces the source of each value.
#
# Config loading priority (lowest to highest):
#   1. Bundled defaults: lib/htm/config/defaults.yml (ships with gem)
#   2. XDG user config: ~/.config/htm/htm.yml
#   3. Project config: ./config/htm.yml
#   4. Local overrides: ./config/htm.local.yml  <-- This example uses this
#   5. HTM_CONF file: path specified by HTM_CONF env var (overrides above)
#   6. Environment variables (HTM_*)
#
# Usage:
#   ruby show_config.rb
#   HTM_ENV=production ruby show_config.rb
#   HTM_EMBEDDING__MODEL=mxbai-embed-large ruby show_config.rb
#   HTM_CONF=/path/to/custom.yml ruby show_config.rb

require_relative '../../lib/htm'
require 'amazing_print'

puts <<~HEADER

  HTM Configuration Example
  #{'=' * 60}

  Environment: #{HTM.config.environment}

  Config sources checked:
    - Bundled defaults: lib/htm/config/defaults.yml
    - XDG config: #{HTM::Config.xdg_config_file}
    - Project config: ./config/htm.yml
    - Local overrides: ./config/htm.local.yml
    - HTM_CONF override: #{ENV['HTM_CONF'] || '(not set)'}
    - Environment variables: HTM_*

  Active XDG config: #{HTM::Config.active_xdg_config_file || '(none found)'}

  #{'-' * 60}
  Configuration with Sources:
  #{'-' * 60}

HEADER

# Get the source trace from anyway_config
trace = HTM.config.to_source_trace

# Helper to format source information
def format_source(source)
  return "unknown" unless source

  case source[:type]
  when :defaults
    "defaults"
  when :yml
    path = source[:path]
    # Shorten the path for readability
    if path.include?('defaults.yml')
      "defaults.yml"
    elsif path.include?('htm.local.yml')
      "htm.local.yml"
    elsif path.include?('htm.yml')
      "htm.yml"
    else
      File.basename(path)
    end
  when :env
    "ENV[#{source[:key]}]"
  when :user
    "code"
  else
    source[:type].to_s
  end
end

# Recursively print config with sources
def print_config(trace, indent = 0)
  trace.each do |key, data|
    prefix = "  " * indent

    if data.is_a?(Hash) && data[:value].nil? && data[:source].nil?
      # Nested section
      puts "\n#{prefix}#{key}:"
      print_config(data, indent + 1)
    elsif data.is_a?(Hash) && data.key?(:value)
      # Leaf value with source
      value = data[:value]
      source = format_source(data[:source])

      # Format value for display
      display_value = case value
      when nil then "nil"
      when String then value.empty? ? '""' : "\"#{value}\""
      when Symbol then ":#{value}"
      else value.inspect
      end

      # Truncate long values
      display_value = display_value[0..50] + "..." if display_value.length > 50

      puts "#{prefix}#{key}: #{display_value}  # from: #{source}"
    else
      # Fallback for unexpected structure
      puts "#{prefix}#{key}: #{data.inspect}"
    end
  end
end

print_config(trace)

puts <<~LEGEND

  #{'-' * 60}
  Legend:
    defaults.yml  = bundled gem defaults
    htm.local.yml = ./config/htm.local.yml
    htm.yml       = ./config/htm.yml or ~/.config/htm/htm.yml
    ENV[KEY]      = environment variable
    code          = set programmatically

LEGEND
