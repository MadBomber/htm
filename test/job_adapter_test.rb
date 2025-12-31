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
    # Nested config uses double-underscore: HTM_JOB__BACKEND
    ENV['HTM_JOB__BACKEND'] = 'inline'
    config = HTM::Config.new
    assert_equal :inline, config.job_backend
  ensure
    ENV.delete('HTM_JOB__BACKEND')
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

  # Test fiber backend executes job
  def test_fiber_backend_executes_job
    HTM.configuration.job.backend = :fiber

    executed = false
    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        executed = true
      end

      define_singleton_method(:name) { "FiberTestJob" }
    end

    HTM::JobAdapter.enqueue(job_class, test_param: 'value')

    # Fiber backend should execute the job
    assert executed, "Job should execute in fiber mode"
  end

  # Test parallel execution with fiber backend
  def test_enqueue_parallel_with_fiber_backend
    HTM.configuration.job.backend = :fiber

    results = []
    mutex = Mutex.new

    job_class_a = Class.new do
      define_singleton_method(:perform) do |value:|
        sleep 0.05 # Simulate I/O
        mutex.synchronize { results << "a:#{value}" }
      end
      define_singleton_method(:name) { "JobA" }
    end

    job_class_b = Class.new do
      define_singleton_method(:perform) do |value:|
        sleep 0.05 # Simulate I/O
        mutex.synchronize { results << "b:#{value}" }
      end
      define_singleton_method(:name) { "JobB" }
    end

    jobs = [
      [job_class_a, { value: 1 }],
      [job_class_b, { value: 2 }]
    ]

    HTM::JobAdapter.enqueue_parallel(jobs)

    assert_equal 2, results.size
    assert_includes results, "a:1"
    assert_includes results, "b:2"
  end

  # Test parallel execution with inline backend falls back to sequential
  def test_enqueue_parallel_with_inline_backend
    HTM.configuration.job.backend = :inline

    order = []

    job_class_a = Class.new do
      define_singleton_method(:perform) do |**params|
        order << :a
      end
      define_singleton_method(:name) { "JobA" }
    end

    job_class_b = Class.new do
      define_singleton_method(:perform) do |**params|
        order << :b
      end
      define_singleton_method(:name) { "JobB" }
    end

    jobs = [
      [job_class_a, {}],
      [job_class_b, {}]
    ]

    HTM::JobAdapter.enqueue_parallel(jobs)

    # Inline executes sequentially
    assert_equal [:a, :b], order
  end

  # Test parallel execution with empty jobs array
  def test_enqueue_parallel_with_empty_array
    HTM.configuration.job.backend = :inline

    # Should not raise
    HTM::JobAdapter.enqueue_parallel([])
  end

  # Test error handling in fiber mode
  def test_error_handling_in_fiber_mode
    HTM.configuration.job.backend = :fiber

    job_class = Class.new do
      define_singleton_method(:perform) do |**params|
        raise StandardError, "Test error in fiber"
      end

      define_singleton_method(:name) { "FiberErrorTestJob" }
    end

    # Should not raise (errors are logged)
    # Suppress Ruby warnings during test (Ruby 4.0.0 emits IO::Buffer experimental warning)
    old_verbose, $VERBOSE = $VERBOSE, nil
    begin
      assert_silent do
        HTM::JobAdapter.enqueue(job_class, test_param: 'value')
      end
    ensure
      $VERBOSE = old_verbose
    end
  end

  # Test configuration validation includes fiber
  def test_configuration_validates_fiber_backend
    config = HTM::Config.new
    config.job.backend = :fiber
    # Should not raise - fiber is a valid backend
    config.validate_settings!
    assert_equal :fiber, config.job_backend
  end
end
