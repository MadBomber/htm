# Class HTM::RobotGroup <a id="class-HTM-RobotGroup"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/robot_group.rb |

Coordinates multiple robots with shared working memory and automatic failover.

RobotGroup provides application-level coordination for multiple HTM robots,
enabling them to share a common working memory context. Key capabilities
include:

*   **Shared Working Memory**: All group members have access to the same
    context
*   **Active/Passive Roles**: Active robots participate in conversations;
    passive robots maintain synchronized context for instant failover
*   **Real-time Sync**: PostgreSQL LISTEN/NOTIFY enables immediate
    synchronization
*   **Failover**: When an active robot fails, a passive robot takes over
    instantly
*   **Dynamic Scaling**: Add or remove robots at runtime

- **`@see`** `HTM::WorkingMemoryChannel` Low-level pub/sub mechanism

**@example High-availability customer support setup**
```ruby
group = HTM::RobotGroup.new(
  name: 'customer-support',
  active: ['primary-agent'],
  passive: ['standby-agent'],
  max_tokens: 8000
)

# Add shared context
group.remember('Customer prefers email communication.')
group.remember('Open ticket #789 regarding billing issue.')

# Query shared memory
results = group.recall('billing', limit: 5)

# Simulate failover
group.failover!  # Promotes standby to active

# Cleanup
group.shutdown
```

## Attributes
### `channel` [R] <a id="attribute-i-channel"></a> <a id="channel-instance_method"></a>
The pub/sub channel used for real-time synchronization
- **`@return`** [HTM::WorkingMemoryChannel]

### `max_tokens` [R] <a id="attribute-i-max_tokens"></a> <a id="max_tokens-instance_method"></a>
Maximum token budget for working memory
- **`@return`** [Integer]

### `name` [R] <a id="attribute-i-name"></a> <a id="name-instance_method"></a>
Name of the robot group
- **`@return`** [String]

## Public Instance Methods
### Membership Management
#### `active?(robot_name)` <a id="method-i-active-3F"></a> <a id="active?-instance_method"></a>
Checks if a robot is an active member of this group.
- **`@param`** `robot_name` [String] Name of the robot to check
- **`@return`** [Boolean] true if the robot is an active member

**`@example`**
```ruby
group.active?('primary-agent')  # => true
```

#### `active_robot_names()` <a id="method-i-active_robot_names"></a> <a id="active_robot_names-instance_method"></a>
Returns names of all active robots.
- **`@return`** [Array<String>] Array of active robot names

**`@example`**
```ruby
group.active_robot_names  # => ['primary-agent', 'secondary-agent']
```

#### `add_active(robot_name)` <a id="method-i-add_active"></a> <a id="add_active-instance_method"></a>
Adds a robot as an active member of the group.

Active robots can add memories and respond to queries. The new robot is
automatically synchronized with existing shared working memory.
- **`@param`** `robot_name` [String] Unique name for the robot
- **`@raise`** [ArgumentError] if robot_name is already a member
- **`@return`** [Integer] The robot's database ID

**`@example`**
```ruby
robot_id = group.add_active('new-agent')
puts "Added robot with ID: #{robot_id}"
```

#### `add_passive(robot_name)` <a id="method-i-add_passive"></a> <a id="add_passive-instance_method"></a>
Adds a robot as a passive (standby) member of the group.

Passive robots maintain synchronized working memory but don't actively
participate in conversations. They serve as warm standbys for failover.
- **`@param`** `robot_name` [String] Unique name for the robot
- **`@raise`** [ArgumentError] if robot_name is already a member
- **`@return`** [Integer] The robot's database ID

**`@example`**
```ruby
robot_id = group.add_passive('standby-agent')
```

#### `demote(robot_name)` <a id="method-i-demote"></a> <a id="demote-instance_method"></a>
Demotes an active robot to passive status.

The robot retains its working memory but stops handling queries. Cannot demote
the last active robot.
- **`@param`** `robot_name` [String] Name of the active robot to demote
- **`@raise`** [ArgumentError] if robot_name is not an active member
- **`@raise`** [ArgumentError] if this is the last active robot
- **`@return`** [void]

**`@example`**
```ruby
group.demote('primary-agent')
group.passive?('primary-agent')  # => true
```

#### `member?(robot_name)` <a id="method-i-member-3F"></a> <a id="member?-instance_method"></a>
Checks if a robot is a member of this group.
- **`@param`** `robot_name` [String] Name of the robot to check
- **`@return`** [Boolean] true if the robot is an active or passive member

**`@example`**
```ruby
group.member?('agent-1')  # => true
group.member?('unknown')  # => false
```

#### `member_ids()` <a id="method-i-member_ids"></a> <a id="member_ids-instance_method"></a>
Returns database IDs of all group members.
- **`@return`** [Array<Integer>] Array of robot IDs (both active and passive)

**`@example`**
```ruby
group.member_ids  # => [1, 2, 3]
```

