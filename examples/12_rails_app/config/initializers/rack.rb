# frozen_string_literal: true

# Increase multipart file upload limit for directory uploads
# Default is 128 parts, increase to 4096 for large directories
Rack::Utils.multipart_part_limit = 4096
