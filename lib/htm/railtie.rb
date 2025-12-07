# frozen_string_literal: true

require 'rails/railtie'

class HTM
  # Rails Railtie for automatic HTM configuration in Rails applications
  #
  # This railtie automatically configures HTM when Rails boots:
  # - Sets logger to Rails.logger
  # - Sets job backend to :active_job
  # - Loads Rake tasks
  # - Configures test environment for synchronous jobs
  #
  # @example Rails application
  #   # HTM is automatically configured on Rails boot
  #   # No additional setup required
  #
  # @example Custom configuration
  #   # config/initializers/htm.rb
  #   HTM.configure do |config|
  #     config.embedding_model = 'custom-model'
  #     config.tag_model = 'custom-tag-model'
  #   end
  #
  class Railtie < Rails::Railtie
    railtie_name :htm

    # Configure HTM before Rails initializers run
    initializer "htm.configure" do |app|
      HTM.configure do |config|
        # Use Rails logger
        config.logger = Rails.logger

        # Use ActiveJob for background jobs in Rails
        config.job_backend = :active_job unless Rails.env.test?

        # Use inline execution in test environment for synchronous behavior
        config.job_backend = :inline if Rails.env.test?
      end

      HTM.logger.info "HTM initialized for Rails application"
      HTM.logger.debug "HTM job backend: #{HTM.configuration.job_backend}"
    end

    # Load Rake tasks
    rake_tasks do
      load File.expand_path('../tasks/htm.rake', __dir__)
      load File.expand_path('../tasks/jobs.rake', __dir__)
    end

    # Add middleware for connection management (if needed)
    initializer "htm.middleware" do |app|
      # Middleware can be added here if needed for connection cleanup
      # app.middleware.use HTM::Middleware
    end

    # Optionally verify database connection on boot (development only)
    config.after_initialize do
      if Rails.env.development?
        begin
          HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?
          HTM::ActiveRecordConfig.verify_extensions!
          HTM.logger.info "HTM database connection verified"
        rescue StandardError => e
          HTM.logger.warn "HTM database connection check failed: #{e.message}"
          HTM.logger.warn "Set HTM_DBURL environment variable or configure database.yml"
        end
      end
    end

  end
end
