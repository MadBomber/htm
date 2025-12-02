# HTM Multi-Framework Support Implementation Plan

**Goal:** Enable HTM gem to work seamlessly in CLI, Sinatra, and Rails applications

**Date:** 2025-11-09

---

## Executive Summary

The HTM gem is currently well-architected but uses simple `Thread.new` for background jobs, which is insufficient for production web applications. This plan outlines the changes needed to support three application types:

1. **Standalone CLI Applications** - Synchronous job execution, progress feedback
2. **Sinatra-based Web Apps** - Sidekiq/inline job backends, thread safety
3. **Rails-based Web Apps** - ActiveJob integration, Rails conventions

## Current State Analysis

### Strengths
- Library-based design (not monolithic)
- Environment detection (`RAILS_ENV || RACK_ENV`)
- Configurable logger, embedding, and tag services
- Connection pooling configured
- ActiveRecord for database abstraction

### Critical Gap
Background job processing uses `Thread.new` (lib/htm.rb:278-280, 298-300), which:
- Threads may die when request completes in some Rack servers
- No job persistence/retry
- No monitoring/observability
- Not suitable for production web applications

---

## Required Changes by Application Type

### 1. Standalone CLI Applications ✅ Mostly Ready

**Current Support:**
- Already works via `examples/basic_usage.rb`
- Direct database connection via `HTM_DBURL`
- Synchronous operation possible

**Needs:**
- **Job Processing Option**: Add synchronous mode for CLI
- **Progress Indicators**: CLI-friendly output for background operations
- **Executable Binary**: Optional `exe/htm` for CLI commands
- **Documentation**: CLI usage guide with examples

**Implementation Priority:** Medium

---

### 2. Sinatra-based Web Applications ⚠️ Needs Work

**Current Support:**
- Library can be required
- Configuration system works

**Critical Needs:**

**A. Background Job Integration** ⭐ **CRITICAL**
- Pluggable job backend (Sidekiq, inline, thread)
- Thread safety verification
- Connection pooling validation

**B. Rack Middleware** (Optional but Recommended)
- Automatic HTM instance per request
- Session-based robot identification

**C. Example Sinatra App**
- Full working example with Sidekiq
- Best practices documentation

**Implementation Priority:** **HIGH**

---

### 3. Rails-based Web Applications ⚠️ Needs Significant Work

**Current Support:**
- ActiveRecord already used internally
- Environment detection works
- Rake tasks exist

**Critical Needs:**

**A. ActiveJob Integration** ⭐ **CRITICAL**
- Job classes inheriting from ActiveJob::Base
- Queue configuration
- Rails job conventions

**B. Rails Connection Sharing**
- Detect and use Rails' database connection
- Avoid duplicate connection pools

**C. Rails Engine/Railtie**
- Auto-configuration on Rails boot
- Logger integration
- Rake tasks auto-loading

**D. Rails Generator**
- `rails generate htm:install` command
- Creates initializer and migrations

**E. Test Environment Handling**
- Synchronous job execution in tests
- Test helpers

**F. Example Rails App**
- Full Rails 7 application
- Best practices

**Implementation Priority:** **HIGH**

---

## Cross-Cutting Improvements

### 1. Pluggable Job Backend ⭐ **HIGHEST PRIORITY**

**Create abstraction for background jobs:**

```ruby
# lib/htm/job_adapter.rb
module HTM
  module JobAdapter
    def self.enqueue(job_class, **params)
      case HTM.configuration.job_backend
      when :active_job
        job_class.perform_later(**params)
      when :sidekiq
        job_class.perform_async(**params)
      when :inline
        job_class.perform(**params)
      when :thread
        Thread.new { job_class.perform(**params) }
      else
        raise "Unknown job backend: #{HTM.configuration.job_backend}"
      end
    end
  end
end
```

**Configuration:**
```ruby
HTM.configure do |c|
  c.job_backend = :active_job  # or :sidekiq, :inline, :thread
end
```

**Auto-detection:**
- Detect ActiveJob if defined
- Detect Sidekiq if defined
- Use :inline for test environments
- Default to :thread for standalone apps

---

### 2. Environment Auto-Detection

```ruby
# lib/htm/configuration.rb
def initialize
  @job_backend = detect_job_backend
  @logger = detect_logger
end

private

def detect_job_backend
  if defined?(ActiveJob)
    :active_job
  elsif defined?(Sidekiq)
    :sidekiq
  elsif ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'
    :inline
  else
    :thread
  end
end

def detect_logger
  if defined?(Rails)
    Rails.logger
  elsif defined?(Sinatra::Base)
    Sinatra::Base.logger
  else
    default_logger
  end
end
```

