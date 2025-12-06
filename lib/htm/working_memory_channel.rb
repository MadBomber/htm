# examples/robot_groups/lib/htm/working_memory_channel.rb
# frozen_string_literal: true

class HTM
  # Provides real-time synchronization of working memory changes across multiple
  # robots using PostgreSQL LISTEN/NOTIFY pub/sub mechanism.
  #
  # This class enables distributed robots to maintain synchronized working memory
  # by broadcasting change notifications through PostgreSQL channels. When one robot
  # adds, evicts, or clears working memory, all other robots in the group receive
  # immediate notification.
  #
  # @example Basic usage
  #   channel = HTM::WorkingMemoryChannel.new('support-team', db_config)
  #
  #   # Subscribe to changes
  #   channel.on_change do |event, node_id, robot_id|
  #     case event
  #     when :added   then puts "Node #{node_id} added by robot #{robot_id}"
  #     when :evicted then puts "Node #{node_id} evicted by robot #{robot_id}"
  #     when :cleared then puts "Working memory cleared by robot #{robot_id}"
  #     end
  #   end
  #
  #   # Start listening in background thread
  #   channel.start_listening
  #
  #   # Publish a change
  #   channel.notify(:added, node_id: 123, robot_id: 456)
  #
  #   # Cleanup when done
  #   channel.stop_listening
  #
  # @see HTM::RobotGroup Higher-level coordination using this channel
  #
  class WorkingMemoryChannel
    # Prefix used for all PostgreSQL channel names
    # @return [String]
    CHANNEL_PREFIX = 'htm_wm'

    # Number of notifications received since channel was created
    # @return [Integer]
    attr_reader :notifications_received

    # Creates a new working memory channel for a robot group.
    #
    # The channel name is derived from the group name with non-alphanumeric
    # characters replaced by underscores to ensure PostgreSQL compatibility.
    #
    # @param group_name [String] Name of the robot group (used to create unique channel)
    # @param db_config [Hash] PostgreSQL connection configuration hash
    # @option db_config [String] :host Database host
    # @option db_config [Integer] :port Database port
    # @option db_config [String] :dbname Database name
    # @option db_config [String] :user Database user
    # @option db_config [String] :password Database password (optional)
    #
    # @example
    #   db_config = { host: 'localhost', port: 5432, dbname: 'htm_dev', user: 'postgres' }
    #   channel = HTM::WorkingMemoryChannel.new('customer-support', db_config)
    #
    def initialize(group_name, db_config)
      @group_name             = group_name
      @channel                = "#{CHANNEL_PREFIX}_#{group_name.gsub(/[^a-z0-9_]/i, '_')}"
      @db_config              = db_config
      @listeners              = []
      @listen_thread          = nil
      @stop_requested         = false
      @notifications_received = 0
      @mutex                  = Mutex.new
    end

    # @!group Publishing

    # Broadcasts a working memory change notification to all listeners.
    #
    # Uses PostgreSQL's pg_notify function to send a JSON payload containing
    # the event type, affected node ID, originating robot ID, and timestamp.
    #
    # @param event [Symbol] Type of change (:added, :evicted, or :cleared)
    # @param node_id [Integer, nil] ID of the affected node (nil for :cleared events)
    # @param robot_id [Integer] ID of the robot that triggered the change
    # @return [void]
    #
    # @example Notify that a node was added
    #   channel.notify(:added, node_id: 123, robot_id: 1)
    #
    # @example Notify that working memory was cleared
    #   channel.notify(:cleared, node_id: nil, robot_id: 1)
    #
    def notify(event, node_id:, robot_id:)
      payload = {
        event: event,
        node_id: node_id,
        robot_id: robot_id,
        timestamp: Time.now.iso8601
      }.to_json

      with_connection do |conn|
        conn.exec_params('SELECT pg_notify($1, $2)', [@channel, payload])
      end
    end

    # @!endgroup

    # @!group Subscribing

    # Registers a callback to be invoked when working memory changes occur.
    #
    # Multiple callbacks can be registered; all will be called for each event.
    # Callbacks are invoked synchronously within the listener thread.
    #
    # @yield [event, node_id, robot_id] Block called for each notification
    # @yieldparam event [Symbol] Type of change (:added, :evicted, or :cleared)
    # @yieldparam node_id [Integer, nil] ID of the affected node
    # @yieldparam robot_id [Integer] ID of the robot that triggered the change
    # @return [void]
    #
    # @example Register a change handler
    #   channel.on_change do |event, node_id, robot_id|
    #     puts "Received #{event} event for node #{node_id}"
    #   end
    #
    def on_change(&callback)
      @mutex.synchronize { @listeners << callback }
    end

    # Starts listening for notifications in a background thread.
    #
    # Creates a dedicated PostgreSQL connection that uses LISTEN to receive
    # notifications. The thread polls every 0.5 seconds, allowing for clean
    # shutdown via {#stop_listening}.
    #
    # @return [Thread] The background listener thread
    #
    # @example Start and verify listening
    #   thread = channel.start_listening
    #   puts "Listening: #{channel.listening?}"  # => true
    #
    def start_listening
      @stop_requested = false
      @listen_thread  = Thread.new do
        listen_loop
      end
      @listen_thread.abort_on_exception = true
      @listen_thread
    end

    # Stops the background listener thread.
    #
    # Signals the listener to stop, waits up to 0.5 seconds for clean exit,
    # then forcefully terminates if still running. The PostgreSQL connection
    # is closed automatically.
    #
    # @return [void]
    #
    # @example Clean shutdown
    #   channel.stop_listening
    #   puts "Listening: #{channel.listening?}"  # => false
    #
    def stop_listening
      @stop_requested = true
      # Give the thread a moment to exit cleanly
      @listen_thread&.join(0.5)
      @listen_thread&.kill if @listen_thread&.alive?
      @listen_thread = nil
    end

    # @!endgroup

    # @!group Status

    # Checks if the listener thread is currently active.
    #
    # @return [Boolean] true if listening for notifications, false otherwise
    #
    # @example
    #   channel.start_listening
    #   channel.listening?  # => true
    #   channel.stop_listening
    #   channel.listening?  # => false
    #
    def listening?
      @listen_thread&.alive? || false
    end

    # Returns the PostgreSQL channel name used for notifications.
    #
    # The channel name is derived from the group name with a prefix and
    # sanitization of special characters.
    #
    # @return [String] The PostgreSQL LISTEN/NOTIFY channel name
    #
    # @example
    #   channel = HTM::WorkingMemoryChannel.new('my-group', db_config)
    #   channel.channel_name  # => "htm_wm_my_group"
    #
    def channel_name
      @channel
    end

    # @!endgroup

    private

    def listen_loop
      conn = PG.connect(@db_config)
      conn.exec("LISTEN #{conn.escape_identifier(@channel)}")

      until @stop_requested
        # Wait for notification with timeout (allows checking @stop_requested)
        conn.wait_for_notify(0.5) do |_channel, _pid, payload|
          handle_notification(payload)
        end
      end
    rescue PG::Error => e
      unless @stop_requested
        HTM.logger.error "WorkingMemoryChannel error: #{e.message}"
        sleep 1
        retry
      end
    ensure
      conn&.close
    end

    def handle_notification(payload)
      data = JSON.parse(payload, symbolize_names: true)

      @mutex.synchronize do
        @notifications_received += 1
        @listeners.each do |callback|
          callback.call(
            data[:event].to_sym,
            data[:node_id],
            data[:robot_id]
          )
        end
      end
    rescue JSON::ParserError => e
      HTM.logger.error "Invalid notification payload: #{e.message}"
    end

    def with_connection
      conn = PG.connect(@db_config)
      yield conn
    ensure
      conn&.close
    end
  end
end