#### `passive?(robot_name)` <a id="method-i-passive-3F"></a> <a id="passive?-instance_method"></a>
Checks if a robot is a passive member of this group.
- **`@param`** `robot_name` [String] Name of the robot to check
- **`@return`** [Boolean] true if the robot is a passive member

**`@example`**
```ruby
group.passive?('standby-agent')  # => true
```

#### `passive_robot_names()` <a id="method-i-passive_robot_names"></a> <a id="passive_robot_names-instance_method"></a>
Returns names of all passive robots.
- **`@return`** [Array<String>] Array of passive robot names

**`@example`**
```ruby
group.passive_robot_names  # => ['standby-agent']
```

#### `promote(robot_name)` <a id="method-i-promote"></a> <a id="promote-instance_method"></a>
Promotes a passive robot to active status.

The robot retains its synchronized working memory and becomes eligible to
handle queries and add memories.
- **`@param`** `robot_name` [String] Name of the passive robot to promote
- **`@raise`** [ArgumentError] if robot_name is not a passive member
- **`@return`** [void]

**`@example`**
```ruby
group.promote('standby-agent')
group.active?('standby-agent')  # => true
```

#### `remove(robot_name)` <a id="method-i-remove"></a> <a id="remove-instance_method"></a>
Removes a robot from the group.

Clears the robot's working memory flags in the database. The robot can be
either active or passive.
- **`@param`** `robot_name` [String] Name of the robot to remove
- **`@return`** [void]

**`@example`**
```ruby
group.remove('departing-agent')
```
### Shared Working Memory Operations
#### `clear_working_memory()` <a id="method-i-clear_working_memory"></a> <a id="clear_working_memory-instance_method"></a>
Clears shared working memory for all group members.

Updates database flags and notifies all members to clear their in-memory
caches.
- **`@return`** [Integer] Number of robot_node records updated

**`@example`**
```ruby
cleared_count = group.clear_working_memory
puts "Cleared #{cleared_count} working memory entries"
```

#### `recall(query)` <a id="method-i-recall"></a> <a id="recall-instance_method"></a>
Recalls memories from shared working memory.

Uses the first active robot to perform the query against the shared working
memory context.
- **`@option`** `options[:limit]` [Integer] Maximum number of results
- **`@option`** `options[:strategy]` [Symbol] Search strategy (:vector, :fulltext, :hybrid)
- **`@param`** `query` [String] The search query
- **`@param`** `options` [Hash] Additional options passed to HTM#recall
- **`@raise`** [RuntimeError] if no active robots exist in the group
- **`@return`** [Array] Array of matching memories

**`@example`**
```ruby
results = group.recall('billing issue', limit: 5, strategy: :fulltext)
```

#### `remember(content, originator: nil)` <a id="method-i-remember"></a> <a id="remember-instance_method"></a>
Adds content to shared working memory for all group members.

The memory is created by the specified originator (or first active robot) and
automatically synchronized to all other members via database and real-time
notifications.
- **`@param`** `content` [String] The content to remember
- **`@param`** `originator` [String, nil] Name of the robot creating the memory (optional)
- **`@param`** `options` [Hash] Additional options passed to HTM#remember
- **`@raise`** [RuntimeError] if no active robots exist in the group
- **`@return`** [Integer] The node ID of the created memory

**@example Add memory with default originator**
```ruby
node_id = group.remember('Customer prefers morning appointments.')
```

**@example Add memory with specific originator**
```ruby
node_id = group.remember(
  'Escalated to billing department.',
  originator: 'agent-2'
)
```

#### `working_memory_contents()` <a id="method-i-working_memory_contents"></a> <a id="working_memory_contents-instance_method"></a>
Returns all nodes currently in shared working memory.

Queries the database for the union of all members' working memory, returning
nodes sorted by creation date (newest first).
- **`@return`** [Sequel::Dataset] Collection of nodes

**`@example`**
```ruby
nodes = group.working_memory_contents
nodes.each { |n| puts n.content }
```
### Synchronization
#### `in_sync?()` <a id="method-i-in_sync-3F"></a> <a id="in_sync?-instance_method"></a>
Checks if all members have identical working memory.

Compares the set of working memory node IDs across all members.
- **`@return`** [Boolean] true if all members have the same working memory nodes

**`@example`**
```ruby
if group.in_sync?
  puts "All robots synchronized"
else
  group.sync_all
end
```

#### `sync_all()` <a id="method-i-sync_all"></a> <a id="sync_all-instance_method"></a>
Synchronizes all members to a consistent state.

Ensures every member has access to all shared working memory nodes.
- **`@return`** [Hash] Sync results with :synced_nodes and :members_updated counts

**`@example`**
```ruby
result = group.sync_all
puts "Synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"
```

#### `sync_robot(robot_name)` <a id="method-i-sync_robot"></a> <a id="sync_robot-instance_method"></a>
Synchronizes a specific robot to match the group's shared working memory.

