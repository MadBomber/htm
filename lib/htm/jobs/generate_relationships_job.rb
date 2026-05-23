# frozen_string_literal: true

class HTM
  module Jobs
    # Background job to compute and upsert weighted edges between nodes.
    #
    # Runs after GenerateTagsJob so the node's tags are already present.
    # For each node, finds all other nodes sharing at least one tag and
    # computes Jaccard similarity as the edge weight:
    #
    #   weight = |tags(A) ∩ tags(B)| / |tags(A) ∪ tags(B)|
    #
    # Both directions are stored (A→B and B→A) so the CTE traversal only
    # needs WHERE source_id IN (seeds) with a plain btree index hit.
    #
    # Edges with weight below MIN_WEIGHT_THRESHOLD are skipped.
    # At most MAX_EDGES_PER_NODE edges are created (highest-weight first).
    #
    MIN_WEIGHT_THRESHOLD = 0.1
    MAX_EDGES_PER_NODE   = 50

    class GenerateRelationshipsJob
      # Compute and persist relationship edges for a node.
      #
      # @param node_id [Integer] ID of the node to process
      #
      def self.perform(node_id:)
        find_node(node_id) or return

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          candidates = compute_candidates(node_id)

          if candidates.empty?
            HTM.logger.info "GenerateRelationshipsJob: No tag-sharing neighbors for node #{node_id}"
            return
          end

          count = upsert_edges(node_id, candidates)
          elapsed = elapsed_ms(start_time)
          HTM.logger.info "GenerateRelationshipsJob: Upserted #{count} edges for node #{node_id} (#{elapsed}ms)"
        rescue StandardError => e
          HTM.logger.error "GenerateRelationshipsJob: Failed for node #{node_id}: #{e.class.name} - #{e.message}"
        end
      end

      class << self
        private

        def find_node(node_id)
          node = HTM::Models::Node.first(id: node_id)
          HTM.logger.warn "GenerateRelationshipsJob: Node #{node_id} not found" unless node
          node
        end

        # Return candidate neighbor rows [{target_id:, weight:}] sorted by weight desc.
        # Uses a single SQL query to compute Jaccard similarity for all tag-sharing nodes.
        #
        def compute_candidates(node_id)
          HTM.db.fetch(<<~SQL, node_id, node_id, MAX_EDGES_PER_NODE).all
            WITH node_a_tags AS (
              SELECT tag_id
              FROM node_tags
              WHERE node_id = ?
                AND deleted_at IS NULL
            ),
            shared AS (
              SELECT nt.node_id AS target_id, COUNT(*) AS shared_count
              FROM node_tags nt
              WHERE nt.tag_id IN (SELECT tag_id FROM node_a_tags)
                AND nt.node_id != ?
                AND nt.deleted_at IS NULL
              GROUP BY nt.node_id
            ),
            target_tag_counts AS (
              SELECT node_id, COUNT(*) AS tag_count
              FROM node_tags
              WHERE node_id IN (SELECT target_id FROM shared)
                AND deleted_at IS NULL
              GROUP BY node_id
            ),
            source_tag_count AS (
              SELECT COUNT(*) AS tag_count FROM node_a_tags
            )
            SELECT
              s.target_id,
              s.shared_count::float /
                (sc.tag_count + tc.tag_count - s.shared_count)::float AS weight
            FROM shared s
            JOIN target_tag_counts tc ON tc.node_id = s.target_id
            CROSS JOIN source_tag_count sc
            WHERE sc.tag_count > 0
              AND (sc.tag_count + tc.tag_count - s.shared_count) > 0
            ORDER BY weight DESC
            LIMIT ?
          SQL
        end

        # Upsert both directions for each candidate above the weight threshold.
        # Uses INSERT ... ON CONFLICT DO UPDATE so re-runs refresh stale weights.
        #
        # @return [Integer] number of edge-pairs inserted or updated
        #
        def upsert_edges(node_id, candidates)
          now  = Time.now
          rows = []

          candidates.each do |row|
            weight = row[:weight].to_f
            next if weight < MIN_WEIGHT_THRESHOLD

            rows << { source_id: node_id,          target_id: row[:target_id],
                      rel_type: 'related_to', origin: 'tag_cooccurrence',
                      weight: weight, created_at: now, updated_at: now }
            rows << { source_id: row[:target_id], target_id: node_id,
                      rel_type: 'related_to', origin: 'tag_cooccurrence',
                      weight: weight, created_at: now, updated_at: now }
          end

          return 0 if rows.empty?

          HTM.db[:node_relationships].insert_conflict(
            target:  %i[source_id target_id rel_type],
            update:  { weight: Sequel[:excluded][:weight], updated_at: Sequel[:excluded][:updated_at] }
          ).multi_insert(rows)

          rows.length / 2
        end

        def elapsed_ms(start_time)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        end
      end
    end
  end
end
