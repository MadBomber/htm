# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'

# Require HTM - this will auto-load the Railtie
require 'htm'

module HtmRailsExample
  class Application < Rails::Application
    config.load_defaults 7.1

    # Full-stack Rails app (not API-only)
    config.api_only = false

    # Use inline jobs for simplicity in demo
    config.active_job.queue_adapter = :inline

    # Generators config
    config.generators do |g|
      g.test_framework nil
      g.stylesheets false
      g.javascripts false
      g.helper false
    end
  end
end
