# Class: HTM::RobotGroup
**Inherits:** Object
    

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

**`@see`** [] Low-level pub/sub mechanism


**`@example`**
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
# Attributes
## channel[RW] {: #attribute-i-channel }
The pub/sub channel used for real-time synchronization

**`@return`** [HTM::WorkingMemoryChannel] 

## max_tokens[RW] {: #attribute-i-max_tokens }
Maximum token budget for working memory

**`@return`** [Integer] 

## name[RW] {: #attribute-i-name }
Name of the robot group

**`@return`** [String] 


# Instance Methods
## active?(robot_name) {: #method-i-active? }
Checks if a robot is an active member of this group.

**`@param`** [String] Name of the robot to check

**`@return`** [Boolean] true if the robot is an active member


**`@example`**
```ruby
group.active?('primary-agent')  # => true
```
## active_robot_names() {: #method-i-active_robot_names }
Returns names of all active robots.

**`@return`** [Array<String>] Array of active robot names


**`@example`**
```ruby
group.active_robot_names  # => ['primary-agent', 'secondary-agent']
```
## add_active(robot_name) {: #method-i-add_active }
Adds a robot as an active member of the group.

Active robots can add memories and respond to queries. The new robot is
automatically synchronized with existing shared working memory.

**`@param`** [String] Unique name for the robot

**`@raise`** [ArgumentError] if robot_name is already a member

**`@return`** [Integer] The robot's database ID


**`@example`**
```ruby
robot_id = group.add_active('new-agent')
puts "Added robot with ID: #{robot_id}"
```
## add_passive(robot_name) {: #method-i-add_passive }
Adds a robot as a passive (standby) member of the group.

Passive robots maintain synchronized working memory but don't actively
participate in conversations. They serve as warm standbys for failover.

**`@param`** [String] Unique name for the robot

**`@raise`** [ArgumentError] if robot_name is already a member

**`@return`** [Integer] The robot's database ID


**`@example`**
```ruby
robot_id = group.add_passive('standby-agent')
```
## clear_working_memory() {: #method-i-clear_working_memory }
Clears shared working memory for all group members.

Updates database flags and notifies all members to clear their in-memory
caches.

**`@return`** [Integer] Number of robot_node records updated


**`@example`**
```ruby
cleared_count = group.clear_working_memory
puts "Cleared #{cleared_count} working memory entries"
```
## demote(robot_name) {: #method-i-demote }
Demotes an active robot to passive status.

The robot retains its working memory but stops handling queries. Cannot demote
the last active robot.

**`@param`** [String] Name of the active robot to demote

**`@raise`** [ArgumentError] if robot_name is not an active member

**`@raise`** [ArgumentError] if this is the last active robot

**`@return`** [void] 


**`@example`**
```ruby
group.demote('primary-agent')
group.passive?('primary-agent')  # => true
```
## failover!() {: #method-i-failover! }
Performs automatic failover to the first passive robot.

Promotes the first passive robot to active status. The promoted robot already
has synchronized working memory and can immediately handle requests.

**`@raise`** [RuntimeError] if no passive robots are available

**`@return`** [String] Name of the promoted robot


**`@example`**
```ruby
promoted = group.failover!
puts "#{promoted} is now active"
```
## in_sync?() {: #method-i-in_sync? }
Checks if all members have identical working memory.

Compares the set of working memory node IDs across all members.

**`@return`** [Boolean] true if all members have the same working memory nodes


**`@example`**
```ruby
if group.in_sync?
  puts "All robots synchronized"
else
  group.sync_all
end
```
## initialize(name:, active:[], passive:[], max_tokens:4000, db_config:nil) {: #method-i-initialize }
Creates a new robot group with optional initial members.

Initializes the group, sets up the PostgreSQL pub/sub channel for real-time
synchronization, and registers initial active and passive robots.

**`@param`** [String] Unique name for this robot group

**`@param`** [Array<String>] Names of robots to add as active members

**`@param`** [Array<String>] Names of robots to add as passive (standby) members

**`@param`** [Integer] Maximum token budget for shared working memory

**`@param`** [Hash, nil] PostgreSQL connection config (defaults to HTM::Database.default_config)

**`@return`** [RobotGroup] a new instance of RobotGroup


**`@example`**
```ruby
group = HTM::RobotGroup.new(
  name: 'support-team',
  active: ['agent-1'],
  passive: ['agent-2'],
  max_tokens: 4000
)
```
**`@example`**
```ruby
group = HTM::RobotGroup.new(name: 'dynamic-team')
group.add_active('agent-1')
group.add_passive('agent-2')
```
## member?(robot_name) {: #method-i-member? }
Checks if a robot is a member of this group.

**`@param`** [String] Name of the robot to check

**`@return`** [Boolean] true if the robot is an active or passive member


**`@example`**
```ruby
group.member?('agent-1')  # => true
group.member?('unknown')  # => false
```
## member_ids() {: #method-i-member_ids }
Returns database IDs of all group members.

**`@return`** [Array<Integer>] Array of robot IDs (both active and passive)


**`@example`**
```ruby
group.member_ids  # => [1, 2, 3]
```
## passive?(robot_name) {: #method-i-passive? }
Checks if a robot is a passive member of this group.

**`@param`** [String] Name of the robot to check

