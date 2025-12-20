# frozen_string_literal: true

require_relative 'test_helper'

class JobAdapterTest < Minitest::Test
  def setup
    @original_backend = HTM.configuration.job_backend
    @job_executed = false
    @job_params = nil

    # Create a test job class
    @test_job_class = Class.new do
      def self.perform(test_param:)
        # Job execution logic (will be stubbed in tests)
      end

      def self.name
        "TestJob"
      end
    end
  end

  def teardown
    # Restore original configuration
    HTM.configuration.job.backend = @original_backend
  end

  # Test inline backend
  def test_inline_backend_executes_synchronously
    HTM.configuration.job.backend = :inline

    # Track job execution
    executed = false
    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        executed = true
      end

      define_singleton_method(:name) { "InlineTestJob" }
    end

    HTM::JobAdapter.enqueue(job_class, test_param: 'value')

    # Job should execute immediately in inline mode
    assert executed, "Job should execute synchronously in inline mode"
  end

  # Test thread backend
  def test_thread_backend_executes_asynchronously
    HTM.configuration.job.backend = :thread

    # Track job execution
    executed = false
    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        executed = true
      end

      define_singleton_method(:name) { "ThreadTestJob" }
    end

    HTM::JobAdapter.enqueue(job_class, test_param: 'value')

    # Give thread time to execute
    sleep 0.1

    assert executed, "Job should execute in background thread"
  end

  # Test unknown backend raises error
  def test_unknown_backend_raises_error
    HTM.configuration.job.backend = :unknown

    error = assert_raises(HTM::Error) do
      HTM::JobAdapter.enqueue(@test_job_class, test_param: 'value')
    end

    assert_match(/Unknown job backend/, error.message)
  end

  # Test configuration validation
  def test_configuration_validates_job_backend
    config = HTM::Config.new
    config.job.backend = :invalid_backend

    error = assert_raises(Anyway::Config::ValidationError) do
      config.validate_settings!
    end

    assert_match(/job\.backend must be one of/, error.message)
  end

  # Test auto-detection in test environment
  def test_auto_detect_inline_in_test_env
    # Save current environment values
    saved_htm_env = ENV['HTM_ENV']
    saved_rails_env = ENV['RAILS_ENV']
    saved_rack_env = ENV['RACK_ENV']

    # Clear HTM_ENV to test RACK_ENV detection
    # (HTM_ENV takes priority: HTM_ENV > RAILS_ENV > RACK_ENV)
    ENV.delete('HTM_ENV')
    ENV.delete('RAILS_ENV')
    ENV['RACK_ENV'] = 'test'

    config = HTM::Config.new
    assert_equal :inline, config.job_backend
  ensure
    # Restore original environment values
    saved_htm_env ? ENV['HTM_ENV'] = saved_htm_env : ENV.delete('HTM_ENV')
    saved_rails_env ? ENV['RAILS_ENV'] = saved_rails_env : ENV.delete('RAILS_ENV')
    saved_rack_env ? ENV['RACK_ENV'] = saved_rack_env : ENV.delete('RACK_ENV')
  end

  # Test auto-detection with environment variable
  def test_auto_detect_with_env_variable
    ENV['HTM_JOB_BACKEND'] = 'inline'
    config = HTM::Config.new
    assert_equal :inline, config.job_backend
  ensure
    ENV.delete('HTM_JOB_BACKEND')
  end

  # Test job parameters are passed correctly
  def test_job_parameters_passed_correctly
    HTM.configuration.job.backend = :inline

    received_params = nil
    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        received_params = params
      end

      define_singleton_method(:name) { "ParamsTestJob" }
    end

    HTM::JobAdapter.enqueue(job_class, node_id: 123, category: 'test')

    assert_equal 123, received_params[:node_id]
    assert_equal 'test', received_params[:category]
  end

  # Test error handling in inline mode
  def test_error_handling_in_inline_mode
    HTM.configuration.job.backend = :inline

    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        raise StandardError, "Test error"
      end

      define_singleton_method(:name) { "ErrorTestJob" }
    end

    # Should not raise (errors are logged)
    assert_silent do
      HTM::JobAdapter.enqueue(job_class, test_param: 'value')
    end
  end

  # Test error handling in thread mode
  def test_error_handling_in_thread_mode
    HTM.configuration.job.backend = :thread

    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        raise StandardError, "Test error in thread"
      end

      define_singleton_method(:name) { "ThreadErrorTestJob" }
    end

    # Should not raise (errors are logged)
    assert_silent do
      HTM::JobAdapter.enqueue(job_class, test_param: 'value')
      sleep 0.1 # Give thread time to execute and fail
    end
  end
end
