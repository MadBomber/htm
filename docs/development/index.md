# Development Guide

Welcome to the HTM development documentation! This guide will help you contribute to HTM, whether you're fixing bugs, adding features, or improving documentation.

## About HTM Development

HTM (Hierarchical Temporary Memory) is an open-source Ruby gem that provides intelligent memory management for LLM-based applications. The project is built with modern Ruby practices, comprehensive testing, and a focus on developer experience.

### Project Values

- **Quality First**: We prioritize correctness, performance, and maintainability
- **Test-Driven**: All features must have comprehensive test coverage
- **Documentation Matters**: Code is read more than it's written
- **Community-Driven**: We welcome contributions from everyone
- **Never Forget**: Like our memory philosophy, we preserve development history and context

## Development Documentation

This development guide is organized into several sections:

### [Setup Guide](setup.md)
Learn how to set up your development environment, clone the repository, install dependencies, configure the database, and run the test suite.

**Topics covered:**

- Cloning the repository
- Installing Ruby and dependencies
- Setting up TimescaleDB for development
- Configuring Ollama for embeddings
- Running tests and examples
- Development tools and rake tasks
- Troubleshooting common setup issues

### [Testing Guide](testing.md)
Understand HTM's testing philosophy, learn how to write tests, and discover best practices for maintaining test quality.

**Topics covered:**

- Test suite organization
- Running tests (unit, integration, all)
- Writing new tests
- Test helpers and fixtures
- Mocking and stubbing strategies
- Test coverage expectations
- CI/CD integration
- Testing best practices

### [Contributing Guide](contributing.md)
Everything you need to know about contributing code, documentation, or bug reports to HTM.

**Topics covered:**

- How to contribute (code, docs, bugs)
- Finding issues to work on
- Development workflow (fork, branch, commit, PR)
- Code style guidelines
- Commit message conventions
- Pull request process
- Code review expectations
- Documentation requirements

### [Database Schema](schema.md)
Deep dive into HTM's database architecture, tables, indexes, and TimescaleDB optimization strategies.

**Topics covered:**

- Complete schema reference
- Entity-Relationship diagrams
- Table definitions and column details
- Indexes and constraints
- Views and functions
- TimescaleDB hypertables
- Compression policies
- Migration strategies

## Quick Start for Contributors

Want to jump right in? Here's the fastest path to contributing:

### 1. Set Up Your Environment

```bash
# Clone the repository
git clone https://github.com/madbomber/htm.git
cd htm

# Install dependencies
bundle install

# Configure database (see setup guide)
source ~/.bashrc__tiger

# Verify setup
rake db_test
```

### 2. Run the Tests

```bash
# Run all tests
rake test

# Run specific test file
ruby test/htm_test.rb

# Run integration tests
ruby test/integration_test.rb
```

### 3. Make Your Changes

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ... edit files ...

# Run tests to verify
rake test

# Commit with descriptive message
git commit -m "Add feature: your feature description"
```

### 4. Submit a Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name

# Open a pull request on GitHub
# Include description of changes and any related issues
```

See the [Contributing Guide](contributing.md) for detailed instructions.

## Development Workflow

HTM follows a streamlined development workflow:

### Branch Strategy

- **`main`**: Stable, production-ready code
- **Feature branches**: `feature/description` for new features
- **Bug fix branches**: `fix/description` for bug fixes
- **Documentation branches**: `docs/description` for documentation updates

### Pull Request Process

1. **Fork and clone** the repository
2. **Create a branch** from `main`
3. **Make your changes** with tests
4. **Run the test suite** to verify
5. **Push to your fork** and create a PR
6. **Respond to review feedback** and iterate
7. **Merge** after approval

### Code Review Standards

All pull requests must:

- Pass the test suite (100% pass rate)
- Maintain or improve test coverage
- Follow Ruby style guidelines
- Include documentation updates
- Have clear commit messages
- Be reviewed by at least one maintainer

## Getting Help

### Documentation

- **[User Guide](../guides/getting-started.md)**: Learn how to use HTM
- **[API Reference](../api/htm.md)**: Detailed API documentation
- **[Architecture Docs](../architecture/overview.md)**: System design and architecture

### Community Resources

