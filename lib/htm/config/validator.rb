# frozen_string_literal: true

class HTM
  class Config
    module Validator
      SUPPORTED_PROVIDERS = %i[
        openai anthropic gemini azure ollama
        huggingface openrouter bedrock deepseek
      ].freeze

      SUPPORTED_JOB_BACKENDS = %i[active_job sidekiq inline thread fiber].freeze
      SUPPORTED_WEEK_STARTS = %i[sunday monday].freeze

      def validate_config
        validate_providers
        validate_job_backend
        validate_week_start
        validate_relevance_weights
      end

      def validate_providers
        validate_provider(:embedding_provider, embedding_provider)
        validate_provider(:tag_provider, tag_provider)
        validate_provider(:proposition_provider, proposition_provider)
      end

      def validate_provider(name, value)
        return if value.nil?

        unless SUPPORTED_PROVIDERS.include?(value)
          raise_validation_error("#{name} must be one of: #{SUPPORTED_PROVIDERS.join(', ')} (got #{value.inspect})")
        end
      end

      def validate_job_backend
        return unless job_backend

        unless SUPPORTED_JOB_BACKENDS.include?(job_backend)
          raise_validation_error("job.backend must be one of: #{SUPPORTED_JOB_BACKENDS.join(', ')} (got #{job_backend.inspect})")
        end
      end

      def validate_week_start
        unless SUPPORTED_WEEK_STARTS.include?(week_start)
          raise_validation_error("week_start must be one of: #{SUPPORTED_WEEK_STARTS.join(', ')} (got #{week_start.inspect})")
        end
      end

      def validate_relevance_weights
        total = relevance_semantic_weight + relevance_tag_weight +
                relevance_recency_weight + relevance_access_weight

        unless (0.99..1.01).cover?(total)
          raise_validation_error("relevance weights must sum to 1.0 (got #{total})")
        end
      end

      def validate_callables
        unless @embedding_generator.respond_to?(:call)
          raise HTM::ValidationError, "embedding_generator must be callable"
        end

        unless @tag_extractor.respond_to?(:call)
          raise HTM::ValidationError, "tag_extractor must be callable"
        end

        unless @proposition_extractor.respond_to?(:call)
          raise HTM::ValidationError, "proposition_extractor must be callable"
        end

        unless @token_counter.respond_to?(:call)
          raise HTM::ValidationError, "token_counter must be callable"
        end
      end

      def validate_logger
        unless @logger.respond_to?(:info) && @logger.respond_to?(:warn) && @logger.respond_to?(:error)
          raise HTM::ValidationError, "logger must respond to :info, :warn, and :error"
        end
      end
    end
  end
end
