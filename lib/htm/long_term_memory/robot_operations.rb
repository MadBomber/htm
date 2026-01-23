# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Robot registration and activity tracking
    #
    # Handles robot lifecycle management including:
    # - Registration (find or create)
    # - Activity timestamp updates
    #
    module RobotOperations
      # Register a robot
      #
      # @param robot_name [String] Robot name
      # @return [Integer] Robot ID
      #
      def register_robot(robot_name)
        robot = HTM::Models::Robot.find_or_create(name: robot_name)
        robot.update(last_active: Time.now)
        robot.id
      end

      # Update robot activity timestamp
      #
      # @param robot_id [Integer] Robot identifier
      # @return [void]
      #
      def update_robot_activity(robot_id)
        robot = HTM::Models::Robot.first(id: robot_id)
        robot&.update(last_active: Time.now)
      end
    end
  end
end
