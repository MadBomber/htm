# frozen_string_literal: true

# Configure HTM for the Rails chatbot app
HTM.configure do |config|
  # Use the examples database which contains the knowledge base
  # This overrides HTM_ENV=development to use the populated database
  config.database.url = ENV.fetch('HTM_CHATBOT_DATABASE_URL', 'postgresql://localhost:5432/htm_examples')

  # Use fiber-based async jobs for better responsiveness
  config.job.backend = :fiber
end

Rails.logger.info "HTM initialized for Rails application"
Rails.logger.info "HTM database: #{HTM.configuration.database_url}"
