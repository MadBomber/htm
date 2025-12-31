# frozen_string_literal: true

require 'uri'

class HTM
  class Config
    module Database
      # ==========================================================================
      # Database Component Accessors
      # ==========================================================================
      #
      # These methods provide convenient access to database components.
      # Components are automatically reconciled at config load time:
      #   - If database.url exists: components are extracted and populated
      #   - If database.url is missing: it's built from components
      #
      # ==========================================================================

      # @return [String, nil] the database host
      def database_host
        database.host
      end

      # @return [Integer, nil] the database port
      def database_port
        database.port
      end

      # @return [String, nil] the database name
      def database_name
        database.name
      end

      # @return [String, nil] the database user
      def database_user
        database.user
      end

      # @return [String, nil] the database password
      def database_password
        database.password
      end

      def database_config
        url = database_url
        return {} unless url

        uri = URI.parse(url)

        # Coercion now merges env vars with SCHEMA defaults, so pool_size/timeout
        # are always available even when only HTM_DATABASE__URL is set
        {
          adapter: 'postgresql',
          host: uri.host,
          port: uri.port || 5432,
          database: uri.path&.sub(%r{^/}, ''),
          username: uri.user,
          password: uri.password,
          pool: database.pool_size.to_i,
          timeout: database.timeout.to_i,
          sslmode: database.sslmode,
          encoding: 'unicode',
          prepared_statements: false,
          advisory_locks: false
        }.compact
      end

      def database_configured?
        url = database_url
        (url && !url.empty?) || (database.name && !database.name.empty?)
      end

      # Database convenience methods
      def database_url
        url = database.url
        return url if url && !url.empty?

        build_database_url
      end

      # Validate that database is configured for the current environment
      #
      # @raise [HTM::ConfigurationError] if database is not configured
      # @return [true] if database is configured
      def validate_database!
        validate_environment!

        unless database_configured?
          raise HTM::ConfigurationError,
            "No database configured for environment '#{environment}'. " \
            "Set HTM_DATABASE__URL or HTM_DATABASE__NAME, " \
            "or add database.name to the '#{environment}:' section in your config."
        end

        true
      end

      # ==========================================================================
      # Database Naming Convention
      # ==========================================================================
      #
      # Database names MUST follow the convention: {service_name}_{environment}
      #
      # Examples:
      #   - htm_development
      #   - htm_test
      #   - htm_production
      #   - payroll_development
      #   - payroll_test
      #
      # This ensures:
      #   1. Database names are predictable and self-documenting
      #   2. Environment mismatches are impossible (exact match required)
      #   3. Service isolation (can't accidentally use another app's database)
      #
      # ==========================================================================

      # Returns the expected database name based on service.name and environment
      #
      # @return [String] expected database name in format "{service_name}_{environment}"
      #
      # @example
      #   config.service.name = "htm"
      #   HTM_ENV = "test"
      #   config.expected_database_name  # => "htm_test"
      #
      def expected_database_name
        "#{service_name}_#{environment}"
      end

      # Extract the actual database name from URL or config
      #
      # @return [String, nil] the database name
      def actual_database_name
        url = database&.url
        if url && !url.empty?
          # Parse database name from URL: postgresql://user@host:port/dbname
          uri = URI.parse(url) rescue nil
          return uri&.path&.sub(%r{^/}, '')
        end

        database&.name
      end

      # Validate that the database name follows the naming convention
      #
      # Database names must be: {service_name}_{environment}
      #
      # @raise [HTM::ConfigurationError] if database name doesn't match expected
      # @return [true] if database name is valid
      #
      # @example Valid configurations
      #   HTM_ENV=test, service.name=htm, database=htm_test        # OK
      #   HTM_ENV=production, service.name=payroll, database=payroll_production  # OK
      #
      # @example Invalid configurations (will raise)
      #   HTM_ENV=test, service.name=htm, database=htm_production  # Wrong environment
      #   HTM_ENV=test, service.name=htm, database=payroll_test    # Wrong service
      #   HTM_ENV=test, service.name=htm, database=mydb            # Wrong format
      #
      def validate_database_name!
        actual = actual_database_name
        expected = expected_database_name

        return true if actual == expected

        raise HTM::ConfigurationError,
          "Database name '#{actual}' does not match expected '#{expected}'.\n" \
          "Database names must follow the convention: {service_name}_{environment}\n" \
          "  Service name: #{service_name}\n" \
          "  Environment:  #{environment}\n" \
          "  Expected:     #{expected}\n" \
          "  Actual:       #{actual}\n\n" \
          "Either:\n" \
          "  - Set HTM_DATABASE__URL to point to '#{expected}'\n" \
          "  - Set HTM_DATABASE__NAME=#{expected}\n" \
          "  - Change HTM_ENV to match the database suffix"
      end

      # Check if the database name matches the expected convention
      #
      # @return [Boolean] true if database name matches expected
      def valid_database_name?
        actual_database_name == expected_database_name
      end

      # ==========================================================================
      # Database URL/Components Parsing
      # ==========================================================================

      # Parse database URL into component hash
      #
      # @return [Hash, nil] parsed components or nil if no URL
      def parse_database_url
        url = database&.url
        return nil if url.nil? || url.empty?

        uri = URI.parse(url) rescue nil
        return nil unless uri

        # Parse query string for sslmode
        query_params = URI.decode_www_form(uri.query || '').to_h
        sslmode = query_params['sslmode']

        {
          host: uri.host,
          port: uri.port,
          name: uri.path&.sub(%r{^/}, ''),
          user: uri.user,
          password: uri.password,
          sslmode: sslmode
        }.compact
      end

      private

      def build_database_url
        return nil unless database.name && !database.name.empty?

        auth = if database.user && !database.user.empty?
          database.password && !database.password.empty? ? "#{database.user}:#{database.password}@" : "#{database.user}@"
        else
          ''
        end

        url = "postgresql://#{auth}#{database.host}:#{database.port}/#{database.name}"

        # Add sslmode as query parameter if set
        if database.sslmode && !database.sslmode.empty?
          url += "?sslmode=#{database.sslmode}"
        end

        url
      end

      # ==========================================================================
      # Database Configuration Reconciliation
      # ==========================================================================
      #
      # Ensures database.url and database.* components are synchronized:
      #
      # 1. If database.url exists:
      #    - Extract all components from the URL
      #    - For each component: if config has a different value → ERROR
      #    - For each component: if config is missing → populate from URL
      #
      # 2. If database.url is missing but components exist:
      #    - Verify minimum required components (at least database.name)
      #    - Build and set database.url from components
      #    - If insufficient components → ERROR
      #
      # This runs automatically at config load time via on_load callback.
      #
      # ==========================================================================

      def reconcile_database_config
        url = database&.url
        has_url = url && !url.empty?

        if has_url
          reconcile_from_url
        else
          reconcile_from_components
        end
      end

      def reconcile_from_url
        url_components = parse_database_url
        return unless url_components

        # URL is the source of truth - populate all components from it
        # This overwrites any values from config files (they're just defaults)
        %i[host port name user password sslmode].each do |component|
          url_value = url_components[component]
          next if url_value.nil?

          database.send("#{component}=", url_value)
        end
      end

      def reconcile_from_components
        # Check what components we have
        name = database&.name
        has_name = name && !name.empty?

        # If no database config at all, that's fine - might not need database
        # Just return without error; validate_database! will catch if needed later
        return unless has_name || has_any_database_component?

        # If name is missing, auto-generate from service.name and environment
        # Format: {service_name}_{environment} (e.g., "htm_development")
        unless has_name
          database.name = expected_database_name
        end

        # Use defaults for host/port if not set
        database.host = 'localhost' if database.host.nil? || database.host.empty?
        database.port = 5432 if database.port.nil?

        # Build and set the URL
        database.url = build_database_url
      end

      def has_any_database_component?
        %i[host port user password].any? do |comp|
          val = database.send(comp)
          next false if val.nil?
          next false if val.respond_to?(:empty?) && val.empty?
          # Skip defaults
          next false if comp == :host && val == 'localhost'
          next false if comp == :port && val == 5432
          true
        end
      end
    end
  end
end
