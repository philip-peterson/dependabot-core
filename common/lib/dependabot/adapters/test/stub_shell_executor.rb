# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../../ports/shell_executor_port"
require_relative "../../ports/execution_result"

module Dependabot
  module Adapters
    module Test
      # Stub shell executor for testing without executing real commands
      class StubShellExecutor < Ports::ShellExecutorPort
        extend T::Sig

        sig { void }
        def initialize
          @command_stubs = T.let({}, T::Hash[String, Ports::ExecutionResult])
          @regex_stubs = T.let([], T::Array[[Regexp, Ports::ExecutionResult]])
          @executed_commands = T.let([], T::Array[String])
        end

        sig do
          override.params(
            command: String,
            env: T::Hash[String, String],
            cwd: T.nilable(String),
            timeout: Integer
          ).returns(Ports::ExecutionResult)
        end
        def execute(command, env: {}, cwd: nil, timeout: 120)
          @executed_commands << command

          # Try exact match first
          return T.must(@command_stubs[command]) if @command_stubs.key?(command)

          # Try regex matches
          @regex_stubs.each do |pattern, result|
            return result if command.match?(pattern)
          end

          # No stub found
          raise "Unstubbed shell command: #{command}\n\n" \
                "Available stubs:\n" \
                "  Exact: #{@command_stubs.keys.join(', ')}\n" \
                "  Regex: #{@regex_stubs.map { |p, _| p.inspect }.join(', ')}"
        end

        # Stub a command with an exact match
        sig { params(command: String, result: Ports::ExecutionResult).void }
        def stub_command(command, result)
          @command_stubs[command] = result
        end

        # Stub commands matching a regex pattern
        sig { params(pattern: Regexp, result: Ports::ExecutionResult).void }
        def stub_command_pattern(pattern, result)
          @regex_stubs << [pattern, result]
        end

        # Create a successful result quickly
        sig { params(command: T.any(String, Regexp), stdout: String).void }
        def stub_success(command, stdout: "")
          result = Ports::ExecutionResult.new(
            stdout: stdout,
            stderr: "",
            exit_code: 0,
            success: true
          )

          case command
          when String
            stub_command(command, result)
          when Regexp
            stub_command_pattern(command, result)
          end
        end

        # Create a failed result quickly
        sig { params(command: T.any(String, Regexp), stderr: String, exit_code: Integer).void }
        def stub_failure(command, stderr: "Command failed", exit_code: 1)
          result = Ports::ExecutionResult.new(
            stdout: "",
            stderr: stderr,
            exit_code: exit_code,
            success: false
          )

          case command
          when String
            stub_command(command, result)
          when Regexp
            stub_command_pattern(command, result)
          end
        end

        # Get all executed commands (for assertions)
        sig { returns(T::Array[String]) }
        attr_reader :executed_commands

        # Check if a command was executed
        sig { params(command: T.any(String, Regexp)).returns(T::Boolean) }
        def executed?(command)
          case command
          when String
            @executed_commands.include?(command)
          when Regexp
            @executed_commands.any? { |cmd| cmd.match?(command) }
          else
            false
          end
        end

        # Clear all stubs and history
        sig { void }
        def clear!
          @command_stubs.clear
          @regex_stubs.clear
          @executed_commands.clear
        end
      end
    end
  end
end