---

### 3. Thread Safety Audit

**Verify these components are thread-safe:**
- `HTM::WorkingMemory` - Per-instance state ✅
- `HTM::LongTermMemory` - Uses connection pool ✅
- `HTM::Configuration` - Global singleton ⚠️

**Add thread-safety tests:**
```ruby
# test/thread_safety_test.rb
def test_concurrent_remember
  threads = 10.times.map do |i|
    Thread.new { htm.remember("Message #{i}") }
  end
  threads.each(&:join)
  assert_equal 10, HTM::Models::Node.count
end
```

---

### 4. Rails-Specific Database Integration

**Create abstract base class:**
```ruby
# lib/htm/models/base.rb
module HTM
  module Models
    class Base < ActiveRecord::Base
      self.abstract_class = true

      def self.establish_connection_if_needed
        unless connected?
          if defined?(Rails)
            establish_connection(Rails.configuration.database_configuration[Rails.env])
          else
            HTM::ActiveRecordConfig.establish_connection!
          end
        end
      end
    end
  end
end
```

**Update all models:**
```ruby
class Robot < HTM::Models::Base
  # ...
end
```

---

### 5. Documentation & Examples

**Framework-Specific Documentation:**
- `docs/cli_usage.md` - CLI application guide
- `docs/sinatra_integration.md` - Sinatra integration guide
- `docs/rails_integration.md` - Rails integration guide
- `docs/job_backends.md` - Job backend configuration

**Working Example Apps:**
- `examples/cli_app/` - CLI tool with synchronous jobs
- `examples/sinatra_app/` - Sinatra + Sidekiq
- `examples/rails_app/` - Rails 7 + ActiveJob

---

## Implementation Roadmap

### Phase 1: Job Backend Abstraction (Week 1) ⭐ **CRITICAL**

**Tasks:**
- [ ] Create `HTM::JobAdapter` with pluggable backends
- [ ] Add `job_backend` configuration option
- [ ] Update job enqueueing in `lib/htm.rb`
- [ ] Support: `:active_job`, `:sidekiq`, `:inline`, `:thread`
- [ ] Add environment auto-detection
- [ ] Create job adapter tests
- [ ] Update existing job classes

**Files to Create:**
- `lib/htm/job_adapter.rb`
- `test/job_adapter_test.rb`

**Files to Modify:**
- `lib/htm/configuration.rb`
- `lib/htm.rb`
- `lib/htm/jobs/generate_embedding_job.rb`
- `lib/htm/jobs/generate_tags_job.rb`

**Impact:** Enables proper Sinatra and Rails integration

---

### Phase 2: Rails Integration (Week 2)

**Tasks:**
- [ ] Create `HTM::Railtie` for auto-configuration
- [ ] Add Rails connection sharing logic
- [ ] Convert jobs to ActiveJob::Base (when in Rails)
- [ ] Create Rails generator (`rails g htm:install`)
- [ ] Add test environment inline jobs
- [ ] Create example Rails app
- [ ] Write Rails integration docs

**Files to Create:**
- `lib/htm/railtie.rb`
- `lib/htm/models/base.rb`
- `lib/generators/htm/install_generator.rb`
- `lib/generators/htm/templates/initializer.rb`
- `examples/rails_app/` (full Rails app)
- `docs/rails_integration.md`

**Files to Modify:**
- `lib/htm.rb` (require railtie)
- `lib/htm/active_record_config.rb`
- `lib/htm/models/*.rb` (inherit from Base)
- `README.md` (add Rails section)

**Impact:** Production-ready Rails support

---

### Phase 3: Sinatra Integration (Week 2)

**Tasks:**
- [ ] Create Rack middleware (optional)
- [ ] Create Sinatra helpers module
- [ ] Create example Sinatra app with Sidekiq
- [ ] Write Sinatra integration docs
- [ ] Add Sinatra-specific tests

**Files to Create:**
- `lib/htm/middleware.rb`
- `lib/htm/sinatra.rb` (helpers)
- `examples/sinatra_app/` (full Sinatra app)
- `docs/sinatra_integration.md`
- `test/sinatra_integration_test.rb`

**Files to Modify:**
- `README.md` (add Sinatra section)

**Impact:** Production-ready Sinatra support

---

### Phase 4: CLI Enhancements (Week 3)

