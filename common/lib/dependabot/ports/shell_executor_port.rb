# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "execution_result"

module Dependabot
  module Ports
    # Abstract port for shell command execution
    # Provides a testable interface for running subprocess commands
    class ShellExecutorPort
      extend T::Sig
      extend T::Helpers

      abstract!

      # Execute a shell command
      #
      # @param command [String] the command to execute
      # @param env [Hash<String, String>] environment variables
      # @param cwd [String, nil] working directory for the command
      # @param timeout [Integer] timeout in seconds (default: 120)
      # @return [ExecutionResult] the result of the execution
      sig do
        abstract.params(
          command: String,
          env: T::Hash[String, String],
          cwd: T.nilable(String),
          timeout: Integer
        ).returns(ExecutionResult)
      end
      def execute(command, env: {}, cwd: nil, timeout: 120); end
    end
  end
end
