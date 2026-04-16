# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Dependabot
  module Ports
    # Abstract port for Git operations
    # Provides a testable interface for Git commands
    class GitPort
      extend T::Sig
      extend T::Helpers

      abstract!

      # Clone a Git repository
      sig { abstract.params(url: String, target_dir: String).void }
      def clone(url, target_dir); end

      # Get the current commit SHA in a repository
      sig { abstract.params(cwd: String).returns(String) }
      def current_commit(cwd); end

      # Checkout a specific ref (branch, tag, commit)
      sig { abstract.params(cwd: String, ref: String).void }
      def checkout(cwd, ref); end

      # Initialize a new Git repository
      sig { abstract.params(cwd: String).void }
      def init(cwd); end

      # Add all files to Git staging
      sig { abstract.params(cwd: String).void }
      def add_all(cwd); end

      # Commit staged changes
      sig { abstract.params(cwd: String, message: String).void }
      def commit(cwd, message); end
    end
  end
end