**Tasks:**
- [ ] Add synchronous mode option
- [ ] Create CLI executable (`exe/htm`)
- [ ] Add progress indicators
- [ ] Create CLI example app
- [ ] Write CLI usage documentation

**Files to Create:**
- `exe/htm`
- `examples/cli_app/` (CLI tool)
- `docs/cli_usage.md`
- `lib/htm/cli.rb` (command classes)

**Files to Modify:**
- `htm.gemspec` (add executables)
- `README.md` (add CLI section)

**Impact:** Better CLI developer experience

---

### Phase 5: Thread Safety & Testing (Week 3)

**Tasks:**
- [ ] Thread-safety audit
- [ ] Concurrent request tests
- [ ] Load testing
- [ ] Framework integration tests
- [ ] Job backend tests for all modes

**Files to Create:**
- `test/thread_safety_test.rb`
- `test/concurrent_requests_test.rb`
- `test/job_backends/active_job_test.rb`
- `test/job_backends/sidekiq_test.rb`
- `test/job_backends/inline_test.rb`
- `test/job_backends/thread_test.rb`

**Impact:** Confidence in production deployment

---

## Summary of Required Changes

| Component | Change | Priority | Effort |
|-----------|--------|----------|--------|
| Job Backend Abstraction | Create `HTM::JobAdapter` | **CRITICAL** | Medium |
| Rails Railtie | Auto-configuration | High | Medium |
| Rails Connection Sharing | Detect & use Rails DB | High | Low |
| ActiveJob Integration | Job classes | High | Low |
| Sidekiq Support | Job backend option | High | Low |
| Inline/Sync Mode | For CLI & tests | Medium | Low |
| Thread Safety Tests | Concurrent tests | Medium | Low |
| Sinatra Example | Full app | Medium | Medium |
| Rails Example | Full app | Medium | High |
| Rails Generator | Install generator | Low | Medium |
| CLI Executable | Binary wrapper | Low | Low |
| Rack Middleware | Per-request HTM | Low | Medium |

**Total Estimated Effort:** 2-3 weeks for full implementation

**Minimum Viable Changes** (1 week):
1. Job backend abstraction with ActiveJob + Sidekiq + inline support
2. Rails Railtie for auto-config
3. Basic thread-safety tests
4. Updated documentation

---

## File Structure After Implementation

```
htm/
├── lib/
│   ├── htm/
│   │   ├── job_adapter.rb          # NEW: Pluggable job backends
│   │   ├── railtie.rb              # NEW: Rails auto-configuration
│   │   ├── middleware.rb           # NEW: Rack middleware
│   │   ├── sinatra.rb              # NEW: Sinatra helpers
│   │   ├── cli.rb                  # NEW: CLI commands
│   │   ├── models/
│   │   │   ├── base.rb             # NEW: Abstract base class
│   │   │   ├── robot.rb            # MODIFIED: Inherit from Base
│   │   │   ├── node.rb             # MODIFIED: Inherit from Base
│   │   │   ├── tag.rb              # MODIFIED: Inherit from Base
│   │   │   └── node_tag.rb         # MODIFIED: Inherit from Base
│   │   ├── jobs/
│   │   │   ├── generate_embedding_job.rb  # MODIFIED: Use JobAdapter
│   │   │   └── generate_tags_job.rb       # MODIFIED: Use JobAdapter
│   │   ├── configuration.rb        # MODIFIED: Add job_backend
│   │   └── active_record_config.rb # MODIFIED: Rails detection
│   └── generators/
│       └── htm/
│           ├── install_generator.rb     # NEW: Rails generator
│           └── templates/
│               └── initializer.rb       # NEW: Initializer template
├── exe/
│   └── htm                         # NEW: CLI executable
├── examples/
│   ├── cli_app/                    # NEW: CLI example
│   ├── sinatra_app/                # NEW: Sinatra example
│   └── rails_app/                  # NEW: Rails example
├── docs/
│   ├── cli_usage.md                # NEW: CLI guide
│   ├── sinatra_integration.md      # NEW: Sinatra guide
│   ├── rails_integration.md        # NEW: Rails guide
│   └── job_backends.md             # NEW: Job backend guide
├── test/
│   ├── job_adapter_test.rb         # NEW: Job adapter tests
│   ├── thread_safety_test.rb       # NEW: Thread safety tests
│   ├── concurrent_requests_test.rb # NEW: Concurrency tests
│   ├── sinatra_integration_test.rb # NEW: Sinatra tests
│   └── job_backends/               # NEW: Backend-specific tests
│       ├── active_job_test.rb
│       ├── sidekiq_test.rb
│       ├── inline_test.rb
│       └── thread_test.rb
└── README.md                       # MODIFIED: Add framework sections
```

