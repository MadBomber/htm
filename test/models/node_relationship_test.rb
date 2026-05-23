# frozen_string_literal: true

require_relative '../test_helper'

class NodeRelationshipTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks
    cleanup_test_data

    @node_a = create_test_node("Node A [NR_MODEL_TEST]")
    @node_b = create_test_node("Node B [NR_MODEL_TEST]")
    @node_c = create_test_node("Node C [NR_MODEL_TEST]")
  end

  def teardown
    return unless database_available?
    cleanup_test_data
  end

  # --- Constants ---

  def test_rel_types_constant
    assert_equal %w[related_to supports contradicts derived_from], HTM::Models::NodeRelationship::REL_TYPES
  end

  def test_origins_constant
    assert_equal %w[tag_cooccurrence tag_hierarchy explicit], HTM::Models::NodeRelationship::ORIGINS
  end

  # --- Validations: presence ---

  def test_valid_relationship
    rel = build_relationship
    assert rel.valid?, rel.errors.full_messages.join(', ')
  end

  def test_requires_source_id
    rel = build_relationship(source_id: nil)
    refute rel.valid?
    assert_includes rel.errors[:source_id], 'is not present'
  end

  def test_requires_target_id
    rel = build_relationship(target_id: nil)
    refute rel.valid?
    assert_includes rel.errors[:target_id], 'is not present'
  end

  def test_requires_rel_type
    rel = build_relationship(rel_type: nil)
    refute rel.valid?
    assert_includes rel.errors[:rel_type], 'is not present'
  end

  def test_requires_origin
    rel = build_relationship(origin: nil)
    refute rel.valid?
    assert_includes rel.errors[:origin], 'is not present'
  end

  def test_requires_weight
    rel = build_relationship(weight: nil)
    refute rel.valid?
    assert_includes rel.errors[:weight], 'is not present'
  end

  # --- Validations: allowed values ---

  def test_rejects_invalid_rel_type
    rel = build_relationship(rel_type: 'invented_type')
    refute rel.valid?
    assert rel.errors[:rel_type].any?
  end

  def test_rejects_invalid_origin
    rel = build_relationship(origin: 'magic')
    refute rel.valid?
    assert rel.errors[:origin].any?
  end

  def test_all_valid_rel_types_accepted
    HTM::Models::NodeRelationship::REL_TYPES.each do |rel_type|
      # alternate target to avoid uniqueness conflict
      target = rel_type == 'related_to' ? @node_b : @node_c
      rel = build_relationship(target_id: target.id, rel_type: rel_type)
      assert rel.valid?, "Expected #{rel_type} to be valid: #{rel.errors.full_messages.join(', ')}"
    end
  end

  def test_all_valid_origins_accepted
    HTM::Models::NodeRelationship::ORIGINS.each_with_index do |origin, i|
      target = i.even? ? @node_b : @node_c
      rel = build_relationship(target_id: target.id, origin: origin)
      assert rel.valid?, "Expected #{origin} to be valid: #{rel.errors.full_messages.join(', ')}"
    end
  end

  # --- Validations: weight range ---

  def test_rejects_weight_below_zero
    rel = build_relationship(weight: -0.001)
    refute rel.valid?
    assert_includes rel.errors[:weight], 'must be between 0.0 and 1.0'
  end

  def test_rejects_weight_above_one
    rel = build_relationship(weight: 1.001)
    refute rel.valid?
    assert_includes rel.errors[:weight], 'must be between 0.0 and 1.0'
  end

  def test_accepts_weight_at_zero
    rel = build_relationship(weight: 0.0)
    assert rel.valid?, rel.errors.full_messages.join(', ')
  end

  def test_accepts_weight_at_one
    rel = build_relationship(weight: 1.0)
    assert rel.valid?, rel.errors.full_messages.join(', ')
  end

  # --- Validations: self-loop and uniqueness ---

  def test_rejects_self_loop
    rel = build_relationship(source_id: @node_a.id, target_id: @node_a.id)
    refute rel.valid?
    assert_includes rel.errors[:source_id], 'cannot relate a node to itself'
  end

  def test_rejects_duplicate_source_target_rel_type
    HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    dup = build_relationship(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to')
    refute dup.valid?
    # Sequel keys multi-column uniqueness errors on the column array, not the first column alone
    assert dup.errors[%i[source_id target_id rel_type]].any?
  end

  def test_allows_different_rel_type_between_same_nodes
    HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    rel = build_relationship(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'supports')
    assert rel.valid?, rel.errors.full_messages.join(', ')
  end

  # --- Persistence ---

  def test_create_persists_to_database
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.8
    )

    assert_predicate rel.id, :positive?
    found = HTM::Models::NodeRelationship[rel.id]
    assert_equal @node_a.id, found.source_id
    assert_equal @node_b.id, found.target_id
    assert_in_delta 0.8, found.weight, 0.0001
    assert_equal 'related_to', found.rel_type
    assert_equal 'explicit', found.origin
  end

  def test_before_create_sets_timestamps
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    assert_instance_of Time, rel.created_at
    assert_instance_of Time, rel.updated_at
  end

  def test_before_save_updates_updated_at
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    original_updated_at = rel.updated_at
    sleep(0.01)
    rel.update(weight: 0.9)

    assert_operator rel.updated_at, :>, original_updated_at
  end

  # --- Associations ---

  def test_source_node_returns_correct_node
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    assert_equal @node_a.id, rel.source_node.id
  end

  def test_target_node_returns_correct_node
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )

    assert_equal @node_b.id, rel.target_node.id
  end

  # --- Dataset scopes ---

  def test_by_origin_filters_by_origin
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to', origin: 'tag_cooccurrence', weight: 0.5)
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_c.id, rel_type: 'related_to', origin: 'explicit', weight: 0.5)

    tag_rels = HTM::Models::NodeRelationship.by_origin('tag_cooccurrence').where(source_id: @node_a.id).all
    explicit  = HTM::Models::NodeRelationship.by_origin('explicit').where(source_id: @node_a.id).all

    assert_equal 1, tag_rels.length
    assert_equal @node_b.id, tag_rels.first.target_id
    assert_equal 1, explicit.length
    assert_equal @node_c.id, explicit.first.target_id
  end

  def test_by_rel_type_filters_by_type
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to', origin: 'explicit', weight: 0.5)
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_c.id, rel_type: 'supports',   origin: 'explicit', weight: 0.5)

    related  = HTM::Models::NodeRelationship.by_rel_type('related_to').where(source_id: @node_a.id).all
    supports = HTM::Models::NodeRelationship.by_rel_type('supports').where(source_id: @node_a.id).all

    assert_equal 1, related.length
    assert_equal 1, supports.length
  end

  def test_above_weight_excludes_low_weight_edges
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to', origin: 'explicit', weight: 0.3)
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_c.id, rel_type: 'supports',   origin: 'explicit', weight: 0.8)

    high = HTM::Models::NodeRelationship.above_weight(0.5).where(source_id: @node_a.id).all

    assert_equal 1, high.length
    assert_in_delta 0.8, high.first.weight, 0.0001
  end

  def test_neighbors_of_returns_ordered_by_weight_desc
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to', origin: 'explicit', weight: 0.3)
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_c.id, rel_type: 'related_to', origin: 'explicit', weight: 0.8)

    neighbors = HTM::Models::NodeRelationship.neighbors_of(@node_a.id).all

    assert_equal 2, neighbors.length
    assert_operator neighbors.first.weight, :>=, neighbors.last.weight
    assert_equal @node_c.id, neighbors.first.target_id
  end

  def test_between_nodes_finds_specific_edge
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_b.id, rel_type: 'related_to', origin: 'explicit', weight: 0.5)
    HTM::Models::NodeRelationship.create(source_id: @node_a.id, target_id: @node_c.id, rel_type: 'related_to', origin: 'explicit', weight: 0.5)

    result = HTM::Models::NodeRelationship.between_nodes(@node_a.id, @node_b.id).all

    assert_equal 1, result.length
    assert_equal @node_b.id, result.first.target_id
  end

  # --- Cascade delete ---

  def test_deleting_source_node_removes_its_edges
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )
    rel_id = rel.id

    HTM::Models::Node.dataset.unfiltered.where(id: @node_a.id).delete
    @node_a = nil

    assert_nil HTM::Models::NodeRelationship[rel_id]
  end

  def test_deleting_target_node_removes_its_edges
    rel = HTM::Models::NodeRelationship.create(
      source_id: @node_a.id, target_id: @node_b.id,
      rel_type: 'related_to', origin: 'explicit', weight: 0.5
    )
    rel_id = rel.id

    HTM::Models::Node.dataset.unfiltered.where(id: @node_b.id).delete
    @node_b = nil

    assert_nil HTM::Models::NodeRelationship[rel_id]
  end

  private

  def create_test_node(content)
    HTM::Models::Node.create(
      content: content,
      content_hash: Digest::SHA256.hexdigest(content)
    )
  end

  def build_relationship(overrides = {})
    HTM::Models::NodeRelationship.new({
      source_id: @node_a.id,
      target_id: @node_b.id,
      rel_type:  'related_to',
      origin:    'tag_cooccurrence',
      weight:    0.5
    }.merge(overrides))
  end

  def cleanup_test_data
    return unless database_available?

    # Deleting nodes cascades to node_relationships and node_tags via FK ON DELETE CASCADE
    HTM::Models::Node.dataset.unfiltered
                     .where(Sequel.like(:content, '%[NR_MODEL_TEST]%'))
                     .delete
  end
end
