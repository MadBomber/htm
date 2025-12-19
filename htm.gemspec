# frozen_string_literal: true

require_relative "lib/htm/version"

Gem::Specification.new do |spec|
  spec.name = "htm"
  spec.version = HTM::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "Hierarchical Temporal Memory for LLM robots"
  spec.description = <<~DESC
    HTM (Hierarchical Temporal Memory) provides intelligent memory/context management for
    LLM-based applications. It implements a two-tier memory system with
    durable long-term storage (PostgreSQL) and token-limited working
    memory, enabling applications to recall context from past conversations using RAG
    (Retrieval-Augmented Generation) techniques.
  DESC
  spec.homepage = "https://github.com/madbomber/htm"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["htm_mcp"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "pg", ">= 1.5.0"
  spec.add_dependency "neighbor"
  spec.add_dependency "activerecord"
  spec.add_dependency "tiktoken_ruby"
  spec.add_dependency "ruby_llm"
  spec.add_dependency "lru_redux"
  spec.add_dependency "ruby-progressbar"
  spec.add_dependency "chronic"
  spec.add_dependency "fast-mcp"
  spec.add_dependency "baran"
  # Optional runtime dependencies for different job backends
  # - ActiveJob (bundled with Rails)
  # - Sidekiq (add to Gemfile if using :sidekiq backend)

  # Development dependencies
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "debug_me"
  spec.add_development_dependency "ruby_llm-mcp"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "yard-markdown"
end
