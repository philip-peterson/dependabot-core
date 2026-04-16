# typed: strict
# frozen_string_literal: true

require "fileutils"
require "sorbet-runtime"
require_relative "../ports/file_system_port"

module Dependabot
  module Adapters
    # Real file system adapter that delegates to Ruby's File, Dir, and FileUtils
    class RealFileSystem < Ports::FileSystemPort
      extend T::Sig

      sig { override.params(path: String).returns(String) }
      def read(path)
        File.read(path)
      end

      sig { override.params(path: String, content: String).void }
      def write(path, content)
        File.write(path, content)
      end

      sig { override.params(path: String).returns(T::Boolean) }
      def exist?(path)
        File.exist?(path)
      end

      sig { override.params(path: String).returns(T::Array[String]) }
      def list_directory(path)
        Dir.entries(path).reject { |entry| entry == "." || entry == ".." }
      end

      sig { override.params(path: String).void }
      def mkdir_p(path)
        FileUtils.mkdir_p(path)
      end

      sig { override.params(path: String).void }
      def remove(path)
        FileUtils.rm_rf(path)
      end

      sig { override.params(old_path: String, new_path: String).void }
      def rename(old_path, new_path)
        File.rename(old_path, new_path)
      end

      sig { override.params(path: String).returns(T::Boolean) }
      def directory?(path)
        File.directory?(path)
      end
    end
  end
end
