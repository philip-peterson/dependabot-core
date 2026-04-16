# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Dependabot
  module Ports
    # Result of executing a shell command
    class ExecutionResult < T::Struct
      extend T::Sig

      const :stdout, String
      const :stderr, String
      const :exit_code, Integer
      const :success, T::Boolean

      sig { returns(String) }
      def to_s
        "ExecutionResult(exit_code=#{exit_code}, success=#{success})"
      end
    end
  end
end
