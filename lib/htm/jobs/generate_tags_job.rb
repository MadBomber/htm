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
          warn "GenerateTagsJob: Node #{node_id} not found"
          return
        end

        begin
          # Get existing ontology for context (sample of recent tags)
          existing_ontology = HTM::Models::Tag
            .order(created_at: :desc)
            .limit(100)
            .pluck(:name)

          # Extract tags using configured extractor
          tag_names = HTM.extract_tags(node.content, existing_ontology: existing_ontology)

          if tag_names.empty?
            debug_me "GenerateTagsJob: No tags extracted for node #{node_id}"
            return
          end

          # Create or find tags and associate with node
          tag_names.each do |tag_name|
            tag = HTM::Models::Tag.find_or_create_by!(name: tag_name)

            # Create association if it doesn't exist
            HTM::Models::NodeTag.find_or_create_by!(
              node_id: node.id,
              tag_id: tag.id
            )
          end

          debug_me "GenerateTagsJob: Successfully generated #{tag_names.length} tags for node #{node_id}: #{tag_names.join(', ')}"

        rescue HTM::TagError => e
          # Log tag-specific errors
          warn "GenerateTagsJob: Tag generation failed for node #{node_id}: #{e.message}"

        rescue ActiveRecord::RecordInvalid => e
          # Log validation errors
          warn "GenerateTagsJob: Database validation failed for node #{node_id}: #{e.message}"

        rescue StandardError => e
          # Log unexpected errors
          warn "GenerateTagsJob: Unexpected error for node #{node_id}: #{e.class.name} - #{e.message}"
          warn e.backtrace.first(5).join("\n")
        end
      end
    end
  end
end
