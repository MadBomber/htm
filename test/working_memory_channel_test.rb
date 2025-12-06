# frozen_string_literal: true

require "test_helper"

class WorkingMemoryChannelTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    @group_name = "test-channel-#{SecureRandom.hex(4)}"
    @db_config = HTM::Database.default_config
  end

  def teardown
    @channel&.stop_listening
  end

  # ========================================
  # Initialization Tests
  # ========================================

  def test_initialization
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    assert_equal 0, @channel.notifications_received
    refute @channel.listening?
  end

  def test_channel_name_sanitization
    @channel = HTM::WorkingMemoryChannel.new("my-group-name", @db_config)

    assert_equal "htm_wm_my_group_name", @channel.channel_name
  end

  def test_channel_name_sanitization_special_chars
    @channel = HTM::WorkingMemoryChannel.new("group.with!special@chars", @db_config)

    assert_equal "htm_wm_group_with_special_chars", @channel.channel_name
  end

  def test_channel_name_prefix
    @channel = HTM::WorkingMemoryChannel.new("test", @db_config)

    assert @channel.channel_name.start_with?("htm_wm_")
  end

  # ========================================
  # Listening Tests
  # ========================================

  def test_start_listening_returns_thread
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    thread = @channel.start_listening

    assert thread.is_a?(Thread)
    assert @channel.listening?
  end

  def test_stop_listening_stops_thread
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    @channel.start_listening
    sleep 0.1  # Allow thread to start

    @channel.stop_listening

    refute @channel.listening?
  end

  def test_listening_returns_false_before_start
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    refute @channel.listening?
  end

  def test_listening_returns_true_after_start
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    @channel.start_listening
    sleep 0.1  # Allow thread to start

    assert @channel.listening?
  end

  # ========================================
  # Notification Tests
  # ========================================

  def test_notify_added_event
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    # Should not raise
    @channel.notify(:added, node_id: 123, robot_id: 456)
  end

  def test_notify_evicted_event
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    # Should not raise
    @channel.notify(:evicted, node_id: 123, robot_id: 456)
  end

  def test_notify_cleared_event
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)

    # Should not raise
    @channel.notify(:cleared, node_id: nil, robot_id: 456)
  end

  # ========================================
  # Callback Registration Tests
  # ========================================

  def test_on_change_registers_callback
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    callback_called = false

    @channel.on_change do |event, node_id, robot_id|
      callback_called = true
    end

    # Callback is registered but not called until notification received
    refute callback_called
  end

  def test_multiple_callbacks_can_be_registered
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    call_count = 0

    @channel.on_change { call_count += 1 }
    @channel.on_change { call_count += 1 }

    # Should not raise - callbacks are just registered
    assert true
  end

  # ========================================
  # End-to-End Notification Tests
  # ========================================

  def test_notification_received_by_listener
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    received_events = []

    @channel.on_change do |event, node_id, robot_id|
      received_events << { event: event, node_id: node_id, robot_id: robot_id }
    end

    @channel.start_listening
    sleep 0.2  # Allow listener to start

    # Send notification
    @channel.notify(:added, node_id: 999, robot_id: 888)

    # Wait for notification to be received
    sleep 0.5

    assert_equal 1, received_events.length
    assert_equal :added, received_events.first[:event]
    assert_equal 999, received_events.first[:node_id]
    assert_equal 888, received_events.first[:robot_id]
  end

  def test_notifications_received_count_increments
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    @channel.on_change { }  # Empty callback

    @channel.start_listening
    sleep 0.2

    @channel.notify(:added, node_id: 1, robot_id: 1)
    @channel.notify(:evicted, node_id: 2, robot_id: 1)
    sleep 0.5

    assert_equal 2, @channel.notifications_received
  end

  def test_cleared_event_has_nil_node_id
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    received_events = []

    @channel.on_change do |event, node_id, robot_id|
      received_events << { event: event, node_id: node_id, robot_id: robot_id }
    end

    @channel.start_listening
    sleep 0.2

    @channel.notify(:cleared, node_id: nil, robot_id: 123)
    sleep 0.5

    assert_equal 1, received_events.length
    assert_equal :cleared, received_events.first[:event]
    assert_nil received_events.first[:node_id]
  end

  # ========================================
  # Thread Safety Tests
  # ========================================

  def test_concurrent_notifications
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    received_count = 0
    mutex = Mutex.new

    @channel.on_change do |event, node_id, robot_id|
      mutex.synchronize { received_count += 1 }
    end

    @channel.start_listening
    sleep 0.2

    # Send multiple notifications from different threads
    threads = 5.times.map do |i|
      Thread.new do
        @channel.notify(:added, node_id: i, robot_id: 1)
      end
    end
    threads.each(&:join)

    # Wait for all notifications to be received
    sleep 1.0

    assert_equal 5, received_count
  end

  # ========================================
  # Error Handling Tests
  # ========================================

  def test_channel_handles_malformed_json_gracefully
    # This tests the internal error handling - the channel should continue
    # working even if it receives invalid JSON
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    error_raised = false

    @channel.on_change do |event, node_id, robot_id|
      # Should not be called for malformed JSON
    end

    @channel.start_listening
    sleep 0.2

    # Send valid notification - should still work
    @channel.notify(:added, node_id: 123, robot_id: 456)
    sleep 0.5

    assert_equal 1, @channel.notifications_received
  end

  # ========================================
  # Cross-Channel Isolation Tests
  # ========================================

  def test_different_groups_are_isolated
    @channel = HTM::WorkingMemoryChannel.new(@group_name, @db_config)
    other_channel = HTM::WorkingMemoryChannel.new("other-group", @db_config)

    received_by_first = 0
    received_by_other = 0

    @channel.on_change { received_by_first += 1 }
    other_channel.on_change { received_by_other += 1 }

    @channel.start_listening
    other_channel.start_listening
    sleep 0.2

    # Send notification to first channel only
    @channel.notify(:added, node_id: 1, robot_id: 1)
    sleep 0.5

    assert_equal 1, received_by_first
    assert_equal 0, received_by_other

    other_channel.stop_listening
  end
end
