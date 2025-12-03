# frozen_string_literal: true

require_relative '../errors'
require_relative '../models/node'
require_relative '../proposition_service'

class HTM
  module Jobs
    # Background job to extract propositions from nodes and create new nodes
    #
    # This job is enqueued after a node is saved (if proposition extraction is enabled).
    # It uses LLM to extract atomic factual propositions from node content and
    # creates new nodes for each proposition. Proposition nodes are marked with
    # metadata to prevent recursive extraction.
    #
    # @see PropositionService
    #
    class GeneratePropositionsJob
      # Generate propositions for a node
      #
      # Uses the configured proposition extractor (HTM.extract_propositions) which
      # delegates to the application-provided or default RubyLLM implementation.
      #
      # @param node_id [Integer] ID of the node to process
      # @param robot_id [Integer] ID of the robot that owns this node
      #
      def self.perform(node_id:, robot_id:)
        node = HTM::Models::Node.find_by(id: node_id)

        unless node
          HTM.logger.warn "GeneratePropositionsJob: Node #{node_id} not found"
          return
        end

        # Skip if this node is already a proposition (prevent recursion)
        if node.metadata&.dig('is_proposition')
          HTM.logger.debug "GeneratePropositionsJob: Node #{node_id} is a proposition, skipping"
          return
        end

        begin
          HTM.logger.debug "GeneratePropositionsJob: Extracting propositions for node #{node_id}"

          # Extract propositions using PropositionService
          propositions = HTM::PropositionService.extract(node.content)

          if propositions.empty?
            HTM.logger.debug "GeneratePropositionsJob: No propositions extracted for node #{node_id}"
            return
          end

          HTM.logger.info "GeneratePropositionsJob: Extracted #{propositions.length} propositions for node #{node_id}"

          # Create a node for each proposition
          created_count = 0
          propositions.each do |proposition_text|
            # Calculate token count
            token_count = HTM.count_tokens(proposition_text)

            # Create proposition node with is_proposition marker
            proposition_node = HTM::Models::Node.create!(
              content: proposition_text,
              token_count: token_count,
              metadata: { is_proposition: true, source_node_id: node_id }
            )

            # Link to robot via RobotNode
            HTM::Models::RobotNode.find_or_create_by!(
              robot_id: robot_id,
              node_id: proposition_node.id
            )

            # Enqueue embedding and tag jobs for the new proposition node
            # (but NOT another propositions job - the is_proposition marker prevents that)
            HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: proposition_node.id)
            HTM::JobAdapter.enqueue(HTM::Jobs::GenerateTagsJob, node_id: proposition_node.id)

            created_count += 1
          end

          HTM.logger.info "GeneratePropositionsJob: Created #{created_count} proposition nodes from node #{node_id}"

        rescue HTM::CircuitBreakerOpenError
          # Circuit breaker is open - service is unavailable, will retry later
          HTM.logger.warn "GeneratePropositionsJob: Circuit breaker open for node #{node_id}, will retry when service recovers"

        rescue HTM::PropositionError => e
          # Log proposition-specific errors
          HTM.logger.error "GeneratePropositionsJob: Proposition extraction failed for node #{node_id}: #{e.message}"

        rescue ActiveRecord::RecordInvalid => e
          # Log validation errors
          HTM.logger.error "GeneratePropositionsJob: Database validation failed for node #{node_id}: #{e.message}"

        rescue StandardError => e
          # Log unexpected errors
          HTM.logger.error "GeneratePropositionsJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
          HTM.logger.debug e.backtrace.first(5).join("\n")
        end
      end
    end
  end
end
