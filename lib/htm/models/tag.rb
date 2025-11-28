# frozen_string_literal: true

class HTM
  module Models
    # Tag model - represents unique tag names
    # Tags have a many-to-many relationship with nodes through node_tags
    class Tag < ActiveRecord::Base
      self.table_name = 'tags'

      # Associations
      has_many :node_tags, class_name: 'HTM::Models::NodeTag', dependent: :destroy
      has_many :nodes, through: :node_tags, class_name: 'HTM::Models::Node'

      # Validations
      validates :name, presence: true
      validates :name, format: {
        with: /\A[a-z0-9\-]+(:[a-z0-9\-]+)*\z/,
        message: "must be lowercase with hyphens, using colons for hierarchy (e.g., 'database:postgresql:performance')"
      }
      validates :name, uniqueness: { message: "already exists" }

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :by_name, ->(name) { where(name: name) }
      scope :with_prefix, ->(prefix) { where("name LIKE ?", "#{prefix}%") }
      scope :hierarchical, -> { where("name LIKE '%:%'") }
      scope :root_level, -> { where("name NOT LIKE '%:%'") }

      # Class methods
      def self.find_by_topic_prefix(prefix)
        where("name LIKE ?", "#{prefix}%")
      end

      def self.popular_tags(limit = 10)
        joins(:node_tags)
          .select('tags.*, COUNT(node_tags.id) as usage_count')
          .group('tags.id')
          .order('usage_count DESC')
          .limit(limit)
      end

      def self.find_or_create_by_name(name)
        find_or_create_by(name: name)
      end

      # Returns a nested hash tree structure from the current scope
      # Example: Tag.all.tree => { "database" => { "postgresql" => {} } }
      # Example: Tag.with_prefix("database").tree => { "database" => { "postgresql" => {} } }
      def self.tree
        tree = {}

        all.order(:name).pluck(:name).each do |tag_name|
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
      # Uses directory-style formatting with ├── and └── characters
      # Example: puts Tag.all.tree_string
      # Example: puts Tag.with_prefix("database").tree_string
      def self.tree_string
        format_tree_branch(tree)
      end

      # Returns a Mermaid flowchart representation of the tag tree
      # Example: puts Tag.all.tree_mermaid
      # Example: Tag.all.tree_mermaid(direction: 'LR') # Left to right
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

        # Generate Mermaid nodes and connections
        generate_mermaid_nodes(tree_data, nil, lines, node_ids, node_id)

        lines.join("\n")
      end

      # Returns an SVG representation of the tag tree
      # Uses dark theme with transparent background
      # Example: File.write('tags.svg', Tag.all.tree_svg)
      #
      # @param title [String] Optional title for the SVG
      # @return [String] SVG markup
      #
      def self.tree_svg(title: 'HTM Tag Hierarchy')
        tree_data = tree
        return empty_tree_svg(title) if tree_data.empty?

        # Calculate dimensions based on tree structure
        stats = calculate_tree_stats(tree_data)
        node_count = stats[:total_nodes]
        max_depth = stats[:max_depth]

        # Layout constants
        node_width = 140
        node_height = 30
        h_spacing = 180
        v_spacing = 50
        padding = 40

        # Calculate positions for all nodes
        positions = {}
        y_offset = [0]  # Use array to allow mutation in closure
        calculate_node_positions(tree_data, 0, positions, y_offset, h_spacing, v_spacing)

        # Calculate SVG dimensions
        width = (max_depth * h_spacing) + node_width + (padding * 2)
        height = (y_offset[0] * v_spacing) + node_height + (padding * 2)

        # Generate SVG
        generate_tree_svg(tree_data, positions, width, height, padding, node_width, node_height, title)
      end

      # Format a tree branch recursively (internal helper)
      def self.format_tree_branch(node, is_last_array = [])
        result = ''
        sorted_keys = node.keys.sort

        sorted_keys.each_with_index do |key, index|
          is_last = (index == sorted_keys.size - 1)

          # Build prefix from parent branches
          line_prefix = is_last_array.map { |was_last| was_last ? '    ' : '│   ' }.join

          # Add branch character and key
          branch = is_last ? '└── ' : '├── '
          result += "#{line_prefix}#{branch}#{key}\n"

          # Recurse into children
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

          # Create unique node ID
          node_id = "n#{counter}"
          node_ids[current_path] = node_id
          counter += 1

          # Add node definition with styling
          lines << "  #{node_id}[\"#{key}\"]"

          # Add connection from parent
          if parent_path && node_ids[parent_path]
            lines << "  #{node_ids[parent_path]} --> #{node_id}"
          end

          # Recurse into children
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
        # Color palette for different depths (dark theme)
        colors = ['#3B82F6', '#8B5CF6', '#EC4899', '#F59E0B', '#10B981', '#6366F1']

        svg_lines = []
        svg_lines << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height + 40}">)
        svg_lines << '  <rect width="100%" height="100%" fill="transparent"/>'

        # Title
        svg_lines << %Q(  <text x="#{width / 2}" y="25" text-anchor="middle" fill="#F3F4F6" font-family="system-ui, sans-serif" font-size="16" font-weight="bold">#{title}</text>)

        # Draw connections first (so they appear behind nodes)
        positions.each do |path, pos|
          parent_path = path.include?(':') ? path.split(':')[0..-2].join(':') : nil
          next unless parent_path && positions[parent_path]

          parent_pos = positions[parent_path]
          x1 = padding + (parent_pos[:x] * (node_width + 40)) + node_width
          y1 = 40 + padding + (parent_pos[:y] * (node_height + 20)) + (node_height / 2)
          x2 = padding + (pos[:x] * (node_width + 40))
          y2 = 40 + padding + (pos[:y] * (node_height + 20)) + (node_height / 2)

          # Curved connection line
          mid_x = (x1 + x2) / 2
          svg_lines << %Q(  <path d="M#{x1},#{y1} C#{mid_x},#{y1} #{mid_x},#{y2} #{x2},#{y2}" stroke="#4B5563" stroke-width="2" fill="none"/>)
        end

        # Draw nodes
        positions.each do |path, pos|
          depth = path.count(':')
          color = colors[depth % colors.size]

          x = padding + (pos[:x] * (node_width + 40))
          y = 40 + padding + (pos[:y] * (node_height + 20))

          # Node rectangle with rounded corners
          svg_lines << %Q(  <rect x="#{x}" y="#{y}" width="#{node_width}" height="#{node_height}" rx="6" fill="#{color}" opacity="0.9"/>)

          # Node label
          text_x = x + (node_width / 2)
          text_y = y + (node_height / 2) + 4
          svg_lines << %Q(  <text x="#{text_x}" y="#{text_y}" text-anchor="middle" fill="#FFFFFF" font-family="system-ui, sans-serif" font-size="11" font-weight="500">#{pos[:label]}</text>)
        end

        svg_lines << '</svg>'
        svg_lines.join("\n")
      end

      # Instance methods
      def root_topic
        name.split(':').first
      end

      def topic_levels
        name.split(':')
      end

      def depth
        topic_levels.length
      end

      def hierarchical?
        name.include?(':')
      end

      def usage_count
        node_tags.count
      end

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
