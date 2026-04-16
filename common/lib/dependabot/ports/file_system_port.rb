# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Dependabot
  module Ports
    # Abstract port for file system operations
    # Provides a testable interface for file I/O
    class FileSystemPort
      extend T::Sig
      extend T::Helpers

      abstract!

      # Read the contents of a file
      sig { abstract.params(path: String).returns(String) }
      def read(path); end

      # Write content to a file
      # Returns the number of bytes written (matching File.write behavior)
      sig { abstract.params(path: String, content: String).returns(Integer) }
      def write(path, content); end

      # Check if a file or directory exists
      sig { abstract.params(path: String).returns(T::Boolean) }
      def exist?(path); end

      # List entries in a directory
      sig { abstract.params(path: String).returns(T::Array[String]) }
      def list_directory(path); end

      # Create a directory and all parent directories
      sig { abstract.params(path: String).void }
      def mkdir_p(path); end

      # Remove a file or directory
      sig { abstract.params(path: String).void }
      def remove(path); end

      # Rename or move a file or directory
      sig { abstract.params(old_path: String, new_path: String).void }
      def rename(old_path, new_path); end

      # Check if path is a directory
      sig { abstract.params(path: String).returns(T::Boolean) }
      def directory?(path); end
    end
  end
end
