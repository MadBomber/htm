# frozen_string_literal: true

require 'anyway_config'
require 'yaml'

class HTM
  module Loaders
    # Bundled Defaults Loader for Anyway Config
    #
    # Loads default configuration values from a YAML file bundled with the gem.
    # This ensures defaults are always available regardless of where HTM is installed.
    #
    # The defaults.yml file has this structure:
    #   defaults:      # Base values for all environments
    #     database:
    #       host: localhost
    #       port: 5432
    #   development:   # Overrides for development
    #     database:
    #       name: htm_development
    #   test:          # Overrides for test
    #     database:
    #       name: htm_test
    #   production:    # Overrides for production
    #     database:
    #       sslmode: require
    #
    # This loader deep-merges `defaults` with the current environment's overrides.
    #
    # This loader runs at LOWEST priority (before XDG), so all other sources
    # can override these bundled defaults:
    # 1. Bundled defaults (this loader)
    # 2. XDG user config (~/.config/htm/htm.yml)
    # 3. Project config (./config/htm.yml)
    # 4. Local overrides (./config/htm.local.yml)
    # 5. Environment variables (HTM_*)
    # 6. Programmatic (configure block)
    #
    class DefaultsLoader < Anyway::Loaders::Base
      DEFAULTS_PATH = File.expand_path('../config/defaults.yml', __dir__).freeze

      class << self
        # Returns the path to the bundled defaults file
        #
        # @return [String] path to defaults.yml
        def defaults_path
          DEFAULTS_PATH
        end

        # Check if defaults file exists
        #
        # @return [Boolean]
        def defaults_exist?
          File.exist?(DEFAULTS_PATH)
        end

        # Load and parse the raw YAML content
        #
        # @return [Hash] parsed YAML with symbolized keys
        def load_raw_yaml
          return {} unless defaults_exist?

          content = File.read(defaults_path)
          YAML.safe_load(
            content,
            permitted_classes: [Symbol],
            symbolize_names: true,
            aliases: true
          ) || {}
        rescue Psych::SyntaxError => e
          warn "HTM: Failed to parse bundled defaults #{defaults_path}: #{e.message}"
          {}
        end

        # Extract the schema (attribute names) from the defaults section
        #
        # @return [Hash] the defaults section containing all attribute definitions
        def schema
          raw = load_raw_yaml
          raw[:defaults] || {}
        end
      end

      def call(name:, **_options)
        return {} unless self.class.defaults_exist?

        trace!(:bundled_defaults, path: self.class.defaults_path) do
          load_and_merge_for_environment
        end
      end

      private

      # Load defaults and deep merge with environment-specific overrides
      #
      # @return [Hash] merged configuration for current environment
      def load_and_merge_for_environment
        raw = self.class.load_raw_yaml
        return {} if raw.empty?

        # Start with the defaults section
        defaults = raw[:defaults] || {}

        # Deep merge with environment-specific overrides
        env = current_environment
        env_overrides = raw[env.to_sym] || {}

        deep_merge(defaults, env_overrides)
      end

      # Deep merge two hashes, with overlay taking precedence
      #
      # @param base [Hash] base configuration
      # @param overlay [Hash] overlay configuration (takes precedence)
      # @return [Hash] merged result
      def deep_merge(base, overlay)
        base.merge(overlay) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      # Determine the current environment
      #
      # Priority: HTM_ENV > RAILS_ENV > RACK_ENV > 'development'
      #
      # @return [String] current environment name
      def current_environment
        ENV['HTM_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end
    end
  end
end

# Register the defaults loader at LOWEST priority (before :yml loader)
# This ensures bundled defaults are overridden by all other sources:
# - XDG user config (registered after this, also before :yml)
# - Project config (:yml loader)
# - Environment variables (:env loader)
Anyway.loaders.insert_before :yml, :bundled_defaults, HTM::Loaders::DefaultsLoader
