# Class HTM::WorkingMemoryChannel <a id="class-HTM-WorkingMemoryChannel"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/working_memory_channel.rb |

Provides real-time synchronization of working memory changes across multiple
robots using PostgreSQL LISTEN/NOTIFY pub/sub mechanism.

This class enables distributed robots to maintain synchronized working memory
by broadcasting change notifications through PostgreSQL channels. When one
robot adds, evicts, or clears working memory, all other robots in the group
receive immediate notification.

- **`@see`** `HTM::RobotGroup` Higher-level coordination using this channel

**@example Basic usage**
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

## Constants
### `CHANNEL_PREFIX` <a id="constant-CHANNEL_PREFIX"></a> <a id="CHANNEL_PREFIX-constant"></a>
Prefix used for all PostgreSQL channel names
- **`@return`** [String]

## Attributes
### `notifications_received` [R] <a id="attribute-i-notifications_received"></a> <a id="notifications_received-instance_method"></a>
Number of notifications received since channel was created
- **`@return`** [Integer]

## Public Instance Methods
### Publishing
#### `notify(event, node_id:, robot_id:)` <a id="method-i-notify"></a> <a id="notify-instance_method"></a>
Broadcasts a working memory change notification to all listeners.

Uses PostgreSQL's pg_notify function to send a JSON payload containing the
event type, affected node ID, originating robot ID, and timestamp.
- **`@param`** `event` [Symbol] Type of change (:added, :evicted, or :cleared)
- **`@param`** `node_id` [Integer, nil] ID of the affected node (nil for :cleared events)
- **`@param`** `robot_id` [Integer] ID of the robot that triggered the change
- **`@return`** [void]

**@example Notify that a node was added**
```ruby
channel.notify(:added, node_id: 123, robot_id: 1)
```

**@example Notify that working memory was cleared**
```ruby
channel.notify(:cleared, node_id: nil, robot_id: 1)
```
### Subscribing
#### `on_change(&callback)` <a id="method-i-on_change"></a> <a id="on_change-instance_method"></a>
Registers a callback to be invoked when working memory changes occur.

Multiple callbacks can be registered; all will be called for each event.
Callbacks are invoked synchronously within the listener thread.
- **`@return`** [void]
- **`@yield`** [event, node_id, robot_id] Block called for each notification
- **`@yieldparam`** `event` [Symbol] Type of change (:added, :evicted, or :cleared)
- **`@yieldparam`** `node_id` [Integer, nil] ID of the affected node
- **`@yieldparam`** `robot_id` [Integer] ID of the robot that triggered the change

**@example Register a change handler**
```ruby
channel.on_change do |event, node_id, robot_id|
  puts "Received #{event} event for node #{node_id}"
end
```

#### `start_listening()` <a id="method-i-start_listening"></a> <a id="start_listening-instance_method"></a>
Starts listening for notifications in a background thread.

Creates a dedicated PostgreSQL connection that uses LISTEN to receive
notifications. The thread polls every 0.5 seconds, allowing for clean shutdown
via {#stop_listening}.
- **`@return`** [Thread] The background listener thread

**@example Start and verify listening**
```ruby
thread = channel.start_listening
puts "Listening: #{channel.listening?}"  # => true
```

#### `stop_listening()` <a id="method-i-stop_listening"></a> <a id="stop_listening-instance_method"></a>
Stops the background listener thread.

Signals the listener to stop, waits up to 0.5 seconds for clean exit, then
forcefully terminates if still running. The PostgreSQL connection is closed
automatically.
- **`@return`** [void]

**@example Clean shutdown**
```ruby
channel.stop_listening
puts "Listening: #{channel.listening?}"  # => false
```
### Status
#### `channel_name()` <a id="method-i-channel_name"></a> <a id="channel_name-instance_method"></a>
Returns the PostgreSQL channel name used for notifications.

The channel name is derived from the group name with a prefix and sanitization
of special characters.
- **`@return`** [String] The PostgreSQL LISTEN/NOTIFY channel name

**`@example`**
```ruby
channel = HTM::WorkingMemoryChannel.new('my-group', db_config)
channel.channel_name  # => "htm_wm_my_group"
```

#### `listening?()` <a id="method-i-listening-3F"></a> <a id="listening?-instance_method"></a>
Checks if the listener thread is currently active.
- **`@return`** [Boolean] true if listening for notifications, false otherwise

**`@example`**
```ruby
channel.start_listening
channel.listening?  # => true
channel.stop_listening
channel.listening?  # => false
```
### General
#### `initialize(group_name, db_config)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Creates a new working memory channel for a robot group.

The channel name is derived from the group name with non-alphanumeric
characters replaced by underscores to ensure PostgreSQL compatibility.
- **`@option`** `db_config[:host]` [String] Database host
- **`@option`** `db_config[:port]` [Integer] Database port
- **`@option`** `db_config[:dbname]` [String] Database name
- **`@option`** `db_config[:user]` [String] Database user
- **`@option`** `db_config[:password]` [String] Database password (optional)
- **`@param`** `group_name` [String] Name of the robot group (used to create unique channel)
- **`@param`** `db_config` [Hash] PostgreSQL connection configuration hash
- **`@return`** [WorkingMemoryChannel] a new instance of WorkingMemoryChannel

**`@example`**
```ruby
db_config = { host: 'localhost', port: 5432, dbname: 'htm_dev', user: 'postgres' }
channel = HTM::WorkingMemoryChannel.new('customer-support', db_config)
```
