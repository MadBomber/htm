# frozen_string_literal: true

class HTM
  class Config
    module Builder
      def build_default_logger
        logger = Logger.new($stdout)
        logger.level = log_level
        logger.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} -- HTM: #{msg}\n"
        end
        logger
      end

      def build_default_token_counter
        lambda do |text|
          require 'tiktoken_ruby' unless defined?(Tiktoken)
          encoder = Tiktoken.encoding_for_model("gpt-3.5-turbo")
          encoder.encode(text).length
        end
      end

      def build_default_embedding_generator
        lambda do |text|
          require 'ruby_llm' unless defined?(RubyLLM)

          configure_ruby_llm(embedding_provider)
          refresh_ollama_models! if embedding_provider == :ollama

          model = embedding_provider == :ollama ? normalize_ollama_model(embedding_model) : embedding_model
          response = RubyLLM.embed(text, model: model)
          embedding = extract_embedding_from_response(response)

          unless embedding.is_a?(Array) && embedding.all? { |v| v.is_a?(Numeric) }
            raise HTM::EmbeddingError, "Invalid embedding response format from #{embedding_provider}"
          end

          embedding
        end
      end

      def build_default_tag_extractor
        lambda do |text, existing_ontology = []|
          require 'ruby_llm' unless defined?(RubyLLM)

          configure_ruby_llm(tag_provider)
          refresh_ollama_models! if tag_provider == :ollama

          model = tag_provider == :ollama ? normalize_ollama_model(tag_model) : tag_model

          prompt = build_tag_extraction_prompt(text, existing_ontology)
          system_prompt = build_tag_system_prompt

          chat = RubyLLM.chat(model: model)
          chat.with_instructions(system_prompt)
          response = chat.ask(prompt)

          parse_tag_response(extract_text_from_response(response))
        end
      end

      def build_default_proposition_extractor
        lambda do |text|
          require 'ruby_llm' unless defined?(RubyLLM)

          configure_ruby_llm(proposition_provider)
          refresh_ollama_models! if proposition_provider == :ollama

          model = proposition_provider == :ollama ? normalize_ollama_model(proposition_model) : proposition_model

          prompt = build_proposition_extraction_prompt(text)
          system_prompt = build_proposition_system_prompt

          chat = RubyLLM.chat(model: model)
          chat.with_instructions(system_prompt)
          response = chat.ask(prompt)

          parse_proposition_response(extract_text_from_response(response))
        end
      end

      # ==========================================================================
      # Response Extraction Helpers
      # ==========================================================================

      def extract_embedding_from_response(response)
        return nil unless response

        case response
        when Array
          response
        when ->(r) { r.respond_to?(:vectors) }
          vectors = response.vectors
          vectors.is_a?(Array) && vectors.first.is_a?(Array) ? vectors.first : vectors
        when ->(r) { r.respond_to?(:to_a) }
          response.to_a
        when ->(r) { r.respond_to?(:embedding) }
          response.embedding
        else
          if response.respond_to?(:instance_variable_get)
            vectors = response.instance_variable_get(:@vectors)
            return vectors.first if vectors.is_a?(Array) && vectors.first.is_a?(Array)
            return vectors if vectors.is_a?(Array)
          end
          raise HTM::EmbeddingError, "Cannot extract embedding from response: #{response.class}"
        end
      end

      def extract_text_from_response(response)
        return '' unless response

        case response
        when String then response
        when ->(r) { r.respond_to?(:content) } then response.content.to_s
        when ->(r) { r.respond_to?(:text) } then response.text.to_s
        else response.to_s
        end
      end

      def parse_tag_response(text)
        tags = text.to_s.split("\n").map(&:strip).reject(&:empty?)
        valid_tags = tags.select { |tag| tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/ }
        valid_tags.select { |tag| tag.count(':') < max_tag_depth }
      end

      def parse_proposition_response(text)
        text.to_s
          .split("\n")
          .map(&:strip)
          .map { |line| line.sub(/^[-*]\s*/, '') }
          .map(&:strip)
          .reject(&:empty?)
      end

      # ==========================================================================
      # Prompt Builders
      # ==========================================================================

      def build_tag_extraction_prompt(text, existing_ontology)
        taxonomy_context = if existing_ontology.any?
          sample_tags = existing_ontology.sample([existing_ontology.size, 20].min)
          tag.taxonomy_context_existing % { sample_tags: sample_tags.join(', ') }
        else
          tag.taxonomy_context_empty
        end

        tag.user_prompt_template % {
          text: text,
          max_depth: max_tag_depth,
          taxonomy_context: taxonomy_context
        }
      end

      def build_tag_system_prompt
        tag.system_prompt.to_s.strip
      end

      def build_proposition_extraction_prompt(text)
        proposition.user_prompt_template % { text: text }
      end

      def build_proposition_system_prompt
        proposition.system_prompt.to_s.strip
      end
    end
  end
end
