# frozen_string_literal: true

class HTM
  module Models
    # OperationLog model - audit trail of HTM operations
    # Stored in TimescaleDB hypertable for efficient time-series queries
    class OperationLog < ActiveRecord::Base
      self.table_name = 'operations_log'

      # Associations
      belongs_to :robot, class_name: 'HTM::Models::Robot', foreign_key: 'robot_id', optional: true

      # Validations
      validates :operation, presence: true

      # Callbacks
      before_create :set_created_at

      # Scopes
      scope :by_robot, ->(robot_id) { where(robot_id: robot_id) }
      scope :by_operation, ->(operation) { where(operation: operation) }
      scope :recent, -> { order(created_at: :desc) }
      scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
      scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
      scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }

      # Class methods
      def self.log_operation(robot_id:, operation:, details: {})
        create(
          robot_id: robot_id,
          operation: operation,
          details: details
        )
      end

      def self.operation_summary(robot_id = nil)
        scope = robot_id ? by_robot(robot_id) : all
        scope.group(:operation).count
      end

      def self.recent_operations(robot_id = nil, limit = 50)
        scope = robot_id ? by_robot(robot_id) : all
        scope.recent.limit(limit)
      end

      # Instance methods
      def details_json
        details.is_a?(String) ? JSON.parse(details) : details
      rescue JSON::ParserError
        {}
      end

      private

      def set_created_at
        self.created_at ||= Time.current
      end
    end
  end
end
