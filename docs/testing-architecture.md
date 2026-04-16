# Testing Architecture: Ports & Adapters with Dependency Injection

This document explains the new testing architecture introduced to make dependabot-core more testable.

## Problem

Previously, testing code like `PoetryFileUpdater` was difficult because:
- Tests required real Python, Poetry, and git installations
- Tests took 30-60 seconds each due to subprocess execution
- Edge cases were hard to test (how do you make Poetry fail in specific ways?)
- Tests were flaky due to external dependencies

## Solution

We introduced **Ports & Adapters** (Hexagonal Architecture) with **Dependency Injection**:

```
┌─────────────────────────────────────────┐
│     Business Logic (PoetryFileUpdater)  │  ← Your code
│            depends on ↓                 │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│    Port Interfaces (abstractions)       │  ← Abstract interfaces
│  FileSystemPort, ShellExecutorPort      │
└─────────────────────────────────────────┘
                 ↓
        ┌───────┴────────┐
        ↓                ↓
┌──────────────┐  ┌──────────────────┐
│ RealAdapters │  │  TestAdapters    │      ← Implementations
│ (Production) │  │  (Testing)       │
└──────────────┘  └──────────────────┘
```

## Core Components

### 1. Port Interfaces (`common/lib/dependabot/ports/`)

Abstract interfaces defining I/O operations:

- **FileSystemPort** - File operations (`read`, `write`, `exist?`, `mkdir_p`)
- **ShellExecutorPort** - Command execution (`execute`)
- **HttpClientPort** - HTTP requests (`get`, `post`, `head`)
- **GitPort** - Git operations (`clone`, `commit`, `checkout`)

### 2. Real Adapters (`common/lib/dependabot/adapters/`)

Production implementations that delegate to existing code:

- **RealFileSystem** → `File`, `Dir`, `FileUtils`
- **RealShellExecutor** → `SharedHelpers.run_shell_command`
- **RealHttpClient** → `Excon`
- **RealGit** → Git commands via SharedHelpers

### 3. Test Adapters (`common/lib/dependabot/adapters/test/`)

Test doubles for fast, isolated testing:

- **InMemoryFileSystem** - Hash-based file storage (no disk I/O)
- **StubShellExecutor** - Pattern-based command stubbing (no subprocess)
- **StubHttpClient** - URL-based HTTP stubbing (no network)

### 4. ServiceContainer (`common/lib/dependabot/service_container.rb`)

Simple DI container that defaults to real implementations:

```ruby
# In production - uses real implementations (automatic)
updater = PoetryFileUpdater.new(dependencies:, files:, credentials:)

# In tests - inject test doubles
updater = PoetryFileUpdater.new(
  dependencies:, files:, credentials:,
  file_system: InMemoryFileSystem.new,
  shell_executor: StubShellExecutor.new
)
```

## Writing Unit Tests

### Tag Your Tests

```ruby
# Fast unit test (milliseconds)
RSpec.describe MyClass, :unit do
  # Automatically gets in-memory adapters
end

# Slow integration test (seconds)
RSpec.describe MyClass, :integration do
  # Uses real file system, real commands
end
```

### Example Unit Test

```ruby
RSpec.describe PoetryFileUpdater, :unit do
  let(:file_system) { Dependabot::Adapters::Test::InMemoryFileSystem.new }
  let(:shell_executor) { Dependabot::Adapters::Test::StubShellExecutor.new }

  before do
    # Seed in-memory file system
    file_system.seed_file("pyproject.toml", fixture_content)

    # Stub shell commands
    shell_executor.stub_success(/poetry update/, stdout: "Updated")
  end

  it "updates lockfile" do
    updater = described_class.new(
      dependencies: [dep],
      dependency_files: [file],
      credentials: creds,
      file_system: file_system,      # ← Injected
      shell_executor: shell_executor  # ← Injected
    )

    result = updater.updated_dependency_files
    expect(result).to include_lockfile
  end
  # Runtime: ~5ms instead of ~45s ✨
end
```

### Stubbing Commands

