# frozen_string_literal: true

pin "application"
# Turbo removed - causes issues with CDN-based setup, using vanilla JS instead
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
