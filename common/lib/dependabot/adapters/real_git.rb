# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../ports/git_port"
require_relative "../shared_helpers"

module Dependabot
  module Adapters
    # Real Git adapter that delegates to SharedHelpers for Git operations
    class RealGit < Ports::GitPort
      extend T::Sig

      sig { override.params(url: String, target_dir: String).void }
      def clone(url, target_dir)
        SharedHelpers.run_shell_command(
          "git clone --bare #{url} #{target_dir}"
        )
        nil
      end

      sig { override.params(cwd: String).returns(String) }
      def current_commit(cwd)
        SharedHelpers.run_shell_command(
          "git rev-parse HEAD",
          chdir: cwd
        ).strip
      end

      sig { override.params(cwd: String, ref: String).void }
      def checkout(cwd, ref)
        SharedHelpers.run_shell_command(
          "git checkout #{ref}",
          chdir: cwd
        )
        nil
      end

      sig { override.params(cwd: String).void }
      def init(cwd)
        SharedHelpers.run_shell_command(
          "git init",
          chdir: cwd
        )
        nil
      end

      sig { override.params(cwd: String).void }
      def add_all(cwd)
        SharedHelpers.run_shell_command(
          "git add --all",
          chdir: cwd
        )
        nil
      end

      sig { override.params(cwd: String, message: String).void }
      def commit(cwd, message)
        SharedHelpers.run_shell_command(
          "git commit -m \"#{message.gsub('"', '\\"')}\"",
          chdir: cwd
        )
        nil
      end
    end
  end
end
