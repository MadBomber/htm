# examples/robot_groups/lib/working_memory_channel.rb
# frozen_string_literal: true
#
# Compatibility shim - loads the HTM-namespaced version

require_relative 'htm/working_memory_channel'

# Alias for backward compatibility with demo applications
WorkingMemoryChannel = HTM::WorkingMemoryChannel