---

## Testing Strategy

### Unit Tests
- Job adapter with all backends
- Configuration auto-detection
- Model base class connection logic

### Integration Tests
- Rails app integration
- Sinatra app integration
- CLI app integration

### Thread Safety Tests
- Concurrent remember() calls
- Concurrent recall() calls
- Connection pool stress test

### Performance Tests
- Job enqueueing overhead
- Connection pool efficiency
- Memory usage under load

---

## Documentation Deliverables

### User Documentation
1. **README.md** - Updated with framework sections
2. **docs/cli_usage.md** - Standalone CLI applications
3. **docs/sinatra_integration.md** - Sinatra web applications
4. **docs/rails_integration.md** - Rails web applications
5. **docs/job_backends.md** - Job backend configuration

### Developer Documentation
1. **CONTRIBUTING.md** - Updated with testing guidelines
2. **docs/architecture.md** - Job adapter architecture
3. **docs/thread_safety.md** - Thread safety guarantees

### Examples
1. **examples/cli_app/** - Working CLI application
2. **examples/sinatra_app/** - Working Sinatra app
3. **examples/rails_app/** - Working Rails app

---

## Success Criteria

### CLI Applications
- [ ] Can run synchronously without background threads
- [ ] Clear progress indicators
- [ ] Works without Rails/Sinatra dependencies
- [ ] Example app runs successfully

### Sinatra Applications
- [ ] Works with Sidekiq in production
- [ ] Thread-safe for concurrent requests
- [ ] Example app with realistic usage
- [ ] Documentation covers deployment

### Rails Applications
- [ ] Auto-configures on Rails boot
- [ ] Uses ActiveJob seamlessly
- [ ] Shares Rails database connection
- [ ] Generator creates working setup
- [ ] Example app demonstrates best practices
- [ ] Test environment runs synchronously

### All Frameworks
- [ ] Zero breaking changes to existing API
- [ ] Comprehensive test coverage (>90%)
- [ ] Complete documentation
- [ ] Performance regression tests pass

---

## Migration Path for Existing Users

### No Breaking Changes
All changes are backwards-compatible:
- Current `Thread.new` behavior remains default for standalone apps
- Existing configurations continue to work
- Auto-detection happens transparently

### Optional Migration
Users can opt into new features:
```ruby
# Sinatra app
HTM.configure do |c|
  c.job_backend = :sidekiq
end

# Rails app (auto-detected, but can override)
HTM.configure do |c|
  c.job_backend = :active_job  # Already the default in Rails
end

# CLI app (run synchronously)
HTM.configure do |c|
  c.job_backend = :inline
end
```

---

## Risk Assessment

### Low Risk
- Job adapter abstraction (well-defined interface)
- Rails Railtie (optional, doesn't affect existing users)
- Documentation and examples

### Medium Risk
- Thread safety verification (requires thorough testing)
- Connection sharing with Rails (needs careful implementation)

### Mitigation Strategies
- Comprehensive test suite before release
- Beta release for early adopters
- Gradual rollout (job adapter first, then framework integrations)
- Maintain backwards compatibility at all costs

---

## Timeline

**Week 1:** Job Backend Abstraction
- Days 1-2: Create JobAdapter, update configuration
- Days 3-4: Convert jobs to use adapter
- Day 5: Tests and documentation

**Week 2:** Rails & Sinatra Integration
- Days 1-3: Rails Railtie, connection sharing, generator
- Days 4-5: Sinatra helpers, middleware

**Week 3:** Examples, CLI, Testing
- Days 1-2: Example applications
- Days 3-4: CLI enhancements
- Day 5: Thread safety and performance tests

---

## Next Steps

1. **Review and Approve** this plan
2. **Create Feature Branch** (`git checkout -b feature/multi-framework-support`)
3. **Phase 1 Implementation** - Job Backend Abstraction
4. **Iterative Development** - Implement, test, document each phase
5. **Beta Release** - Get feedback from early adopters
6. **Production Release** - After thorough testing

---

## Conclusion

This implementation will transform HTM from a library that *works* in multiple frameworks to one that *excels* in each framework's ecosystem. The pluggable job backend is the critical enabler, with framework-specific integrations providing the polish that makes HTM feel native to each environment.

**Total effort: 2-3 weeks**
**Risk level: Low-Medium**
**Value: High - enables production use in web applications**
