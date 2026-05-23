# frozen_string_literal: true

class HTM
  module Models
    # NodeRelationship model - weighted directed edge between two nodes
    #
    # Edges are stored in both directions so the CTE traversal only needs
    # WHERE source_id IN (seeds) rather than an OR across both columns.
    #
    # Weights are Jaccard similarity scores for tag_cooccurrence edges:
    #   weight = |tags(A) ∩ tags(B)| / |tags(A) ∪ tags(B)|
    #
    class NodeRelationship < Sequel::Model(:node_relationships)
      REL_TYPES = %w[related_to supports contradicts derived_from].freeze
      ORIGINS   = %w[tag_cooccurrence tag_hierarchy explicit].freeze

      # Associations
      many_to_one :source_node, class: 'HTM::Models::Node', key: :source_id
      many_to_one :target_node, class: 'HTM::Models::Node', key: :target_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence %i[source_id target_id rel_type origin weight]
        validates_includes REL_TYPES, :rel_type, allow_missing: true
        validates_includes ORIGINS,   :origin,   allow_missing: true
        validates_unique %i[source_id target_id rel_type], message: 'relationship already exists'
        errors.add(:source_id, 'cannot relate a node to itself') if source_id && source_id == target_id
        errors.add(:weight, 'must be between 0.0 and 1.0') if weight && !weight.between?(0.0, 1.0)
      end

      # Dataset methods (scopes)
      dataset_module do
        def by_origin(origin)
          where(origin: origin.to_s)
        end

        def by_rel_type(rel_type)
          where(rel_type: rel_type.to_s)
        end

        def above_weight(min_weight)
          where { weight >= min_weight }
        end

        def neighbors_of(node_id)
          where(source_id: node_id).order(Sequel.desc(:weight))
        end

        def between_nodes(source_id, target_id)
          where(source_id: source_id, target_id: target_id)
        end
      end

      # Hooks
      def before_create
        self.created_at ||= Time.now
        self.updated_at ||= Time.now
        super
      end

      def before_save
        self.updated_at = Time.now if changed_columns.any?
        super
      end
    end
  end
end
