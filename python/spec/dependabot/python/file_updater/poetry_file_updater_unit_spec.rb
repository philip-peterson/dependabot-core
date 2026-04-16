# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/python/file_updater/poetry_file_updater"
require "dependabot/service_container"
require "dependabot/adapters/test/in_memory_file_system"
require "dependabot/adapters/test/stub_shell_executor"

# Fast unit tests for PoetryFileUpdater using dependency injection
# These tests run in MILLISECONDS without requiring Python, Poetry, or git
RSpec.describe Dependabot::Python::FileUpdater::PoetryFileUpdater, :unit do
  let(:file_system) { Dependabot::Adapters::Test::InMemoryFileSystem.new }
  let(:shell_executor) { Dependabot::Adapters::Test::StubShellExecutor.new }

  let(:dependency_files) { [pyproject, lockfile] }
  let(:pyproject) do
    Dependabot::DependencyFile.new(
      name: "pyproject.toml",
      content: fixture("pyproject_files", "version_not_specified.toml")
    )
  end
  let(:lockfile) do
    Dependabot::DependencyFile.new(
      name: "poetry.lock",
      content: fixture("poetry_locks", "version_not_specified.lock")
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: "requests",
      version: "2.19.1",
      previous_version: "2.18.0",
      package_manager: "pip",
      requirements: [{
        requirement: "*",
        file: "pyproject.toml",
        source: nil,
        groups: ["dependencies"]
      }],
      previous_requirements: [{
        requirement: "*",
        file: "pyproject.toml",
        source: nil,
        groups: ["dependencies"]
      }]
    )
  end

  let(:credentials) do
    [Dependabot::Credential.new({
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    })]
  end

  let(:updater) do
    described_class.new(
      dependency_files: dependency_files,
      dependencies: [dependency],
      credentials: credentials,
      file_system: file_system,
      shell_executor: shell_executor
    )
  end

  describe "#run_poetry_command" do
    context "when command succeeds" do
      before do
        shell_executor.stub_success(
          "poetry config system-git-client true",
          stdout: "Configuration updated"
        )
      end

      it "returns stdout" do
        result = updater.send(:run_poetry_command, "poetry config system-git-client true")
        expect(result).to eq("Configuration updated")
      end

      it "executes the command" do
        updater.send(:run_poetry_command, "poetry config system-git-client true")
        expect(shell_executor.executed?("poetry config system-git-client true")).to be true
      end
    end

    context "when command fails" do
      before do
        shell_executor.stub_failure(
          "poetry update requests",
          stderr: "Package 'requests' not found in any repository",
          exit_code: 1
        )
      end

      it "raises HelperSubprocessFailed with error message" do
        expect do
          updater.send(:run_poetry_command, "poetry update requests")
        end.to raise_error(
          Dependabot::SharedHelpers::HelperSubprocessFailed,
          /Package 'requests' not found/
        )
      end

      it "includes command in error context" do
        expect do
          updater.send(:run_poetry_command, "poetry update requests", fingerprint: "poetry update <dep>")
        end.to raise_error do |error|
          expect(error.error_context[:command]).to eq("poetry update <dep>")
        end
      end
    end

    context "with regex pattern matching" do
      before do
        shell_executor.stub_command_pattern(
          /poetry update .*/,
          Dependabot::Ports::ExecutionResult.new(
            stdout: "Dependencies updated",
            stderr: "",
            exit_code: 0,
            success: true
          )
        )
      end

      it "matches multiple similar commands" do
        result1 = updater.send(:run_poetry_command, "poetry update requests")
        result2 = updater.send(:run_poetry_command, "poetry update flask")

        expect(result1).to eq("Dependencies updated")
        expect(result2).to eq("Dependencies updated")
      end
    end
  end

  describe "#write_temporary_dependency_files" do
    let(:pyproject_content) do
      <<~TOML
        [tool.poetry]
        name = "test"
        version = "0.1.0"

        [tool.poetry.dependencies]
        python = "^3.10"
        requests = "2.19.1"
      TOML
    end

    it "writes all dependency files to file system" do
      updater.send(:write_temporary_dependency_files, pyproject_content)

      expect(file_system.exist?("pyproject.toml")).to be true
      expect(file_system.exist?("poetry.lock")).to be true
    end

    it "writes pyproject.toml with updated content" do
      updater.send(:write_temporary_dependency_files, pyproject_content)

      written_content = file_system.read("pyproject.toml")
      expect(written_content).to include("requests = \"2.19.1\"")
    end

    it "creates parent directories as needed" do
      files_with_nested = dependency_files + [
        Dependabot::DependencyFile.new(
          name: "subdir/nested/config.toml",
          content: "[config]"
        )
      ]

      updater_with_nested = described_class.new(
        dependency_files: files_with_nested,
        dependencies: [dependency],
        credentials: credentials,
        file_system: file_system,
        shell_executor: shell_executor
      )

      updater_with_nested.send(:write_temporary_dependency_files, pyproject_content)

      expect(file_system.exist?("subdir/nested/config.toml")).to be true
      expect(file_system.directory?("subdir/nested")).to be true
    end

    it "does not perform actual disk I/O" do
      # This test itself proves no disk I/O - if it did, we'd see temp files
      # Instead, everything is in-memory
      expect(Dir.glob("/tmp/dependabot_*")).to be_empty

      updater.send(:write_temporary_dependency_files, pyproject_content)

      # Files are in memory, not on disk
      expect(file_system.files.keys).to include("pyproject.toml", "poetry.lock")
      expect(Dir.glob("/tmp/dependabot_*")).to be_empty
    end
  end

  describe "integration between methods" do
    let(:pyproject_content) { pyproject.content }

    before do
      # Stub poetry commands
      shell_executor.stub_success(/poetry config/, stdout: "Config set")
      shell_executor.stub_success(/poetry update/, stdout: "Updated")
    end

    it "writes files and executes commands without external dependencies" do
      # Write files
      updater.send(:write_temporary_dependency_files, pyproject_content)

      # Execute command
      result = updater.send(:run_poetry_command, "poetry config test true")

      expect(file_system.exist?("pyproject.toml")).to be true
      expect(result).to eq("Config set")
      expect(shell_executor.executed?(/poetry config/)).to be true
    end
  end

  describe "performance" do
    it "runs in milliseconds, not seconds" do
      shell_executor.stub_success(/poetry/, stdout: "OK")

      start_time = Time.now

      10.times do
        updater.send(:write_temporary_dependency_files, pyproject.content)
        updater.send(:run_poetry_command, "poetry --version")
        file_system.clear!
        shell_executor.clear!
      end

      elapsed = Time.now - start_time

      # 10 iterations should complete in under 100ms
      # (vs 450+ seconds with real Poetry execution)
      expect(elapsed).to be < 0.1
    end
  end
end