Copies working memory flags from other members to the specified robot,
ensuring it has access to all shared context.
- **`@param`** `robot_name` [String] Name of the robot to synchronize
- **`@raise`** [ArgumentError] if robot_name is not a member
- **`@return`** [Integer] Number of nodes synchronized

**`@example`**
```ruby
synced = group.sync_robot('new-agent')
puts "Synchronized #{synced} nodes"
```
### Failover
#### `failover!()` <a id="method-i-failover-21"></a> <a id="failover!-instance_method"></a>
Performs automatic failover to the first passive robot.

Promotes the first passive robot to active status. The promoted robot already
has synchronized working memory and can immediately handle requests.
- **`@raise`** [RuntimeError] if no passive robots are available
- **`@return`** [String] Name of the promoted robot

**`@example`**
```ruby
promoted = group.failover!
puts "#{promoted} is now active"
```

#### `transfer_working_memory(from_robot, to_robot, clear_source: true)` <a id="method-i-transfer_working_memory"></a> <a id="transfer_working_memory-instance_method"></a>
Transfers working memory from one robot to another.

Copies all working memory node references from the source robot to the target
robot, optionally clearing the source.
- **`@param`** `from_robot` [String] Name of the source robot
- **`@param`** `to_robot` [String] Name of the destination robot
- **`@param`** `clear_source` [Boolean] Whether to clear source's working memory after transfer
- **`@raise`** [ArgumentError] if either robot is not a member
- **`@return`** [Integer] Number of nodes transferred

**@example Transfer with source clearing**
```ruby
transferred = group.transfer_working_memory('failing-agent', 'backup-agent')
```

**@example Transfer without clearing source**
```ruby
transferred = group.transfer_working_memory(
  'agent-1', 'agent-2',
  clear_source: false
)
```
### Status & Health
#### `status()` <a id="method-i-status"></a> <a id="status-instance_method"></a>
Returns comprehensive status information about the group.
- **`@option`** `return[:name]` [String] Group name
- **`@option`** `return[:active]` [Array<String>] Names of active robots
- **`@option`** `return[:passive]` [Array<String>] Names of passive robots
- **`@option`** `return[:total_members]` [Integer] Total number of members
- **`@option`** `return[:working_memory_nodes]` [Integer] Number of nodes in shared memory
- **`@option`** `return[:working_memory_tokens]` [Integer] Total tokens in shared memory
- **`@option`** `return[:max_tokens]` [Integer] Maximum token budget
- **`@option`** `return[:token_utilization]` [Float] Ratio of used to max tokens (0.0-1.0)
- **`@option`** `return[:in_sync]` [Boolean] Whether all members are synchronized
- **`@param`** `return` [Hash] a customizable set of options
- **`@return`** [Hash] Status hash with the following keys:

**`@example`**
```ruby
status = group.status
puts "Group: #{status[:name]}"
puts "Active: #{status[:active].join(', ')}"
puts "Utilization: #{(status[:token_utilization] * 100).round(1)}%"
```

#### `sync_stats()` <a id="method-i-sync_stats"></a> <a id="sync_stats-instance_method"></a>
Returns statistics about real-time synchronization.
- **`@return`** [Hash] Stats hash with :nodes_synced and :evictions_synced counts

**`@example`**
```ruby
stats = group.sync_stats
puts "Nodes synced: #{stats[:nodes_synced]}"
puts "Evictions synced: #{stats[:evictions_synced]}"
```
### General
#### `initialize(name:, active: [], passive: [], max_tokens: 4000, db_config: nil)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Creates a new robot group with optional initial members.

Initializes the group, sets up the PostgreSQL pub/sub channel for real-time
synchronization, and registers initial active and passive robots.
- **`@param`** `name` [String] Unique name for this robot group
- **`@param`** `active` [Array<String>] Names of robots to add as active members
- **`@param`** `passive` [Array<String>] Names of robots to add as passive (standby) members
- **`@param`** `max_tokens` [Integer] Maximum token budget for shared working memory
- **`@param`** `db_config` [Hash, nil] PostgreSQL connection config (defaults to HTM::Database.default_config)
- **`@return`** [RobotGroup] a new instance of RobotGroup

**@example Create a group with one active and one passive robot**
```ruby
group = HTM::RobotGroup.new(
  name: 'support-team',
  active: ['agent-1'],
  passive: ['agent-2'],
  max_tokens: 4000
)
```

**@example Create an empty group and add members later**
```ruby
group = HTM::RobotGroup.new(name: 'dynamic-team')
group.add_active('agent-1')
group.add_passive('agent-2')
```

#### `shutdown()` <a id="method-i-shutdown"></a> <a id="shutdown-instance_method"></a>
Shuts down the group by stopping the listener thread.

Should be called when the group is no longer needed to release resources and
close the PostgreSQL listener connection.
- **`@return`** [void]

**`@example`**
```ruby
group.shutdown
```
