# frozen_string_literal: true

# Override the examples_helper.rb :inline setting for the Rails app
# Use fiber-based async jobs for better responsiveness
HTM.configure do |config|
  config.job.backend = :fiber
end
