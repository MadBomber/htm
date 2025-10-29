# frozen_string_literal: true

require_relative 'errors'

class HTM
  # Tag Service - LLM-based hierarchical tag extraction
  #
  # HTM uses this service to automatically extract hierarchical topic tags
  # from node content. Tags are extracted in the format root:level1:level2.
  #
  # Supported providers:
  # - :ollama - Ollama with configurable model (default: llama3)
  # - :openai - OpenAI (requires OPENAI_API_KEY)
  #
  class TagService
    # Default models for tag extraction
    DEFAULT_MODELS = {
      ollama: 'llama3',
      openai: 'gpt-4o-mini'
    }.freeze

    attr_reader :provider, :model

    # Initialize tag extraction service
    #
    # @param provider [Symbol] LLM provider (:ollama, :openai)
    # @param model [String] Model name
    # @param base_url [String] Base URL for Ollama
    #
    def initialize(provider = :ollama, model: nil, base_url: nil)
      @provider = provider
      @model = model || DEFAULT_MODELS[provider]
      @base_url = base_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
    end

    # Extract hierarchical tags from content
    #
    # @param content [String] Text to analyze
    # @param existing_ontology [Array<String>] Sample of existing tags for context
    # @return [Array<String>] Extracted tag names in format root:level1:level2
    #
    def extract_tags(content, existing_ontology: [])
      prompt = build_extraction_prompt(content, existing_ontology)
      response = call_llm(prompt)
      parse_and_validate_tags(response)
    end

    private

    def build_extraction_prompt(content, ontology_sample)
      ontology_context = if ontology_sample.any?
        sample_tags = ontology_sample.sample([ontology_sample.size, 20].min)
        "Existing ontology includes: #{sample_tags.join(', ')}\n"
      else
        "This is a new ontology - create appropriate hierarchical tags.\n"
      end

      <<~PROMPT
        Extract hierarchical topic tags from the following text.

        #{ontology_context}
        Format: root:level1:level2:level3 (use colons to separate levels)

        Rules:
        - Use lowercase letters, numbers, and hyphens only
        - Maximum depth: 5 levels
        - Return 2-5 tags per text
        - Tags should be reusable and consistent
        - Prefer existing ontology tags when applicable
        - Use hyphens for multi-word terms (e.g., natural-language-processing)

        Text: #{content}

        Return ONLY the topic tags, one per line, no explanations.
      PROMPT
    end

    def call_llm(prompt)
      case @provider
      when :ollama
        call_ollama(prompt)
      when :openai
        call_openai(prompt)
      else
        raise HTM::TagError, "Unknown provider: #{@provider}"
      end
    end

    def call_ollama(prompt)
      require 'net/http'
      require 'json'

      uri = URI("#{@base_url}/api/generate")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate({
        model: @model,
        prompt: prompt,
        stream: false,
        system: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail',
        options: {
          temperature: 0  # Deterministic output
        }
      })

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        error_details = "#{response.code} #{response.message}"
        begin
          error_body = JSON.parse(response.body)
          error_details += " - #{error_body['error']}" if error_body['error']
        rescue
          error_details += " - #{response.body[0..200]}" unless response.body.empty?
        end
        raise HTM::TagError, "Ollama API error: #{error_details}"
      end

      result = JSON.parse(response.body)
      result['response']
    rescue JSON::ParserError => e
      raise HTM::TagError, "Failed to parse Ollama response: #{e.message}"
    rescue HTM::TagError
      raise
    rescue StandardError => e
      raise HTM::TagError, "Failed to call Ollama: #{e.message}"
    end

    def call_openai(prompt)
      require 'net/http'
      require 'json'

      api_key = ENV['OPENAI_API_KEY']
      unless api_key
        raise HTM::TagError, "OPENAI_API_KEY environment variable not set"
      end

      uri = URI('https://api.openai.com/v1/chat/completions')
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request.body = JSON.generate({
        model: @model,
        messages: [
          {
            role: 'system',
            content: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0
      })

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise HTM::TagError, "OpenAI API error: #{response.code} #{response.message}"
      end

      result = JSON.parse(response.body)
      result.dig('choices', 0, 'message', 'content')
    rescue JSON::ParserError => e
      raise HTM::TagError, "Failed to parse OpenAI response: #{e.message}"
    rescue HTM::TagError
      raise
    rescue StandardError => e
      raise HTM::TagError, "Failed to call OpenAI: #{e.message}"
    end

    def parse_and_validate_tags(response)
      return [] if response.nil? || response.strip.empty?

      # Parse response (one tag per line)
      tags = response.split("\n").map(&:strip).reject(&:empty?)

      # Validate format: lowercase alphanumeric + hyphens + colons
      valid_tags = tags.select do |tag|
        tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
      end

      # Limit depth to 5 levels (4 colons maximum)
      valid_tags.select { |tag| tag.count(':') < 5 }
    end
  end
end
