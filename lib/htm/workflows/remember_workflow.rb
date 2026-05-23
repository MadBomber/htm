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
        save_step  = save_node_step
        embed_step = generate_embedding_step
        tags_step  = generate_tags_step
        props_step = generate_propositions_step
        final_step = finalize_step

        SimpleFlow::Pipeline.new(concurrency: @concurrency) do
          step :save_node,             save_step,  depends_on: :none
          step :generate_embedding,    embed_step, depends_on: [:save_node]
          step :generate_tags,         tags_step,  depends_on: [:save_node]
          step :generate_propositions, props_step, depends_on: [:save_node]
          step :finalize,              final_step, depends_on: %i[generate_embedding generate_tags generate_propositions]
        end
      end

      def save_node_step
        lambda { |result|
          data = result.value
          htm = data[:htm]
          token_count = HTM.count_tokens(data[:content])
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
        }
      end

      def generate_embedding_step
        lambda { |result|
          node_id = result.context[:node_id]
          if result.context[:is_new]
            begin
              HTM::Jobs::GenerateEmbeddingJob.perform(node_id: node_id)
            rescue StandardError => e
              HTM.logger.error "RememberWorkflow: Embedding generation failed: #{e.message}"
            end
          end
          result.continue(result.value)
        }
      end

      def generate_tags_step
        lambda { |result|
          node_id    = result.context[:node_id]
          is_new     = result.context[:is_new]
          manual_tags = result.value[:tags] || []

          if is_new
            manual_tags.each do |tag_name|
              HTM::Models::Tag.find_or_create_with_ancestors(tag_name).each do |tag|
                HTM::Models::NodeTag.find_or_create(node_id: node_id, tag_id: tag.id)
              end
            end
            begin
              HTM::Jobs::GenerateTagsJob.perform(node_id: node_id)
            rescue StandardError => e
              HTM.logger.error "RememberWorkflow: Tag generation failed: #{e.message}"
            end
          elsif manual_tags.any?
            HTM::Models::Node[node_id].add_tags(manual_tags)
          end

          result.continue(result.value)
        }
      end

      def generate_propositions_step
        lambda { |result|
          node_id  = result.context[:node_id]
          is_new   = result.context[:is_new]
          metadata = result.value[:metadata] || {}
          robot_id = result.value[:robot_id]

          if is_new && HTM.config.extract_propositions && !metadata[:is_proposition]
            begin
              HTM::Jobs::GeneratePropositionsJob.perform(node_id: node_id, robot_id: robot_id)
            rescue StandardError => e
              HTM.logger.error "RememberWorkflow: Proposition extraction failed: #{e.message}"
            end
          end

          result.continue(result.value)
        }
      end

      def finalize_step
        lambda { |result|
          ctx = result.context
          finalize_node(
            htm:         result.value[:htm],
            node_id:     ctx[:node_id],
            token_count: ctx[:token_count],
            robot_node:  ctx[:robot_node],
            content:     result.value[:content],
            robot_id:    result.value[:robot_id]
          )
          result.continue(result.value)
        }
      end

      def finalize_node(htm:, node_id:, token_count:, robot_node:, content:, robot_id:)
        evict_working_memory_if_needed(htm, token_count, robot_id)
        htm.working_memory.add(node_id, content, token_count: token_count, access_count: 0)
        robot_node.update(working_memory: true)
        htm.long_term_memory.update_robot_activity(robot_id)
        HTM.logger.info "RememberWorkflow: Node #{node_id} finalized"
      end

      def evict_working_memory_if_needed(htm, token_count, robot_id)
        return if htm.working_memory.has_space?(token_count)
        evicted      = htm.working_memory.evict_to_make_space(token_count)
        evicted_keys = evicted.map { |n| n[:key] }
        htm.long_term_memory.mark_evicted(robot_id: robot_id, node_ids: evicted_keys) if evicted_keys.any?
      end
    end
  end
end