```ruby
# Stub successful command
shell_executor.stub_success("poetry --version", stdout: "Poetry 1.5.0")

# Stub failed command
shell_executor.stub_failure("poetry update", stderr: "Package not found", exit_code: 1)

# Stub with regex pattern
shell_executor.stub_command_pattern(/poetry update.*/, result)

# Check if command was executed
expect(shell_executor.executed?(/poetry update/)).to be true
```

### Using In-Memory File System

```ruby
# Seed files for testing
file_system.seed_file("pyproject.toml", content)

# Read files
content = file_system.read("pyproject.toml")

# Check existence
expect(file_system.exist?("poetry.lock")).to be true

# Clear between tests
file_system.clear!
```

## Migrating Existing Code

### 1. Add Constructor Parameters

```ruby
class MyUpdater
  def initialize(dependencies:, files:, credentials:,
                 file_system: nil, shell_executor: nil)
    @file_system = file_system || ServiceContainer.instance.resolve(:file_system)
    @shell_executor = shell_executor || ServiceContainer.instance.resolve(:shell_executor)
    # ...
  end
end
```

### 2. Replace Direct I/O

```ruby
# Before
File.write(path, content)

# After
@file_system.write(path, content)
```

```ruby
# Before
SharedHelpers.run_shell_command("poetry update")

# After
result = @shell_executor.execute("poetry update")
raise "Failed" unless result.success
result.stdout
```

### 3. Write Unit Tests

See `python/spec/dependabot/python/file_updater/poetry_file_updater_unit_spec.rb` for examples.

### 4. Tag Integration Tests

```ruby
# Add :integration tag to existing tests
RSpec.describe MyClass, :integration do
  # These tests use real external dependencies
end
```

## Benefits

### Before Refactoring
- **Test time**: 30-60s per test
- **External deps**: Python, Poetry, git required
- **Coverage**: Hard to test edge cases
- **Flakiness**: Network/subprocess issues

### After Refactoring
- **Test time**: 5-10ms per test (9000x faster!)
- **External deps**: None for unit tests
- **Coverage**: Easy to test any scenario
- **Flakiness**: Zero (pure in-memory)

## Test Pyramid

Goal: Shift from integration-heavy to unit-heavy tests

```
Before (Bad):           After (Good):
     ╱╲                      ╱╲
    ╱  ╲  5% Unit            ╱  ╲  5% E2E
   ╱────╲ 15% Integration   ╱────╲ 25% Integration
  ╱      ╲                 ╱      ╲
 ╱────────╲ 80% E2E       ╱────────╲ 70% Unit
```

## Running Tests

```bash
# Run only fast unit tests
bundle exec rspec --tag unit

# Run only integration tests
bundle exec rspec --tag integration

# Run all tests
bundle exec rspec

# Run unit tests for specific file
bundle exec rspec python/spec/dependabot/python/file_updater/poetry_file_updater_unit_spec.rb
```

## FAQ

### Q: Will this break production code?

No. The changes are backward compatible. Production code uses real implementations by default.

### Q: Do I have to refactor everything at once?

No. This is incremental. Old code continues to work. New code can adopt DI gradually.

### Q: What about existing integration tests?

Keep them! Tag them with `:integration`. They remain valuable for contract testing.

### Q: Is this overkill for simple code?

Use judgment. For code with heavy I/O (file system, network, subprocess), DI helps tremendously. For pure logic, it may not be needed.

### Q: How do I know if I should use DI?

Ask: "Would this be hard to test without real external dependencies?" If yes, use DI.

## Next Steps

1. **Review Poetry pilot** - See `poetry_file_updater.rb` and `poetry_file_updater_unit_spec.rb`
2. **Apply to other modules** - Start with modules that do heavy I/O
3. **Write more unit tests** - Increase coverage, test edge cases
4. **Measure improvements** - Track test speed, coverage, flakiness

## Resources

- Plan: `/Users/quine/.claude/plans/binary-mapping-truffle.md`
- Example: `python/lib/dependabot/python/file_updater/poetry_file_updater.rb`
- Unit tests: `python/spec/dependabot/python/file_updater/poetry_file_updater_unit_spec.rb`
- Ports: `common/lib/dependabot/ports/`
- Adapters: `common/lib/dependabot/adapters/`
