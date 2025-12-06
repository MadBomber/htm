# examples/robot_groups/lib/robot_group.rb
# frozen_string_literal: true
#
# Compatibility shim - loads the HTM-namespaced version

require_relative 'htm/working_memory_channel'
require_relative 'htm/robot_group'

# Alias for backward compatibility with demo applications
RobotGroup = HTM::RobotGroup
