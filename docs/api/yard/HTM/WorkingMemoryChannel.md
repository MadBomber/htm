# Class: HTM::WorkingMemoryChannel
**Inherits:** Object
    

Provides real-time synchronization of working memory changes across multiple
robots using PostgreSQL LISTEN/NOTIFY pub/sub mechanism.

This class enables distributed robots to maintain synchronized working memory
by broadcasting change notifications through PostgreSQL channels. When one
robot adds, evicts, or clears working memory, all other robots in the group
receive immediate notification.

**`@see`** [] Higher-level coordination using this channel


**`@example`**
```ruby
channel = HTM::WorkingMemoryChannel.new('support-team', db_config)

# Subscribe to changes
channel.on_change do |event, node_id, robot_id|
  case event
  when :added   then puts "Node #{node_id} added by robot #{robot_id}"
  when :evicted then puts "Node #{node_id} evicted by robot #{robot_id}"
  when :cleared then puts "Working memory cleared by robot #{robot_id}"
  end
end

# Start listening in background thread
channel.start_listening

# Publish a change
channel.notify(:added, node_id: 123, robot_id: 456)

# Cleanup when done
channel.stop_listening
```
# Attributes
## notifications_received[RW] {: #attribute-i-notifications_received }
Number of notifications received since channel was created

**`@return`** [Integer] 


# Instance Methods
## channel_name() {: #method-i-channel_name }
Returns the PostgreSQL channel name used for notifications.

The channel name is derived from the group name with a prefix and sanitization
of special characters.

**`@return`** [String] The PostgreSQL LISTEN/NOTIFY channel name


**`@example`**
```ruby
channel = HTM::WorkingMemoryChannel.new('my-group', db_config)
channel.channel_name  # => "htm_wm_my_group"
```
## initialize(group_name, db_config) {: #method-i-initialize }
Creates a new working memory channel for a robot group.

The channel name is derived from the group name with non-alphanumeric
characters replaced by underscores to ensure PostgreSQL compatibility.

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@option`** [] 

**`@param`** [String] Name of the robot group (used to create unique channel)

**`@param`** [Hash] PostgreSQL connection configuration hash

**`@return`** [WorkingMemoryChannel] a new instance of WorkingMemoryChannel


**`@example`**
```ruby
db_config = { host: 'localhost', port: 5432, dbname: 'htm_dev', user: 'postgres' }
channel = HTM::WorkingMemoryChannel.new('customer-support', db_config)
```
## listening?() {: #method-i-listening? }
Checks if the listener thread is currently active.

**`@return`** [Boolean] true if listening for notifications, false otherwise


**`@example`**
```ruby
channel.start_listening
channel.listening?  # => true
channel.stop_listening
channel.listening?  # => false
```
## notify(event, node_id:, robot_id:) {: #method-i-notify }
Broadcasts a working memory change notification to all listeners.

Uses PostgreSQL's pg_notify function to send a JSON payload containing the
event type, affected node ID, originating robot ID, and timestamp.

**`@param`** [Symbol] Type of change (:added, :evicted, or :cleared)

**`@param`** [Integer, nil] ID of the affected node (nil for :cleared events)

**`@param`** [Integer] ID of the robot that triggered the change

**`@return`** [void] 


**`@example`**
```ruby
channel.notify(:added, node_id: 123, robot_id: 1)
```
**`@example`**
```ruby
channel.notify(:cleared, node_id: nil, robot_id: 1)
```
## on_change(&callback) {: #method-i-on_change }
Registers a callback to be invoked when working memory changes occur.

Multiple callbacks can be registered; all will be called for each event.
Callbacks are invoked synchronously within the listener thread.

**`@return`** [void] 

**`@yield`** [event, node_id, robot_id] Block called for each notification

**`@yieldparam`** [Symbol] Type of change (:added, :evicted, or :cleared)

**`@yieldparam`** [Integer, nil] ID of the affected node

**`@yieldparam`** [Integer] ID of the robot that triggered the change


**`@example`**
```ruby
channel.on_change do |event, node_id, robot_id|
  puts "Received #{event} event for node #{node_id}"
end
```
## start_listening() {: #method-i-start_listening }
Starts listening for notifications in a background thread.

Creates a dedicated PostgreSQL connection that uses LISTEN to receive
notifications. The thread polls every 0.5 seconds, allowing for clean shutdown
via {#stop_listening}.

**`@return`** [Thread] The background listener thread


**`@example`**
```ruby
thread = channel.start_listening
puts "Listening: #{channel.listening?}"  # => true
```
## stop_listening() {: #method-i-stop_listening }
Stops the background listener thread.

Signals the listener to stop, waits up to 0.5 seconds for clean exit, then
forcefully terminates if still running. The PostgreSQL connection is closed
automatically.

**`@return`** [void] 


**`@example`**
```ruby
channel.stop_listening
puts "Listening: #{channel.listening?}"  # => false
```