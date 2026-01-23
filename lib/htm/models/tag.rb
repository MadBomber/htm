# frozen_string_literal: true

class HTM
  module Models
    # Tag model - represents unique tag names
    # Tags have a many-to-many relationship with nodes through node_tags
    class Tag < Sequel::Model(:tags)
      # Associations
      one_to_many :node_tags, class: 'HTM::Models::NodeTag', key: :tag_id
      many_to_many :nodes, class: 'HTM::Models::Node',
                   join_table: :node_tags, left_key: :tag_id, right_key: :node_id

      # Plugins
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Tag name format regex
      TAG_FORMAT = /\A[a-z0-9\-]+(:[a-z0-9\-]+)*\z/

      # Validations
      def validate
        super
        validates_presence :name
        validates_format TAG_FORMAT, :name,
          message: "must be lowercase with hyphens, using colons for hierarchy (e.g., 'database:postgresql:performance')"
        validates_unique :name, message: "already exists"
      end

      # Dataset methods (scopes)
      dataset_module do
        # Soft delete - by default, only show non-deleted tags
        def active
          where(deleted_at: nil)
        end

        def by_name(name)
          where(name: name)
        end

        def with_prefix(prefix)
          where(Sequel.like(:name, "#{prefix}%"))
        end

        def hierarchical
          where(Sequel.like(:name, '%:%'))
        end

        def root_level
          exclude(Sequel.like(:name, '%:%'))
        end

        def deleted
          exclude(deleted_at: nil)
        end

        def with_deleted
          unfiltered
        end

        # Orphaned tags - tags with no active (non-deleted) node associations
        def orphaned
          where(
            Sequel.lit(
              "NOT EXISTS (
                SELECT 1 FROM node_tags
                JOIN nodes ON nodes.id = node_tags.node_id
                WHERE node_tags.tag_id = tags.id
                AND node_tags.deleted_at IS NULL
                AND nodes.deleted_at IS NULL
              )"
            )
          )
        end
      end

      # Apply default scope for active records
      set_dataset(dataset.where(Sequel[:tags][:deleted_at] => nil))

      # Hooks
      def before_create
        self.created_at ||= Time.now
        super
      end

      # Class methods

      # Check if a tag exists with the given conditions
      #
      # @param conditions [Hash] Conditions to check
      # @return [Boolean] true if a matching tag exists
      #
      def self.exists?(conditions = {})
        where(conditions).any?
      end

      # Find tags with a given prefix (hierarchical query)
      #
      # @param prefix [String] Tag prefix to match (e.g., "database" matches "database:postgresql")
      # @return [Sequel::Dataset] Tags matching the prefix
      #
      def self.find_by_topic_prefix(prefix)
        dataset.with_prefix(prefix)
      end

      # Get the most frequently used tags
      #
      # @param limit [Integer] Maximum number of tags to return (default: 10)
      # @return [Array<Tag>] Tags with usage_count attribute
      #
      def self.popular_tags(limit = 10)
        dataset
          .select_append { count(node_tags[:id]).as(usage_count) }
          .join(:node_tags, tag_id: :id)
          .group(:id)
          .order(Sequel.desc(:usage_count))
          .limit(limit)
          .all
      end

      # Find or create a tag by name
      #
      # @param name [String] Hierarchical tag name (e.g., "database:postgresql")
      # @return [Tag] The found or created tag
      #
      def self.find_or_create_by_name(name)
        find_or_create(name: name)
      end

      # Expand a hierarchical tag name into all ancestor paths
      #
      # @param tag_name [String] Hierarchical tag (e.g., "a:b:c:d")
      # @return [Array<String>] All paths from root to leaf
      #
      def self.expand_hierarchy(tag_name)
        return [] if tag_name.nil? || tag_name.empty?

        levels = tag_name.split(':')
        (1..levels.size).map { |i| levels[0, i].join(':') }
      end

      # Find or create a tag and all its ancestor tags
      #
      # @param name [String] Hierarchical tag name (e.g., "database:postgresql:extensions")
      # @return [Array<Tag>] All created/found tags from root to leaf
      #
      def self.find_or_create_with_ancestors(name)
        expand_hierarchy(name).map do |tag_name|
          find_or_create(name: tag_name)
        end
      end

      # Returns a nested hash tree structure from the current scope
      #
      # @return [Hash] Nested hash representing the tag hierarchy
      #
      def self.tree
        tree = {}

        order(:name).select_map(:name).each do |tag_name|
          parts = tag_name.split(':')
          current = tree

          parts.each do |part|
            current[part] ||= {}
            current = current[part]
          end
        end

        tree
      end

      # Returns a formatted string representation of the tag tree
      #
      # @return [String] Formatted tree string
      #
      def self.tree_string
        format_tree_branch(tree)
      end

      # Returns a Mermaid flowchart representation of the tag tree
      #
      # @param direction [String] Flow direction: 'TD' (top-down), 'LR' (left-right), 'BT', 'RL'
      # @return [String] Mermaid flowchart syntax
      #
      def self.tree_mermaid(direction: 'TD')
        tree_data = tree
        return "flowchart #{direction}\n  empty[No tags]" if tree_data.empty?

        lines = ["flowchart #{direction}"]
        node_id = 0
        node_ids = {}

        generate_mermaid_nodes(tree_data, nil, lines, node_ids, node_id)

        lines.join("\n")
      end

      # Returns an SVG representation of the tag tree
      #
      # @param title [String] Optional title for the SVG
      # @return [String] SVG markup
      #
      def self.tree_svg(title: 'HTM Tag Hierarchy')
        tree_data = tree
        return empty_tree_svg(title) if tree_data.empty?

        stats = calculate_tree_stats(tree_data)
        max_depth = stats[:max_depth]

        node_width = 140
        node_height = 30
        h_spacing = 180
        v_spacing = 50
        padding = 40

        positions = {}
        y_offset = [0]
        calculate_node_positions(tree_data, 0, positions, y_offset, h_spacing, v_spacing)

        width = (max_depth * h_spacing) + node_width + (padding * 2)
        height = (y_offset[0] * v_spacing) + node_height + (padding * 2)

        generate_tree_svg(tree_data, positions, width, height, padding, node_width, node_height, title)
      end

      # Format a tree branch recursively (internal helper)
      def self.format_tree_branch(node, is_last_array = [])
        result = ''
        sorted_keys = node.keys.sort

        sorted_keys.each_with_index do |key, index|
          is_last = (index == sorted_keys.size - 1)

          line_prefix = is_last_array.map { |was_last| was_last ? '    ' : '|   ' }.join

          branch = is_last ? '+-- ' : '+-- '
          result += "#{line_prefix}#{branch}#{key}\n"

          children = node[key]
          unless children.empty?
            result += format_tree_branch(children, is_last_array + [is_last])
          end
        end

        result
      end

      # Generate Mermaid nodes recursively (internal helper)
      def self.generate_mermaid_nodes(node, parent_path, lines, node_ids, counter)
        node.keys.sort.each do |key|
          current_path = parent_path ? "#{parent_path}:#{key}" : key

          node_id = "n#{counter}"
          node_ids[current_path] = node_id
          counter += 1

          lines << "  #{node_id}[\"#{key}\"]"

          if parent_path && node_ids[parent_path]
            lines << "  #{node_ids[parent_path]} --> #{node_id}"
          end

          children = node[key]
          counter = generate_mermaid_nodes(children, current_path, lines, node_ids, counter) unless children.empty?
        end

        counter
      end

      # Calculate tree statistics (internal helper)
      def self.calculate_tree_stats(node, depth = 0)
        return { total_nodes: 0, max_depth: depth } if node.empty?

        total = node.keys.size
        max = depth + 1

        node.each_value do |children|
          child_stats = calculate_tree_stats(children, depth + 1)
          total += child_stats[:total_nodes]
          max = [max, child_stats[:max_depth]].max
        end

        { total_nodes: total, max_depth: max }
      end

      # Calculate node positions for SVG layout (internal helper)
      def self.calculate_node_positions(node, depth, positions, y_offset, h_spacing, v_spacing, parent_path = nil)
        node.keys.sort.each do |key|
          current_path = parent_path ? "#{parent_path}:#{key}" : key

          positions[current_path] = {
            x: depth,
            y: y_offset[0],
            label: key
          }
          y_offset[0] += 1

          children = node[key]
          calculate_node_positions(children, depth + 1, positions, y_offset, h_spacing, v_spacing, current_path) unless children.empty?
        end
      end

      # Generate SVG for empty tree (internal helper)
      def self.empty_tree_svg(title)
        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 100">
            <rect width="100%" height="100%" fill="transparent"/>
            <text x="150" y="30" text-anchor="middle" fill="#9CA3AF" font-family="system-ui, sans-serif" font-size="14" font-weight="bold">#{title}</text>
            <text x="150" y="60" text-anchor="middle" fill="#6B7280" font-family="system-ui, sans-serif" font-size="12">No tags found</text>
          </svg>
        SVG
      end

      # Generate SVG tree visualization (internal helper)
      def self.generate_tree_svg(tree_data, positions, width, height, padding, node_width, node_height, title)
        colors = ['#3B82F6', '#8B5CF6', '#EC4899', '#F59E0B', '#10B981', '#6366F1']

        svg_lines = []
        svg_lines << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height + 40}">)
        svg_lines << '  <rect width="100%" height="100%" fill="transparent"/>'

        svg_lines << %Q(  <text x="#{width / 2}" y="25" text-anchor="middle" fill="#F3F4F6" font-family="system-ui, sans-serif" font-size="16" font-weight="bold">#{title}</text>)

        positions.each do |path, pos|
          parent_path = path.include?(':') ? path.split(':')[0..-2].join(':') : nil
          next unless parent_path && positions[parent_path]

          parent_pos = positions[parent_path]
          x1 = padding + (parent_pos[:x] * (node_width + 40)) + node_width
          y1 = 40 + padding + (parent_pos[:y] * (node_height + 20)) + (node_height / 2)
          x2 = padding + (pos[:x] * (node_width + 40))
          y2 = 40 + padding + (pos[:y] * (node_height + 20)) + (node_height / 2)

          mid_x = (x1 + x2) / 2
          svg_lines << %Q(  <path d="M#{x1},#{y1} C#{mid_x},#{y1} #{mid_x},#{y2} #{x2},#{y2}" stroke="#4B5563" stroke-width="2" fill="none"/>)
        end

        positions.each do |path, pos|
          depth = path.count(':')
          color = colors[depth % colors.size]

          x = padding + (pos[:x] * (node_width + 40))
          y = 40 + padding + (pos[:y] * (node_height + 20))

          svg_lines << %Q(  <rect x="#{x}" y="#{y}" width="#{node_width}" height="#{node_height}" rx="6" fill="#{color}" opacity="0.9"/>)

          text_x = x + (node_width / 2)
          text_y = y + (node_height / 2) + 4
          svg_lines << %Q(  <text x="#{text_x}" y="#{text_y}" text-anchor="middle" fill="#FFFFFF" font-family="system-ui, sans-serif" font-size="11" font-weight="500">#{pos[:label]}</text>)
        end

        svg_lines << '</svg>'
        svg_lines.join("\n")
      end

      # Instance methods

      # Get the root (top-level) topic of this tag
      #
      # @return [String] The first segment of the hierarchical tag
      #
      def root_topic
        name.split(':').first
      end

      # Get all hierarchy levels of this tag
      #
      # @return [Array<String>] Array of topic segments
      #
      def topic_levels
        name.split(':')
      end

      # Get the depth (number of levels) of this tag
      #
      # @return [Integer] Number of hierarchy levels
      #
      def depth
        topic_levels.length
      end

      # Check if this tag is hierarchical (has child levels)
      #
      # @return [Boolean] True if tag contains colons (hierarchy separators)
      #
      def hierarchical?
        name.include?(':')
      end

      # Get the number of nodes using this tag
      #
      # @return [Integer] Count of nodes with this tag
      #
      def usage_count
        node_tags_dataset.count
      end

      # Soft delete - mark tag as deleted without removing from database
      #
      # @return [Boolean] true if soft deleted successfully
      #
      def soft_delete!
        update(deleted_at: Time.now)
        true
      end

      # Restore a soft-deleted tag
      #
      # @return [Boolean] true if restored successfully
      #
      def restore!
        update(deleted_at: nil)
        true
      end

      # Check if tag is soft-deleted
      #
      # @return [Boolean] true if deleted_at is set
      #
      def deleted?
        !deleted_at.nil?
      end
    end
  end
end
