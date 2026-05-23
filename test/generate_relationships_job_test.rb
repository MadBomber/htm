# frozen_string_literal: true

require_relative 'test_helper'

class GenerateRelationshipsJobTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks
    cleanup_test_data
  end

  def teardown
    return unless database_available?
    cleanup_test_data
  end

  # --- Guard clauses ---

  def test_skips_when_node_not_found
    # Should not raise, just log a warning
    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: 0)
  end

  def test_skips_when_node_has_no_tags
    node = create_node("Tagless [NR_JOB_TEST]")

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node.id)

    assert_equal 0, HTM::Models::NodeRelationship.where(source_id: node.id).count
  end

  def test_skips_when_no_other_nodes_share_a_tag
    tag   = create_tag('lonely:concept')
    node  = create_node_with_tags("Lonely node [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node.id)

    assert_equal 0, HTM::Models::NodeRelationship.where(source_id: node.id).count
  end

  # --- Edge creation ---

  def test_creates_edges_between_nodes_sharing_a_tag
    tag    = create_tag('shared:concept')
    node_a = create_node_with_tags("Node A [NR_JOB_TEST]", [tag])
    node_b = create_node_with_tags("Node B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    assert_equal 1, HTM::Models::NodeRelationship.where(source_id: node_a.id, target_id: node_b.id).count
  end

  def test_stores_both_directions
    tag    = create_tag('bidirectional:check')
    node_a = create_node_with_tags("Bidir A [NR_JOB_TEST]", [tag])
    node_b = create_node_with_tags("Bidir B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    a_to_b = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    b_to_a = HTM::Models::NodeRelationship.first(source_id: node_b.id, target_id: node_a.id)

    refute_nil a_to_b, "Expected A→B edge"
    refute_nil b_to_a, "Expected B→A edge"
  end

  def test_both_directions_have_the_same_weight
    tag1   = create_tag('sym:weight-a')
    tag2   = create_tag('sym:weight-b')
    node_a = create_node_with_tags("Sym A [NR_JOB_TEST]", [tag1, tag2])
    node_b = create_node_with_tags("Sym B [NR_JOB_TEST]", [tag1])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    a_to_b = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    b_to_a = HTM::Models::NodeRelationship.first(source_id: node_b.id, target_id: node_a.id)

    assert_in_delta a_to_b.weight, b_to_a.weight, 0.0001
  end

  def test_creates_edges_to_all_qualifying_neighbors
    tag     = create_tag('hub:all-neighbors')
    node_a  = create_node_with_tags("Hub [NR_JOB_TEST]", [tag])
    create_node_with_tags("Spoke 1 [NR_JOB_TEST]", [tag])
    create_node_with_tags("Spoke 2 [NR_JOB_TEST]", [tag])
    create_node_with_tags("Spoke 3 [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    assert_equal 3, HTM::Models::NodeRelationship.where(source_id: node_a.id).count
  end

  def test_does_not_create_self_edge
    tag    = create_tag('self:loop-check')
    node_a = create_node_with_tags("Self [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    assert_nil HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_a.id)
  end

  # --- Jaccard similarity ---

  def test_jaccard_weight_with_full_overlap
    # Both nodes have identical tags → Jaccard = 1.0
    tag1   = create_tag('jaccard:full-a')
    tag2   = create_tag('jaccard:full-b')
    node_a = create_node_with_tags("Full A [NR_JOB_TEST]", [tag1, tag2])
    node_b = create_node_with_tags("Full B [NR_JOB_TEST]", [tag1, tag2])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    assert_in_delta 1.0, rel.weight, 0.001
  end

  def test_jaccard_weight_with_partial_overlap
    # node_a: 3 tags, node_b: 2 of those 3
    # Jaccard = 2 / (3 + 2 - 2) = 2/3 ≈ 0.667
    tag1   = create_tag('jaccard:partial-1')
    tag2   = create_tag('jaccard:partial-2')
    tag3   = create_tag('jaccard:partial-3')
    node_a = create_node_with_tags("Partial A [NR_JOB_TEST]", [tag1, tag2, tag3])
    node_b = create_node_with_tags("Partial B [NR_JOB_TEST]", [tag1, tag2])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    assert_in_delta(2.0 / 3.0, rel.weight, 0.001)
  end

  def test_jaccard_weight_with_single_shared_tag
    # node_a: 1 tag, node_b: 1 same tag → Jaccard = 1/1 = 1.0
    tag    = create_tag('jaccard:single-shared')
    node_a = create_node_with_tags("Single A [NR_JOB_TEST]", [tag])
    node_b = create_node_with_tags("Single B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    assert_in_delta 1.0, rel.weight, 0.001
  end

  # --- Minimum weight threshold ---

  def test_skips_edges_below_minimum_weight_threshold
    # node_a: 12 tags, node_b shares 1 → Jaccard = 1/(12+1-1) = 1/12 ≈ 0.083 < 0.1
    tags   = (1..12).map { |i| create_tag("threshold:below-#{i}") }
    node_a = create_node_with_tags("Wide A [NR_JOB_TEST]", tags)
    node_b = create_node_with_tags("Narrow B [NR_JOB_TEST]", [tags.first])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    assert_equal 0, HTM::Models::NodeRelationship.where(source_id: node_a.id, target_id: node_b.id).count
  end

  def test_includes_edges_at_or_above_minimum_weight_threshold
    # node_a: 3 tags, node_b: 2 of those → Jaccard = 2/3 ≈ 0.667 > 0.1
    tags   = (1..3).map { |i| create_tag("threshold:above-#{i}") }
    node_a = create_node_with_tags("Above A [NR_JOB_TEST]", tags)
    node_b = create_node_with_tags("Above B [NR_JOB_TEST]", tags[0..1])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    refute_nil rel
    assert_operator rel.weight, :>, HTM::Jobs::MIN_WEIGHT_THRESHOLD
  end

  # --- Idempotency ---

  def test_running_twice_does_not_duplicate_edges
    tag    = create_tag('idem:no-dup')
    node_a = create_node_with_tags("Idem A [NR_JOB_TEST]", [tag])
    node_b = create_node_with_tags("Idem B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)
    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    assert_equal 1, HTM::Models::NodeRelationship.where(source_id: node_a.id, target_id: node_b.id).count
  end

  def test_reruns_update_stale_weights
    tag1   = create_tag('stale:weight-1')
    tag2   = create_tag('stale:weight-2')
    node_a = create_node_with_tags("Stale A [NR_JOB_TEST]", [tag1])
    node_b = create_node_with_tags("Stale B [NR_JOB_TEST]", [tag1])

    # First run: A and B share 1/1 tag each → Jaccard = 1.0
    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)
    rel_before = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    assert_in_delta 1.0, rel_before.weight, 0.001

    # Add a second tag to node_a only → Jaccard = 1/(2+1-1) = 0.5
    HTM::Models::NodeTag.create(node_id: node_a.id, tag_id: tag2.id)

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)
    rel_after = HTM::Models::NodeRelationship.first(source_id: node_a.id, target_id: node_b.id)
    assert_in_delta 0.5, rel_after.weight, 0.001
  end

  def test_updated_at_is_refreshed_on_rerun
    tag    = create_tag('idem:timestamps')
    node_a = create_node_with_tags("Ts A [NR_JOB_TEST]", [tag])
    _node_b = create_node_with_tags("Ts B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)
    first_updated = HTM::Models::NodeRelationship
                    .where(source_id: node_a.id).first.updated_at

    sleep(0.05)
    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)
    second_updated = HTM::Models::NodeRelationship
                     .where(source_id: node_a.id).first.updated_at

    assert_operator second_updated, :>=, first_updated
  end

  # --- Edge metadata ---

  def test_edges_have_tag_cooccurrence_origin
    tag    = create_tag('meta:origin-check')
    node_a = create_node_with_tags("Meta A [NR_JOB_TEST]", [tag])
    _node_b = create_node_with_tags("Meta B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id)
    assert_equal 'tag_cooccurrence', rel.origin
  end

  def test_edges_have_related_to_rel_type
    tag    = create_tag('meta:reltype-check')
    node_a = create_node_with_tags("RelType A [NR_JOB_TEST]", [tag])
    _node_b = create_node_with_tags("RelType B [NR_JOB_TEST]", [tag])

    HTM::Jobs::GenerateRelationshipsJob.perform(node_id: node_a.id)

    rel = HTM::Models::NodeRelationship.first(source_id: node_a.id)
    assert_equal 'related_to', rel.rel_type
  end

  # --- Constants ---

  def test_min_weight_threshold_constant
    assert_equal 0.1, HTM::Jobs::MIN_WEIGHT_THRESHOLD
  end

  def test_max_edges_per_node_constant
    assert_equal 50, HTM::Jobs::MAX_EDGES_PER_NODE
  end

  private

  def create_node(content)
    HTM::Models::Node.create(
      content: content,
      content_hash: Digest::SHA256.hexdigest(content)
    )
  end

  def create_tag(name)
    HTM::Models::Tag.find_or_create(name: name)
  end

  def create_node_with_tags(content, tags)
    node = create_node(content)
    tags.each { |tag| HTM::Models::NodeTag.create(node_id: node.id, tag_id: tag.id) }
    node
  end

  def cleanup_test_data
    return unless database_available?

    # Deleting nodes cascades to node_relationships and node_tags via FK ON DELETE CASCADE
    HTM::Models::Node.dataset.unfiltered
                     .where(Sequel.like(:content, '%[NR_JOB_TEST]%'))
                     .delete
  end
end
