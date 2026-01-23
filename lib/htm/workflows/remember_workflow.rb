# frozen_string_literal: true

require 'simple_flow'

class HTM
  module Workflows
    # RememberWorkflow orchestrates the parallel processing of node enrichment
    #
    # Uses simple_flow to manage the dependency graph and parallel execution
    # of embedding generation, tag extraction, and proposition extraction.
    #
    # The workflow structure:
    #   save_node (no deps) -> embedding, tags, propositions (parallel)
    #
    # @example Basic usage with fiber concurrency
    #   workflow = HTM::Workflows::RememberWorkflow.new(htm_instance)
    #   node_id = workflow.call(content: "PostgreSQL is great", tags: ["database"])
    #
    # @example With inline execution (for testing)
    #   workflow = HTM::Workflows::RememberWorkflow.new(htm_instance, concurrency: :threads)
    #   node_id = workflow.call(content: "Test content")
    #
    class RememberWorkflow
      attr_reader :htm, :pipeline

      # Initialize the remember workflow
      #
      # @param htm [HTM] HTM instance for the robot
      # @param concurrency [Symbol] Concurrency model (:auto, :threads, :async)
      #
      def initialize(htm, concurrency: :auto)
        @htm = htm
        @concurrency = concurrency
        @pipeline = build_pipeline
      end

      # Execute the remember workflow
      #
      # @param content [String] Content to remember
      # @param tags [Array<String>] Manual tags to assign
      # @param metadata [Hash] Metadata for the node
      # @return [Integer] Node ID of the created memory
      #
      def call(content:, tags: [], metadata: {})
        initial_data = {
          content: content,
          tags: tags,
          metadata: metadata,
          robot_id: @htm.robot_id,
          htm: @htm
        }

        result = @pipeline.call_parallel(SimpleFlow::Result.new(initial_data))

        if result.continue?
          result.context[:node_id]
        else
          HTM.logger.error "RememberWorkflow failed: #{result.errors.inspect}"
          raise HTM::Error, "Remember workflow failed: #{result.errors.values.flatten.join(', ')}"
        end
      end

      # Get visualization of the workflow as Mermaid diagram
      #
      # @return [String] Mermaid diagram source
      #
      def to_mermaid
        @pipeline.visualize_mermaid
      end

      # Get execution plan
      #
      # @return [String] Execution plan description
      #
      def execution_plan
        @pipeline.execution_plan
      end

      private

      def build_pipeline
        SimpleFlow::Pipeline.new(concurrency: @concurrency) do
          # Step 1: Save node to database (no dependencies)
          step :save_node, ->(result) {
            data = result.value
            htm = data[:htm]

            # Calculate token count
            token_count = HTM.count_tokens(data[:content])

            # Store in long-term memory
            save_result = htm.long_term_memory.add(
              content: data[:content],
              token_count: token_count,
              robot_id: data[:robot_id],
              embedding: nil,
              metadata: data[:metadata]
            )

            node_id = save_result[:node_id]
            is_new = save_result[:is_new]

            HTM.logger.info "RememberWorkflow: Node #{node_id} saved (new: #{is_new})"

            result
              .with_context(:node_id, node_id)
              .with_context(:is_new, is_new)
              .with_context(:token_count, token_count)
              .with_context(:robot_node, save_result[:robot_node])
              .continue(data)
          }, depends_on: :none

          # Step 2: Generate embedding (depends on save_node, runs in parallel with tags/propositions)
          step :generate_embedding, ->(result) {
            node_id = result.context[:node_id]
            is_new = result.context[:is_new]

            # Only generate for new nodes
            if is_new
              begin
                HTM::Jobs::GenerateEmbeddingJob.perform(node_id: node_id)
              rescue StandardError => e
                HTM.logger.error "RememberWorkflow: Embedding generation failed: #{e.message}"
                # Continue despite error - embedding is non-critical
              end
            end

            result.continue(result.value)
          }, depends_on: [:save_node]

          # Step 3: Generate tags (depends on save_node, runs in parallel with embedding/propositions)
          step :generate_tags, ->(result) {
            node_id = result.context[:node_id]
            is_new = result.context[:is_new]
            manual_tags = result.value[:tags] || []

            if is_new
              # Add manual tags immediately (including parent tags)
              if manual_tags.any?
                manual_tags.each do |tag_name|
                  HTM::Models::Tag.find_or_create_with_ancestors(tag_name).each do |tag|
                    HTM::Models::NodeTag.find_or_create(node_id: node_id, tag_id: tag.id)
                  end
                end
              end

              begin
                HTM::Jobs::GenerateTagsJob.perform(node_id: node_id)
              rescue StandardError => e
                HTM.logger.error "RememberWorkflow: Tag generation failed: #{e.message}"
                # Continue despite error - tags are non-critical
              end
            else
              # For existing nodes, only add manual tags
              if manual_tags.any?
                node = HTM::Models::Node[node_id]
                node.add_tags(manual_tags)
              end
            end

            result.continue(result.value)
          }, depends_on: [:save_node]

          # Step 4: Generate propositions (depends on save_node, runs in parallel with embedding/tags)
          step :generate_propositions, ->(result) {
            node_id = result.context[:node_id]
            is_new = result.context[:is_new]
            metadata = result.value[:metadata] || {}
            robot_id = result.value[:robot_id]

            # Only extract propositions for new nodes that aren't already propositions
            if is_new && HTM.config.extract_propositions && !metadata[:is_proposition]
              begin
                HTM::Jobs::GeneratePropositionsJob.perform(node_id: node_id, robot_id: robot_id)
              rescue StandardError => e
                HTM.logger.error "RememberWorkflow: Proposition extraction failed: #{e.message}"
                # Continue despite error - propositions are non-critical
              end
            end

            result.continue(result.value)
          }, depends_on: [:save_node]

          # Step 5: Finalize (depends on all enrichment steps)
          step :finalize, ->(result) {
            node_id = result.context[:node_id]
            token_count = result.context[:token_count]
            robot_node = result.context[:robot_node]
            htm = result.value[:htm]

            # Add to working memory
            unless htm.working_memory.has_space?(token_count)
              evicted = htm.working_memory.evict_to_make_space(token_count)
              evicted_keys = evicted.map { |n| n[:key] }
              htm.long_term_memory.mark_evicted(robot_id: result.value[:robot_id], node_ids: evicted_keys) if evicted_keys.any?
            end
            htm.working_memory.add(node_id, result.value[:content], token_count: token_count, access_count: 0)

            # Mark as in working memory
            robot_node.update(working_memory: true)

            # Update robot activity
            htm.long_term_memory.update_robot_activity(result.value[:robot_id])

            HTM.logger.info "RememberWorkflow: Node #{node_id} finalized"

            result.continue(result.value)
          }, depends_on: [:generate_embedding, :generate_tags, :generate_propositions]
        end
      end
    end
  end
end
