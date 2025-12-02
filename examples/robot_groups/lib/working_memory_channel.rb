# robot_groups/lib/working_memory_channel.rb
# frozen_string_literal: true
#
# PostgreSQL LISTEN/NOTIFY for real-time sync
#

class WorkingMemoryChannel
  CHANNEL_PREFIX = 'htm_wm'

  attr_reader :notifications_received

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

  # ===========================================================================
  # Publishing (called by the robot that adds/evicts memory)
  # ===========================================================================

  # Notify all group members of a working memory change
  #
  # @param event [Symbol] :added, :evicted, :cleared
  # @param node_id [Integer, nil] Node ID (nil for :cleared)
  # @param robot_id [Integer] Robot that triggered the change
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

  # ===========================================================================
  # Subscribing (called by robots to receive updates)
  # ===========================================================================

  # Register a callback for working memory events
  #
  # @param callback [Proc] Called with (event, node_id, robot_id)
  #
  def on_change(&callback)
    @mutex.synchronize { @listeners << callback }
  end


  # Start listening for notifications in a background thread
  #
  # @return [Thread] The listener thread
  #
  def start_listening
    @stop_requested = false
    @listen_thread  = Thread.new do
      listen_loop
    end
    @listen_thread.abort_on_exception = true
    @listen_thread
  end


  # Stop the listener thread
  #
  def stop_listening
    @stop_requested = true
    # Give the thread a moment to exit cleanly
    @listen_thread&.join(0.5)
    @listen_thread&.kill if @listen_thread&.alive?
    @listen_thread = nil
  end


  def listening?
    @listen_thread&.alive? || false
  end


  def channel_name
    @channel
  end

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
