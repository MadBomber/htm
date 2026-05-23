# frozen_string_literal: true

require_relative '../errors'
require_relative '../proposition_service'

class HTM
  module Jobs
    # Background job to extract propositions from nodes and create new nodes
    #
    # @see PropositionService
    #
    class GeneratePropositionsJob
      # Generate propositions for a node
      #
      # @param node_id [Integer] ID of the node to process
      # @param robot_id [Integer] ID of the robot that owns this node
      #
      def self.perform(node_id:, robot_id:)
        node = find_node(node_id) or return
        return if node.metadata&.dig('is_proposition')

        begin
          propositions = HTM::PropositionService.extract(node.content)
          return if propositions.empty?

          HTM.logger.info "GeneratePropositionsJob: Extracted #{propositions.length} propositions for node #{node_id}"
          created = create_proposition_nodes(propositions, source_node_id: node_id, robot_id: robot_id)
          HTM.logger.info "GeneratePropositionsJob: Created #{created} proposition nodes from node #{node_id}"
        rescue HTM::CircuitBreakerOpenError
          HTM.logger.warn "GeneratePropositionsJob: Circuit breaker open for node #{node_id}"
        rescue HTM::PropositionError => e
          HTM.logger.error "GeneratePropositionsJob: Proposition extraction failed for node #{node_id}: #{e.message}"
        rescue Sequel::ValidationFailed => e
          HTM.logger.error "GeneratePropositionsJob: Database validation failed for node #{node_id}: #{e.message}"
        rescue StandardError => e
          HTM.logger.error "GeneratePropositionsJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
        end
      end

      class << self
        private

        def find_node(node_id)
          node = HTM::Models::Node.first(id: node_id)
          HTM.logger.warn "GeneratePropositionsJob: Node #{node_id} not found" unless node
          node
        end

        def create_proposition_nodes(propositions, source_node_id:, robot_id:)
          propositions.count do |text|
            token_count = HTM.count_tokens(text)
            prop_node = HTM::Models::Node.create(
              content: text,
              token_count: token_count,
              metadata: { is_proposition: true, source_node_id: source_node_id }
            )
            HTM::Models::RobotNode.find_or_create(robot_id: robot_id, node_id: prop_node.id)
            HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: prop_node.id)
            HTM::JobAdapter.enqueue(HTM::Jobs::GenerateTagsJob, node_id: prop_node.id)
            true
          end
        end
      end
    end
  end
end