**`@return`** [Boolean] true if the robot is a passive member


**`@example`**
```ruby
group.passive?('standby-agent')  # => true
```
## passive_robot_names() {: #method-i-passive_robot_names }
Returns names of all passive robots.

**`@return`** [Array<String>] Array of passive robot names


**`@example`**
```ruby
group.passive_robot_names  # => ['standby-agent']
```
## promote(robot_name) {: #method-i-promote }
Promotes a passive robot to active status.

The robot retains its synchronized working memory and becomes eligible to
handle queries and add memories.

**`@param`** [String] Name of the passive robot to promote

**`@raise`** [ArgumentError] if robot_name is not a passive member

**`@return`** [void] 


**`@example`**
```ruby
group.promote('standby-agent')
group.active?('standby-agent')  # => true
```
## recall(query, **options) {: #method-i-recall }
Recalls memories from shared working memory.

Uses the first active robot to perform the query against the shared working
memory context.

**`@option`** [] 

**`@option`** [] 

**`@param`** [String] The search query

**`@param`** [Hash] Additional options passed to HTM#recall

**`@raise`** [RuntimeError] if no active robots exist in the group

**`@return`** [Array] Array of matching memories


**`@example`**
```ruby
results = group.recall('billing issue', limit: 5, strategy: :fulltext)
```
## remember(content, originator:nil, **options) {: #method-i-remember }
Adds content to shared working memory for all group members.

The memory is created by the specified originator (or first active robot) and
automatically synchronized to all other members via database and real-time
notifications.

**`@param`** [String] The content to remember

**`@param`** [String, nil] Name of the robot creating the memory (optional)

**`@param`** [Hash] Additional options passed to HTM#remember

**`@raise`** [RuntimeError] if no active robots exist in the group

**`@return`** [Integer] The node ID of the created memory


**`@example`**
```ruby
node_id = group.remember('Customer prefers morning appointments.')
```
**`@example`**
```ruby
node_id = group.remember(
  'Escalated to billing department.',
  originator: 'agent-2'
)
```
## remove(robot_name) {: #method-i-remove }
Removes a robot from the group.

Clears the robot's working memory flags in the database. The robot can be
either active or passive.

**`@param`** [String] Name of the robot to remove

**`@return`** [void] 


**`@example`**
```ruby
group.remove('departing-agent')
```
## shutdown() {: #method-i-shutdown }
Shuts down the group by stopping the listener thread.

Should be called when the group is no longer needed to release resources and
close the PostgreSQL listener connection.

**`@return`** [void] 


**`@example`**
```ruby
group.shutdown
```
## status() {: #method-i-status }
Returns comprehensive status information about the group.

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@param`** [Hash] a customizable set of options

**`@return`** [Hash] Status hash with the following keys:


**`@example`**
```ruby
status = group.status
puts "Group: #{status[:name]}"
puts "Active: #{status[:active].join(', ')}"
puts "Utilization: #{(status[:token_utilization] * 100).round(1)}%"
```
## sync_all() {: #method-i-sync_all }
Synchronizes all members to a consistent state.

Ensures every member has access to all shared working memory nodes.

**`@return`** [Hash] Sync results with :synced_nodes and :members_updated counts


**`@example`**
```ruby
result = group.sync_all
puts "Synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"
```
## sync_robot(robot_name) {: #method-i-sync_robot }
Synchronizes a specific robot to match the group's shared working memory.

Copies working memory flags from other members to the specified robot,
ensuring it has access to all shared context.

**`@param`** [String] Name of the robot to synchronize

**`@raise`** [ArgumentError] if robot_name is not a member

**`@return`** [Integer] Number of nodes synchronized


**`@example`**
```ruby
synced = group.sync_robot('new-agent')
puts "Synchronized #{synced} nodes"
```
## sync_stats() {: #method-i-sync_stats }
Returns statistics about real-time synchronization.

**`@return`** [Hash] Stats hash with :nodes_synced and :evictions_synced counts


**`@example`**
```ruby
stats = group.sync_stats
puts "Nodes synced: #{stats[:nodes_synced]}"
puts "Evictions synced: #{stats[:evictions_synced]}"
```
## transfer_working_memory(from_robot, to_robot, clear_source:true) {: #method-i-transfer_working_memory }
Transfers working memory from one robot to another.

Copies all working memory node references from the source robot to the target
robot, optionally clearing the source.

**`@param`** [String] Name of the source robot

**`@param`** [String] Name of the destination robot

**`@param`** [Boolean] Whether to clear source's working memory after transfer

**`@raise`** [ArgumentError] if either robot is not a member

**`@return`** [Integer] Number of nodes transferred


**`@example`**
```ruby
transferred = group.transfer_working_memory('failing-agent', 'backup-agent')
```
**`@example`**
```ruby
transferred = group.transfer_working_memory(
  'agent-1', 'agent-2',
  clear_source: false
)
```
## working_memory_contents() {: #method-i-working_memory_contents }
Returns all nodes currently in shared working memory.

Queries the database for the union of all members' working memory, returning
nodes sorted by creation date (newest first).

**`@return`** [ActiveRecord::Relation<HTM::Models::Node>] Collection of nodes


**`@example`**
```ruby
nodes = group.working_memory_contents
nodes.each { |n| puts n.content }
```