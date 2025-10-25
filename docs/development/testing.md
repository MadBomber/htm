# Testing Guide

HTM follows a comprehensive testing philosophy to ensure reliability, correctness, and maintainability. This guide covers everything you need to know about testing HTM.

## Testing Philosophy

### Core Principles

HTM's testing approach is guided by these principles:

1. **Test Everything**: Every feature must have corresponding tests
2. **Test in Isolation**: Methods should be testable independently
3. **Test Real Scenarios**: Integration tests with actual database
4. **Test Edge Cases**: Don't just test the happy path
5. **Keep Tests Fast**: Optimize for quick feedback loops
6. **Keep Tests Clear**: Tests are documentation

### Test-Driven Development

We encourage (but don't strictly require) test-driven development:

1. **Write the test first** - Define expected behavior
2. **Watch it fail** - Ensure the test actually tests something
3. **Implement the feature** - Make the test pass
4. **Refactor** - Clean up while tests keep you safe

## Test Suite Overview

HTM uses **Minitest** as its testing framework. The test suite is organized into three categories:

### Unit Tests

**Purpose**: Test individual methods and classes in isolation

**Location**: `test/*_test.rb` (excluding `integration_test.rb`)

**Characteristics**:

- Fast execution (milliseconds)
- No database required
- Mock external dependencies
- Test logic and behavior

**Example**: `test/htm_test.rb`, `test/embedding_service_test.rb`

### Integration Tests

**Purpose**: Test full workflows with real dependencies

**Location**: `test/integration_test.rb`

**Characteristics**:

- Slower execution (seconds)
- Requires PostgreSQL/TimescaleDB
- Requires Ollama for embeddings
- Tests real-world scenarios
- Tests database interactions

### Performance Tests

**Purpose**: Ensure performance characteristics

**Status**: Planned for future implementation

**Focus areas**:

- Query performance
- Memory usage
- Token counting accuracy
- Embedding generation speed

## Running Tests

### Run All Tests

```bash
# Using Rake (recommended)
rake test

# Using Ruby directly
ruby -Ilib:test test/**/*_test.rb
```

Expected output:

```
HTMTest
  test_version_exists                             PASS (0.00s)
  test_version_format                             PASS (0.00s)
  test_htm_class_exists                           PASS (0.00s)
  ...

IntegrationTest
  test_htm_initializes_with_ollama                PASS (0.15s)
  test_add_node_with_embedding                    PASS (0.32s)
  ...

Finished in 2.47s
28 tests, 0 failures, 0 errors, 0 skips
```

### Run Specific Test File

```bash
# Run unit tests only
ruby test/htm_test.rb

# Run embedding service tests
ruby test/embedding_service_test.rb

# Run integration tests
ruby test/integration_test.rb
```

### Run Specific Test Method

```bash
# Run a single test method
ruby test/htm_test.rb -n test_version_exists

# Run tests matching a pattern
ruby test/integration_test.rb -n /embedding/
```

### Run Tests with Verbose Output

```bash
# Verbose output
rake test TESTOPTS="-v"

# Show test names as they run
ruby test/htm_test.rb -v
```

### Run Tests with Debugging

```bash
# Run with debug output
DEBUG=1 rake test

# Run with Ruby debugger
ruby -r debug test/htm_test.rb
```

## Test Structure and Organization

### Test File Layout

```
test/
├── test_helper.rb              # Shared test configuration
├── htm_test.rb                 # Unit tests for HTM class
├── embedding_service_test.rb   # Unit tests for EmbeddingService
├── integration_test.rb         # Integration tests
└── fixtures/                   # Test data (future)
    └── sample_memories.json
```

### Test File Template

Every test file follows this structure:

```ruby
# frozen_string_literal: true

require "test_helper"

class MyFeatureTest < Minitest::Test
  def setup
    # Runs before each test
    # Initialize test data, mocks, etc.
  end

  def teardown
    # Runs after each test
    # Clean up test data
  end

  def test_something_works
    # Arrange: Set up test data
    input = "test value"

    # Act: Execute the code being tested
    result = MyClass.some_method(input)

    # Assert: Verify the results
    assert_equal "expected", result
  end

  def test_handles_edge_case
    # Test edge cases and error conditions
    assert_raises(ArgumentError) do
      MyClass.some_method(nil)
    end
  end
end
```

### Test Helper Configuration

`test/test_helper.rb` provides shared configuration:

```ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "htm"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
```

## Writing Tests

### Unit Test Example

Testing a method in isolation:

```ruby
class WorkingMemoryTest < Minitest::Test
  def setup
    @memory = HTM::WorkingMemory.new(max_tokens: 1000)
  end

  def test_calculates_token_count
    node = { value: "Hello, world!" }

    result = @memory.calculate_tokens(node)

    assert_instance_of Integer, result
    assert result > 0
  end

  def test_rejects_nodes_exceeding_capacity
    @memory = HTM::WorkingMemory.new(max_tokens: 10)
    large_node = { value: "x" * 1000 }

    assert_raises(HTM::WorkingMemoryFullError) do
      @memory.add_node(large_node)
    end
  end
end
```

### Integration Test Example

Testing with real database:

```ruby
class DatabaseIntegrationTest < Minitest::Test
  def setup
    skip "Database not configured" unless ENV['TIGER_DBURL']

    @htm = HTM.new(
      robot_name: "Test Robot",
      working_memory_size: 128_000,
      embedding_service: :ollama
    )
  end

  def teardown
    return unless @htm

    # Clean up test data
    @htm.forget("test_node_001", confirm: :confirmed) rescue nil
  end

  def test_adds_and_retrieves_node
    # Add a node
    node_id = @htm.add_node(
      "test_node_001",
      "Test memory content",
      type: :fact,
      importance: 5.0
    )

    assert_instance_of Integer, node_id

    # Retrieve it
    node = @htm.retrieve("test_node_001")

    refute_nil node
    assert_equal "test_node_001", node['key']
    assert_includes node['value'], "Test memory"
  end
end
```

### Testing with Mocks and Stubs

For testing without external dependencies:

```ruby
class EmbeddingServiceTest < Minitest::Test
  def test_generates_embedding_vector
    service = HTM::EmbeddingService.new(:ollama, model: 'gpt-oss')

    # Skip if Ollama is not available
    skip "Ollama not running" unless ollama_available?

    embedding = service.generate_embedding("test text")

    assert_instance_of Array, embedding
    assert_equal 1536, embedding.length
    assert embedding.all? { |v| v.is_a?(Float) }
  end

  private

  def ollama_available?
    require 'net/http'
    uri = URI('http://localhost:11434/api/version')
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue
    false
  end
end
```

## Test Fixtures

### What are Fixtures?

Fixtures are pre-defined test data that can be reused across tests. HTM will use fixtures for complex test scenarios.

### Future Fixture Structure

```ruby
# test/fixtures/memories.rb
module Fixtures
  MEMORIES = {
    fact: {
      key: "user_preference_001",
      value: "User prefers debug_me over puts for debugging",
      type: :fact,
      importance: 7.0
    },
    decision: {
      key: "decision_001",
      value: "We decided to use TimescaleDB for time-series optimization",
      type: :decision,
      importance: 9.0,
      tags: ["database", "architecture"]
    }
  }
end
```

### Using Fixtures

```ruby
require_relative 'fixtures/memories'

class MemoryTest < Minitest::Test
  def test_stores_fact
    htm = HTM.new(robot_name: "Test")
    fact = Fixtures::MEMORIES[:fact]

    node_id = htm.add_node(
      fact[:key],
      fact[:value],
      type: fact[:type],
      importance: fact[:importance]
    )

    assert node_id > 0
  end
end
```

## Assertions Reference

### Common Assertions

Minitest provides many assertion methods:

```ruby
# Equality
assert_equal expected, actual
refute_equal unexpected, actual

# Truth/falsy
assert actual
refute actual
assert_nil value
refute_nil value

# Type checking
assert_instance_of String, value
assert_kind_of Numeric, value

# Collections
assert_includes collection, item
assert_empty collection
refute_empty collection

# Exceptions
assert_raises(ErrorClass) { code }
assert_silent { code }

# Matching
assert_match /pattern/, string
refute_match /pattern/, string

# Comparison
assert_operator 5, :>, 3
assert_in_delta 3.14, Math::PI, 0.01
```

### Custom Assertions

You can create custom assertions for HTM-specific checks:

```ruby
module HTMAssertions
  def assert_valid_embedding(embedding)
    assert_instance_of Array, embedding
    assert_equal 1536, embedding.length
    assert embedding.all? { |v| v.is_a?(Float) }
  end

  def assert_valid_node(node)
    assert_instance_of Hash, node
    assert node.key?('id')
    assert node.key?('key')
    assert node.key?('value')
    assert node.key?('type')
  end
end

class MyTest < Minitest::Test
  include HTMAssertions

  def test_node_structure
    node = create_test_node
    assert_valid_node(node)
  end
end
```

## Mocking and Stubbing

### When to Mock

Mock external dependencies to:

- Speed up tests (avoid slow API calls)
- Test error conditions
- Isolate the code under test
- Test without required services

### Minitest Mocking

Minitest includes built-in mocking:

```ruby
require 'minitest/mock'

class ServiceTest < Minitest::Test
  def test_calls_external_api
    mock_client = Minitest::Mock.new
    mock_client.expect :call, "response", ["arg"]

    service = MyService.new(client: mock_client)
    result = service.process

    assert_equal "response", result
    mock_client.verify  # Ensures expectations were met
  end
end
```

### Stubbing Methods

Temporarily replace method implementations:

```ruby
class NetworkTest < Minitest::Test
  def test_handles_network_failure
    # Stub a method to simulate failure
    HTM::Database.stub :connected?, false do
      assert_raises(HTM::DatabaseError) do
        htm = HTM.new(robot_name: "Test")
      end
    end
  end
end
```

## Test Coverage

### Coverage Goals

HTM aims for high test coverage:

- **Unit tests**: 90%+ line coverage
- **Integration tests**: Cover all critical paths
- **Edge cases**: Test error conditions
- **Documentation**: Tests serve as usage examples

### Measuring Coverage (Future)

We plan to add SimpleCov for coverage reporting:

```ruby
# test/test_helper.rb (future)
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  minimum_coverage 90
end
```

### Coverage Report

```bash
# Generate coverage report
rake test:coverage

# View report
open coverage/index.html
```

## Continuous Integration

### GitHub Actions (Future)

HTM will use GitHub Actions for CI/CD:

```yaml
# .github/workflows/test.yml (future)
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: timescale/timescaledb-ha:pg17
        env:
          POSTGRES_PASSWORD: testpass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
          bundler-cache: true
      - name: Run tests
        run: bundle exec rake test
```

### CI Requirements

All pull requests must:

- Pass all tests (100%)
- Maintain or improve coverage
- Pass style checks (future)
- Pass integration tests

## Testing Best Practices

### DO: Write Clear Tests

```ruby
# Good: Clear test name and assertions
def test_working_memory_evicts_least_important_nodes_when_full
  memory = HTM::WorkingMemory.new(max_tokens: 100)
  memory.add_node(key: "important", importance: 9.0, tokens: 50)
  memory.add_node(key: "unimportant", importance: 1.0, tokens: 51)

  assert memory.contains?("important")
  refute memory.contains?("unimportant")
end

# Bad: Unclear test
def test_eviction
  memory = HTM::WorkingMemory.new(max_tokens: 100)
  memory.add_node(key: "a", importance: 9.0, tokens: 50)
  memory.add_node(key: "b", importance: 1.0, tokens: 51)
  assert memory.contains?("a")
end
```

### DO: Test One Thing at a Time

```ruby
# Good: Each test focuses on one behavior
def test_calculates_token_count
  result = calculate_tokens("hello")
  assert result > 0
end

def test_handles_empty_string
  result = calculate_tokens("")
  assert_equal 0, result
end

# Bad: Testing multiple things
def test_token_stuff
  assert calculate_tokens("hello") > 0
  assert_equal 0, calculate_tokens("")
  assert_raises(ArgumentError) { calculate_tokens(nil) }
end
```

### DO: Use Descriptive Test Names

```ruby
# Good: Describes what is being tested
def test_recall_returns_memories_from_specified_timeframe
def test_forget_requires_confirmation_parameter
def test_add_node_generates_embedding_automatically

# Bad: Vague or unclear
def test_recall
def test_forget
def test_add
```

### DO: Clean Up After Tests

```ruby
def setup
  @htm = HTM.new(robot_name: "Test")
  @test_keys = []
end

def teardown
  # Clean up any created nodes
  @test_keys.each do |key|
    @htm.forget(key, confirm: :confirmed) rescue nil
  end
end

def test_adds_node
  key = "test_#{Time.now.to_i}"
  @test_keys << key

  @htm.add_node(key, "content", type: :fact)
  # Test continues...
end
```

### DON'T: Rely on Test Order

```ruby
# Bad: Tests depend on each other
def test_1_creates_node
  @htm.add_node("shared", "value", type: :fact)
end

def test_2_retrieves_node  # Fails if test_1 doesn't run first
  node = @htm.retrieve("shared")
  assert node
end

# Good: Each test is independent
def test_creates_node
  @htm.add_node("test_create", "value", type: :fact)
  node = @htm.retrieve("test_create")
  assert node
end

def test_retrieves_node
  @htm.add_node("test_retrieve", "value", type: :fact)
  node = @htm.retrieve("test_retrieve")
  assert node
end
```

### DON'T: Use Sleep for Timing

```ruby
# Bad: Flaky test with arbitrary sleep
def test_async_operation
  start_operation
  sleep 2  # Hope it finishes in 2 seconds
  assert operation_complete?
end

# Good: Poll with timeout
def test_async_operation
  start_operation
  wait_until(timeout: 5) { operation_complete? }
  assert operation_complete?
end

def wait_until(timeout: 5)
  start = Time.now
  loop do
    return if yield
    raise "Timeout" if Time.now - start > timeout
    sleep 0.1
  end
end
```

### DON'T: Test Implementation Details

```ruby
# Bad: Testing internal implementation
def test_uses_specific_sql_query
  assert_match /SELECT \* FROM/, @htm.instance_variable_get(:@last_query)
end

# Good: Testing behavior/outcome
def test_retrieves_all_node_fields
  @htm.add_node("key", "value", type: :fact)
  node = @htm.retrieve("key")

  assert node.key?('id')
  assert node.key?('key')
  assert node.key?('value')
  assert node.key?('type')
end
```

## Debugging Test Failures

### Run Single Test with Verbose Output

```bash
ruby test/htm_test.rb -v -n test_specific_test
```

### Use debug_me in Tests

```ruby
require 'debug_me'

def test_something
  debug_me { [ :input, :expected ] }

  result = method_under_test(input)

  debug_me { [ :result ] }

  assert_equal expected, result
end
```

### Check Test Data

```ruby
def test_database_state
  # Add debugging to inspect state
  pp @htm.memory_stats
  pp @htm.working_memory.inspect

  # Your test assertions
  assert something
end
```

### Use Ruby Debugger

```bash
# Install debugger
gem install debug

# Run test with debugger
ruby -r debug test/htm_test.rb

# Set breakpoints in test
def test_something
  debugger  # Execution will stop here
  result = method_under_test
  assert result
end
```

## Testing Checklist

Before submitting a pull request, ensure:

- [ ] All existing tests pass
- [ ] New features have tests
- [ ] Edge cases are tested
- [ ] Error conditions are tested
- [ ] Tests are clear and well-named
- [ ] Tests are independent (no order dependency)
- [ ] Integration tests clean up test data
- [ ] No skipped tests (unless explicitly documented)
- [ ] Tests run in reasonable time (<5s for unit, <30s for integration)

## Resources

### Minitest Documentation

- **Official docs**: [https://docs.seattlerb.org/minitest/](https://docs.seattlerb.org/minitest/)
- **Minitest assertions**: [https://docs.seattlerb.org/minitest/Minitest/Assertions.html](https://docs.seattlerb.org/minitest/Minitest/Assertions.html)
- **Minitest mocking**: [https://docs.seattlerb.org/minitest/Minitest/Mock.html](https://docs.seattlerb.org/minitest/Minitest/Mock.html)

### Testing Guides

- **Ruby Testing Guide**: [https://guides.rubyonrails.org/testing.html](https://guides.rubyonrails.org/testing.html)
- **Better Specs**: [https://www.betterspecs.org/](https://www.betterspecs.org/)

## Next Steps

- **[Contributing Guide](contributing.md)**: Learn how to submit your tests
- **[Database Schema](schema.md)**: Understand what you're testing
- **[Setup Guide](setup.md)**: Get your test environment running

Happy testing! Remember: Good tests make better code.