- **GitHub Issues**: [https://github.com/madbomber/htm/issues](https://github.com/madbomber/htm/issues)
- **GitHub Discussions**: Ask questions and share ideas
- **Planning Document**: See `htm_teamwork.md` for design decisions and rationale

### Common Questions

**Q: Where do I start if I'm new to the project?**

A: Check out issues labeled `good-first-issue` on GitHub. These are specifically chosen to be approachable for new contributors.

**Q: How do I run tests without a database?**

A: Unit tests (like `test/htm_test.rb`) don't require a database. Integration tests require TimescaleDB. See the [Testing Guide](testing.md) for details.

**Q: What's the preferred debugging approach?**

A: HTM uses the `debug_me` gem for debugging. See examples in the codebase and avoid using `puts` for debugging.

**Q: How do I add new database columns or tables?**

A: See the [Database Schema](schema.md) guide for migration strategies and best practices.

## Code of Conduct

HTM is committed to providing a welcoming and inclusive environment for all contributors. We expect all participants to:

- **Be respectful**: Treat everyone with respect and kindness
- **Be inclusive**: Welcome diverse perspectives and backgrounds
- **Be collaborative**: Work together toward common goals
- **Be professional**: Keep discussions focused and constructive
- **Be patient**: Remember that everyone was a beginner once

Unacceptable behavior includes harassment, discrimination, or any conduct that creates an unsafe or unwelcoming environment.

## Development Philosophy

HTM's development is guided by several key principles:

### Never Forget (But Evolve)

Just like HTM's memory philosophy, we preserve development history and context. However, we're not afraid to evolve and improve:

- Git history is sacred - no force pushes to `main`
- Deprecate before removing - give users time to adapt
- Document breaking changes clearly
- Maintain backward compatibility when possible

### Test Everything

Every feature must have comprehensive tests:

- **Unit tests**: Test individual methods in isolation
- **Integration tests**: Test full workflows with real database
- **Edge cases**: Test error conditions and boundaries
- **Performance**: Monitor memory usage and query performance

### Document as You Go

Documentation is part of the feature:

- Add inline comments for complex logic
- Update API docs for public methods
- Include examples in documentation
- Update guides when behavior changes

### Iterate and Improve

We value continuous improvement:

- Refactor for clarity and performance
- Review and update old code
- Learn from mistakes and share lessons
- Celebrate improvements, no matter how small

## Project Structure

Understanding the codebase structure:

```
htm/
├── lib/                    # Main library code
│   ├── htm.rb             # HTM main class
│   └── htm/
│       ├── database.rb           # Database setup and management
│       ├── long_term_memory.rb   # PostgreSQL-backed storage
│       ├── working_memory.rb     # In-memory active context
│       ├── embedding_service.rb  # Vector embedding generation
│       └── version.rb            # Version constant
├── test/                   # Test suite
│   ├── test_helper.rb           # Test configuration
│   ├── htm_test.rb              # Unit tests
│   ├── embedding_service_test.rb # Embedding tests
│   └── integration_test.rb      # Integration tests
├── sql/                    # Database schemas
│   └── schema.sql              # PostgreSQL/TimescaleDB schema
├── examples/              # Usage examples
│   └── basic_usage.rb          # Basic usage demonstration
├── docs/                   # Documentation (MkDocs)
│   ├── development/            # This guide
│   ├── guides/                 # User guides
│   ├── api/                    # API reference
│   └── architecture/           # Architecture docs
├── Rakefile               # Rake tasks
├── Gemfile                # Development dependencies
├── htm.gemspec            # Gem specification
└── README.md              # Project overview
```

## Tools and Technologies

HTM is built with modern Ruby tools:

### Core Technologies

- **Ruby 3.0+**: Modern Ruby with pattern matching and better performance
- **PostgreSQL 17**: Robust relational database
- **TimescaleDB**: Time-series optimization for PostgreSQL
- **pgvector**: Vector similarity search
- **RubyLLM**: LLM client library for embeddings
- **Ollama**: Local embedding generation

### Development Tools

- **Minitest**: Testing framework
- **Minitest Reporters**: Beautiful test output
- **Rake**: Task automation
- **Bundler**: Dependency management
- **debug_me**: Debugging utility
- **MkDocs**: Documentation generation

### Optional Tools

- **VSCode**: Popular editor with Ruby extensions
- **RuboCop**: Ruby style checker (future)
- **SimpleCov**: Code coverage (future)
- **YARD**: Documentation generator (future)

## Next Steps

Ready to contribute? Here's where to go next:

1. **[Setup Your Environment](setup.md)**: Clone the repo and get everything running
2. **[Understand the Tests](testing.md)**: Learn how to write and run tests
3. **[Read Contributing Guidelines](contributing.md)**: Learn our workflow and standards
4. **[Explore the Schema](schema.md)**: Understand the database architecture

## Thank You

Thank you for your interest in contributing to HTM! Every contribution, whether it's code, documentation, bug reports, or ideas, helps make HTM better for everyone.

We look forward to working with you!

---

**Maintained by**: [Dewayne VanHoozer](https://github.com/madbomber)

**License**: [MIT License](https://opensource.org/licenses/MIT)
