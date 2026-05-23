# frozen_string_literal: true

require_relative '../errors'
require_relative '../tag_service'

class HTM
  module Jobs
    # Background job to generate and associate tags for nodes
    #
    # @see ADR-016: Async Embedding and Tag Generation
    # @see ADR-015: Hierarchical Tag Ontology and LLM Extraction
    #
    class GenerateTagsJob
      # Generate tags for a node
      #
      # @param node_id [Integer] ID of the node to process
      #
      def self.perform(node_id:)
        node = find_node(node_id) or return

        provider   = HTM.configuration.tag_provider.to_s
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          tag_names = extract_tags_for(node)
          return if tag_names.empty?

          associate_tags(node, tag_names)
          record_telemetry(provider, start_time, 'success')
          HTM.logger.info "GenerateTagsJob: Generated #{tag_names.length} tags for node #{node_id}: #{tag_names.join(', ')}"

          HTM::JobAdapter.enqueue(HTM::Jobs::GenerateRelationshipsJob, node_id: node_id)
        rescue HTM::CircuitBreakerOpenError
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => 'circuit_open' })
          HTM.logger.warn "GenerateTagsJob: Circuit breaker open for node #{node_id}"
        rescue HTM::TagError, Sequel::ValidationFailed => e
          record_telemetry(provider, start_time, 'error')
          HTM.logger.error "GenerateTagsJob: Failed for node #{node_id}: #{e.message}"
        rescue StandardError => e
          record_telemetry(provider, start_time, 'error')
          HTM.logger.error "GenerateTagsJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
        end
      end

      class << self
        private

        def find_node(node_id)
          node = HTM::Models::Node.first(id: node_id)
          HTM.logger.warn "GenerateTagsJob: Node #{node_id} not found" unless node
          node
        end

        def extract_tags_for(node)
          existing_ontology = HTM::Models::Tag
                              .order(Sequel.desc(:created_at))
                              .limit(100)
                              .select_map(:name)
          HTM::TagService.extract(node.content, existing_ontology: existing_ontology)
        end

        def associate_tags(node, tag_names)
          tag_names.each do |tag_name|
            HTM::Models::Tag.find_or_create_with_ancestors(tag_name).each do |tag|
              HTM::Models::NodeTag.find_or_create(node_id: node.id, tag_id: tag.id)
            end
          end
        end

        def elapsed_ms(start_time)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        end

        def record_telemetry(provider, start_time, status)
          ms = elapsed_ms(start_time)
          HTM::Telemetry.tag_latency.record(ms, attributes: { 'provider' => provider, 'status' => status })
          HTM::Telemetry.job_counter.add(1, attributes: { 'job' => 'tags', 'status' => status })
        end
      end
    end
  end
end
