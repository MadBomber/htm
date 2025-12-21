# frozen_string_literal: true

require_relative '../errors'
require_relative '../models/node'
require_relative '../models/tag'
require_relative '../models/node_tag'
require_relative '../tag_service'

class HTM
  module Jobs
    # Background job to generate and associate tags for nodes
    #
    # This job is enqueued after a node is saved to avoid blocking the
    # main request path. It uses LLM to extract hierarchical tags from
    # node content and creates the necessary database associations.
    #
    # @see ADR-016: Async Embedding and Tag Generation
    # @see ADR-015: Hierarchical Tag Ontology and LLM Extraction
    #
    class GenerateTagsJob
      # Generate tags for a node
      #
      # Uses the configured tag extractor (HTM.extract_tags) which delegates
      # to the application-provided or default RubyLLM implementation.
      #
      # @param node_id [Integer] ID of the node to process
      #
      def self.perform(node_id:)
        node = HTM::Models::Node.find_by(id: node_id)

        unless node
          HTM.logger.warn "GenerateTagsJob: Node #{node_id} not found"
          return
        end

        provider = HTM.configuration.tag_provider.to_s
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          # Get existing ontology for context (sample of recent tags)
          existing_ontology = HTM::Models::Tag
            .order(created_at: :desc)
            .limit(100)
            .pluck(:name)

          # Extract and validate tags using TagService
          tag_names = HTM::TagService.extract(node.content, existing_ontology: existing_ontology)
          return if tag_names.empty?

          # Create or find tags and associate with node
          tag_names.each do |tag_name|
            tag = HTM::Models::Tag.find_or_create_by!(name: tag_name)

            # Create association if it doesn't exist
            HTM::Models::NodeTag.find_or_create_by!(
              node_id: node.id,
              tag_id: tag.id
            )
          end

          # Record success metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.tag_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'success' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'success' })

          HTM.logger.info "GenerateTagsJob: Successfully generated #{tag_names.length} tags for node #{node_id}: #{tag_names.join(', ')}"

        rescue HTM::CircuitBreakerOpenError => e
          # Circuit breaker is open - service is unavailable, will retry later
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'circuit_open' })
          HTM.logger.warn "GenerateTagsJob: Circuit breaker open for node #{node_id}, will retry when service recovers"

        rescue HTM::TagError => e
          # Record failure metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.tag_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'error' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'error' })

          # Log tag-specific errors
          HTM.logger.error "GenerateTagsJob: Tag generation failed for node #{node_id}: #{e.message}"

        rescue ActiveRecord::RecordInvalid => e
          # Record failure metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.tag_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'error' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'error' })

          # Log validation errors
          HTM.logger.error "GenerateTagsJob: Database validation failed for node #{node_id}: #{e.message}"

        rescue StandardError => e
          # Record failure metrics
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HTM::Telemetry.tag_latency.record(elapsed_ms, attributes: { 'provider' => provider, 'status' => 'error' })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'error' })

          # Log unexpected errors
          HTM.logger.error "GenerateTagsJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
        end
      end
    end
  end
end
