# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../ports/shell_executor_port"
require_relative "../ports/execution_result"
require_relative "../shared_helpers"

module Dependabot
  module Adapters
    # Real shell executor that delegates to SharedHelpers
    class RealShellExecutor < Ports::ShellExecutorPort
      extend T::Sig

      sig do
        override.params(
          command: String,
          env: T::Hash[String, String],
          cwd: T.nilable(String),
          timeout: Integer
        ).returns(Ports::ExecutionResult)
      end
      def execute(command, env: {}, cwd: nil, timeout: 120)
        # SharedHelpers expects timeout in milliseconds
        timeout_ms = timeout * 1000

        # Build options hash for SharedHelpers
        options = {}
        options[:env] = env unless env.empty?
        options[:chdir] = cwd if cwd
        options[:timeout] = timeout_ms if timeout_ms != 120_000

        # Execute command via SharedHelpers
        stdout = SharedHelpers.run_shell_command(command, **options)

        Ports::ExecutionResult.new(
          stdout: stdout,
          stderr: "",
          exit_code: 0,
          success: true
        )
      rescue SharedHelpers::HelperSubprocessFailed => e
        Ports::ExecutionResult.new(
          stdout: "",
          stderr: e.message,
          exit_code: 1,
          success: false
        )
      end
    end
  end
end
