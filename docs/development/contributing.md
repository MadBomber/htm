# Contributing Guide

Thank you for your interest in contributing to HTM! This guide will help you understand how to contribute effectively.

## Welcome Contributors

We welcome contributions from everyone, regardless of experience level. Whether you're fixing a typo, improving documentation, reporting a bug, or implementing a major feature, your contribution is valued.

### Types of Contributions

We welcome many types of contributions:

- **Bug reports**: Help us identify and fix issues
- **Feature requests**: Suggest new capabilities
- **Documentation**: Improve guides, API docs, or examples
- **Code**: Fix bugs or implement features
- **Tests**: Improve test coverage
- **Performance**: Optimize slow code
- **Design**: Improve architecture or API design

## Getting Started

### Before You Begin

1. **Check existing issues**: Search [GitHub Issues](https://github.com/madbomber/htm/issues) to see if your idea or bug is already reported
2. **Read the docs**: Familiarize yourself with HTM by reading the [User Guide](../guides/getting-started.md) and [API Reference](../api/htm.md)
3. **Set up your environment**: Follow the [Setup Guide](setup.md) to get HTM running locally

### Finding Issues to Work On

Good places to start:

- **`good-first-issue` label**: Issues specifically chosen for new contributors
- **`help-wanted` label**: Issues where we need community help
- **`documentation` label**: Documentation improvements
- **`bug` label**: Bug fixes (clearly defined scope)

Browse issues at: [https://github.com/madbomber/htm/issues](https://github.com/madbomber/htm/issues)

### Claiming an Issue

Before starting work:

1. **Comment on the issue**: Let others know you're working on it
2. **Wait for acknowledgment**: A maintainer will confirm the approach
3. **Ask questions**: If anything is unclear, ask in the issue

This prevents duplicate work and ensures your approach aligns with the project.

## Development Workflow

### 1. Fork and Clone

#### Fork the Repository

1. Visit [https://github.com/madbomber/htm](https://github.com/madbomber/htm)
2. Click "Fork" in the upper right
3. This creates a copy under your GitHub account

#### Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/htm.git
cd htm
```

#### Add Upstream Remote

```bash
git remote add upstream https://github.com/madbomber/htm.git
git fetch upstream
```

### 2. Create a Branch

Always work in a feature branch, never directly on `main`:

```bash
# Sync with upstream first
git checkout main
git pull upstream main

# Create and switch to feature branch
git checkout -b feature/your-feature-name
```

#### Branch Naming Conventions

Use descriptive branch names with prefixes:

- **Features**: `feature/add-compression-policy`
- **Bug fixes**: `fix/recall-timeframe-parsing`
- **Documentation**: `docs/improve-setup-guide`
- **Refactoring**: `refactor/simplify-embedding-service`
- **Performance**: `perf/optimize-vector-search`

Examples:

```bash
git checkout -b feature/add-hybrid-search
git checkout -b fix/working-memory-overflow
git checkout -b docs/add-examples
```

### 3. Make Your Changes

#### Code Changes

Follow these guidelines:

**File Organization**:

- Keep methods focused and testable in isolation
- Use clear, descriptive method and variable names
- Add comments for complex logic
- Follow existing code style

**Error Handling**:

```ruby
# Good: Specific error with helpful message
raise ArgumentError, "importance must be between 0 and 10, got #{importance}"

# Bad: Generic error
raise "Bad importance"
```

**Debugging**:

```ruby
# Good: Use debug_me gem
require 'debug_me'

def process(value)
  debug_me { [ :value ] }
  # Process value...
end

# Bad: Don't use puts
def process(value)
  puts "Value: #{value}"  # Don't do this
end
```

**Method Testing**:

Every method, public or private, must be easily testable in isolation:

```ruby
# Good: Testable method
def calculate_importance(factors)
  base_score = factors[:recency] * 0.4
  relevance_score = factors[:relevance] * 0.6
  base_score + relevance_score
end

# This can be tested without side effects
```

#### Documentation Changes

When updating documentation:

- Use clear, concise language
- Include code examples for features
- Add diagrams for complex concepts
- Use Material for MkDocs formatting
- Check for spelling and grammar

#### Add Tests

All code changes must include tests. See the [Testing Guide](testing.md) for details.

```ruby
# test/your_feature_test.rb
require "test_helper"

class YourFeatureTest < Minitest::Test
  def test_your_feature_works
    result = YourClass.your_method("input")
    assert_equal "expected", result
  end

  def test_handles_edge_cases
    assert_raises(ArgumentError) do
      YourClass.your_method(nil)
    end
  end
end
```

### 4. Run Tests

Before committing, ensure all tests pass:

```bash
# Run all tests
rake test

# Run specific test file
ruby test/your_feature_test.rb

# Run with verbose output
rake test TESTOPTS="-v"
```

All tests must pass before submitting a pull request.

### 5. Commit Your Changes

#### Commit Message Format

We follow a simple commit message convention:

```
<type>: <subject>

<optional body>

<optional footer>
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring (no behavior change)
- `perf`: Performance improvement
- `style`: Code style changes (formatting, etc.)
- `chore`: Maintenance tasks (dependencies, build, etc.)

**Examples**:

```bash
# Good commit messages
git commit -m "feat: add hybrid search combining vector and fulltext"
git commit -m "fix: handle nil values in recall timeframe parsing"
git commit -m "docs: add examples for relationship queries"
git commit -m "test: add integration tests for working memory eviction"
git commit -m "refactor: extract embedding generation to separate method"

# Bad commit messages
git commit -m "updates"
git commit -m "fix stuff"
git commit -m "wip"
```

#### Multi-line Commit Messages

For more complex changes, include a body:

```bash
git commit -m "feat: add compression policy for old memories

Implements automatic compression for memories older than 30 days
using TimescaleDB compression policies. This reduces storage costs
and improves query performance for recent data.

- Adds compress_old_memories rake task
- Updates schema with compression settings
- Adds tests for compression policy
- Documents compression in schema guide

Closes #123"
```

#### Atomic Commits

Make commits focused and atomic:

```bash
# Good: Focused commits
git add lib/htm/compression.rb test/compression_test.rb
git commit -m "feat: add memory compression for old data"

git add docs/development/schema.md
git commit -m "docs: document compression policy in schema guide"

# Bad: Kitchen sink commit
git add .
git commit -m "Add compression and fix bugs and update docs"
```

### 6. Push to Your Fork

```bash
# Push your feature branch
git push origin feature/your-feature-name
```

If you make additional changes:

```bash
# Make changes
git add .
git commit -m "fix: address review feedback"
git push origin feature/your-feature-name
```

### 7. Create a Pull Request

#### Open the Pull Request

1. Visit your fork on GitHub
2. Click "Compare & pull request"
3. Ensure base is `madbomber/htm:main` and compare is `YOUR_USERNAME/htm:feature/your-feature-name`
4. Fill out the pull request template

#### Pull Request Title

Use the same format as commit messages:

```
feat: add hybrid search combining vector and fulltext
fix: handle nil values in recall timeframe parsing
docs: improve setup guide with troubleshooting section
```

#### Pull Request Description

Provide a clear description:

```markdown
## Summary

This PR adds hybrid search functionality that combines vector similarity
search with PostgreSQL full-text search for better recall accuracy.

## Changes

- Add `HybridSearch` class in `lib/htm/hybrid_search.rb`
- Update `recall` method to support `:hybrid` strategy
- Add integration tests for hybrid search
- Document hybrid search in user guide

## Testing

- All existing tests pass
- Added 12 new tests for hybrid search
- Tested with 10,000+ memories in database

## Related Issues

Closes #123
Related to #100

## Screenshots (if applicable)

N/A

## Checklist

- [x] Tests pass locally
- [x] Added tests for new functionality
- [x] Updated documentation
- [x] Followed code style guidelines
- [x] No breaking changes (or documented if necessary)
```

### 8. Respond to Review Feedback

Maintainers will review your pull request and may request changes.

#### Making Changes After Review

```bash
# Make requested changes
git add .
git commit -m "fix: address review feedback - improve error handling"
git push origin feature/your-feature-name
```

The pull request will update automatically.

#### Discuss and Iterate

- **Ask questions**: If feedback is unclear, ask for clarification
- **Explain your approach**: If you disagree, explain your reasoning respectfully
- **Be patient**: Reviews take time, especially for large PRs
- **Be open**: Reviewers have project context you might not have

### 9. Merge

Once approved, a maintainer will merge your pull request. Congratulations!

#### After Merging

```bash
# Sync your fork with upstream
git checkout main
git pull upstream main
git push origin main

# Delete your feature branch (optional)
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## Code Style Guidelines

### Ruby Style

HTM follows standard Ruby conventions:

#### General Style

- **Indentation**: 2 spaces (no tabs)
- **Line length**: Max 100 characters (prefer 80)
- **String literals**: Use double quotes `"string"` for most strings
- **Frozen strings**: Add `# frozen_string_literal: true` at the top of files

#### Naming Conventions

```ruby
# Classes and modules: CamelCase
class WorkingMemory
  module Helpers
  end
end

# Methods and variables: snake_case
def calculate_token_count
  max_tokens = 128_000
end

# Constants: SCREAMING_SNAKE_CASE
MAX_WORKING_MEMORY_SIZE = 128_000

# Private methods: prefix with private keyword
class MyClass
  def public_method
  end

  private

  def private_helper
  end
end
```

#### Method Definitions

```ruby
# Good: Clear parameter names
def add_node(key, value, type:, importance: 1.0, tags: [])
  # Implementation
end

# Good: Guard clauses at the top
def process(value)
  return unless value
  raise ArgumentError, "value too large" if value > MAX_SIZE

  # Main logic
end

# Good: Testable in isolation
def calculate_score(importance, recency)
  (importance * 0.6) + (recency * 0.4)
end
```

#### Error Messages

```ruby
# Good: Specific, actionable error messages
raise ArgumentError, "importance must be between 0 and 10, got #{importance}"
raise HTM::DatabaseError, "Failed to connect to database at #{url}: #{error.message}"

# Bad: Vague errors
raise "Bad value"
raise StandardError
```

### Documentation Style

#### Code Comments

```ruby
# Good: Explain WHY, not WHAT
# Use recency score to prioritize recent memories over old ones
# This prevents the context window from being filled with stale data
recency_score = calculate_recency(timestamp)

# Bad: Obvious comment
# Calculate recency score
recency_score = calculate_recency(timestamp)
```

#### Method Documentation (Future: YARD)

```ruby
# Calculates the importance score based on recency and relevance.
#
# @param importance [Float] Base importance (0-10)
# @param recency [Float] Recency factor (0-1)
# @return [Float] Combined score
# @raise [ArgumentError] If importance is out of range
def calculate_score(importance, recency)
  # Implementation
end
```

### Git Style

#### Branch Names

- Use lowercase with hyphens
- Use descriptive names
- Include type prefix

```bash
# Good
feature/add-compression
fix/recall-parsing
docs/setup-guide

# Bad
MyFeature
fix
branch1
```

#### Commit Messages

- Use imperative mood ("add feature" not "added feature")
- Keep first line under 72 characters
- Add body for complex changes
- Reference issues when applicable

```bash
# Good
feat: add hybrid search for better recall
fix: prevent working memory overflow
docs: improve contributing guide

# Bad
Added stuff
Fixed
Update
```

## Pull Request Guidelines

### Before Submitting

Ensure your pull request:

- [ ] **Passes all tests** - Run `rake test`
- [ ] **Includes new tests** - For new features or bug fixes
- [ ] **Updates documentation** - If behavior changes
- [ ] **Follows code style** - Consistent with existing code
- [ ] **Has clear commits** - Follow commit message guidelines
- [ ] **Is focused** - Solves one problem or adds one feature
- [ ] **No merge conflicts** - Rebase if needed

### Pull Request Checklist

Include this checklist in your PR description:

```markdown
## Checklist

- [ ] Tests pass locally (`rake test`)
- [ ] Added tests for new functionality
- [ ] Updated documentation (if applicable)
- [ ] Followed code style guidelines
- [ ] Commits follow message conventions
- [ ] No breaking changes (or documented clearly)
- [ ] Referenced related issues
```

### Pull Request Size

Keep pull requests manageable:

- **Small PRs**: <200 lines changed (ideal)
- **Medium PRs**: 200-500 lines (acceptable)
- **Large PRs**: >500 lines (split if possible)

Large PRs are harder to review and more likely to have issues. Consider splitting into smaller, incremental changes.

### Handling Merge Conflicts

If your branch conflicts with `main`:

```bash
# Sync with upstream
git fetch upstream

# Rebase your branch
git checkout feature/your-feature
git rebase upstream/main

# Resolve conflicts
# ... edit files ...
git add .
git rebase --continue

# Force push (your branch only!)
git push origin feature/your-feature --force
```

## Code Review Process

### What to Expect

1. **Initial review**: Within 3-5 days (usually faster)
2. **Feedback**: Comments on code, tests, or documentation
3. **Iteration**: Make requested changes
4. **Approval**: Once all feedback is addressed
5. **Merge**: Maintainer merges the PR

### Review Criteria

Reviewers check for:

- **Correctness**: Does it work as intended?
- **Tests**: Are there adequate tests?
- **Style**: Does it follow our conventions?
- **Documentation**: Are changes documented?
- **Design**: Does it fit the architecture?
- **Performance**: Are there performance concerns?
- **Security**: Are there security implications?

### Responding to Reviews

- **Be responsive**: Reply to comments promptly
- **Be respectful**: Assume good intent
- **Be open**: Consider feedback carefully
- **Ask questions**: If anything is unclear
- **Explain reasoning**: If you disagree with feedback

## Documentation Requirements

### When to Update Docs

Update documentation if you:

- Add a new feature
- Change existing behavior
- Add or change public API methods
- Fix a bug that affects documented behavior
- Improve performance characteristics

### Documentation Locations

- **User Guide**: `docs/guides/getting-started.md` - How to use the feature
- **API Reference**: `docs/api/` - Method signatures and parameters
- **Development Guide**: `docs/development/` - Developer information
- **README**: `README.md` - High-level overview
- **Code Comments**: Inline documentation for complex logic

### Documentation Style

- Use clear, concise language
- Include code examples
- Add warnings for edge cases
- Use Material for MkDocs formatting
- Spell check your writing

Example:

```markdown
### Hybrid Search

HTM's hybrid search combines vector similarity search with full-text search for improved recall accuracy.

**Usage:**

```ruby
memories = htm.recall(
  topic: "database decisions",
  strategy: :hybrid,
  timeframe: "last week"
)
```

**Parameters:**

- `topic` (String): Search query
- `strategy` (Symbol): Must be `:hybrid`
- `timeframe` (String): Optional time range

**Returns:**

Array of memory hashes with relevance scores.

!!! warning
    Hybrid search requires Ollama to be running for embedding generation.
```

## Release Process

### Versioning

HTM uses [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., `1.2.3`)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist (Maintainers)

1. Update `lib/htm/version.rb`
2. Update `CHANGELOG.md` (future)
3. Run full test suite
4. Create git tag
5. Push to RubyGems
6. Create GitHub release

Contributors don't need to worry about releases - maintainers handle this.

## Community Guidelines

### Code of Conduct

We are committed to providing a welcoming, inclusive environment:

- **Be respectful**: Treat everyone with respect
- **Be inclusive**: Welcome diverse perspectives
- **Be collaborative**: Work together constructively
- **Be professional**: Keep discussions focused
- **Be patient**: Help others learn

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and general discussion
- **Pull Requests**: Code review and collaboration

### Getting Help

If you're stuck:

1. **Check the docs**: Review guides and API reference
2. **Search issues**: Someone might have had the same problem
3. **Ask in discussions**: Post your question
4. **Be specific**: Include error messages, code samples, versions

## Recognition

Contributors are recognized in several ways:

- Listed in `CONTRIBUTORS.md` (future)
- Mentioned in release notes
- GitHub contributor badge
- Our gratitude and appreciation!

## Additional Resources

### Project Documentation

- **[Setup Guide](setup.md)**: Set up development environment
- **[Testing Guide](testing.md)**: Write and run tests
- **[Schema Documentation](schema.md)**: Database architecture
- **[Architecture Overview](../architecture/overview.md)**: System design

### External Resources

- **Ruby Style Guide**: [https://rubystyle.guide/](https://rubystyle.guide/)
- **Git Best Practices**: [https://git-scm.com/book/en/v2](https://git-scm.com/book/en/v2)
- **Semantic Versioning**: [https://semver.org/](https://semver.org/)
- **Conventional Commits**: [https://www.conventionalcommits.org/](https://www.conventionalcommits.org/)

## Questions?

If you have questions about contributing:

- Open a [GitHub Discussion](https://github.com/madbomber/htm/discussions)
- Comment on a related issue
- Review `htm_teamwork.md` for design context

## Thank You!

Thank you for contributing to HTM! Your efforts help make HTM better for everyone. We appreciate your time, expertise, and collaboration.

Happy coding!

---

**Maintained by**: [Dewayne VanHoozer](https://github.com/madbomber)

**License**: [MIT License](https://opensource.org/licenses/MIT)
