# typed: strict
# frozen_string_literal: true

require "pathname"
require "sorbet-runtime"
require_relative "../../ports/file_system_port"

module Dependabot
  module Adapters
    module Test
      # In-memory file system for fast, isolated unit testing
      # No actual disk I/O is performed
      class InMemoryFileSystem < Ports::FileSystemPort
        extend T::Sig

        sig { void }
        def initialize
          @files = T.let({}, T::Hash[String, String])
          @directories = T.let(Set.new, T::Set[String])
        end

        sig { override.params(path: String).returns(String) }
        def read(path)
          normalized = normalize_path(path)
          raise Errno::ENOENT, "No such file or directory: #{path}" unless @files.key?(normalized)

          T.must(@files[normalized])
        end

        sig { override.params(path: String, content: String).void }
        def write(path, content)
          normalized = normalize_path(path)

          # Ensure parent directory exists
          parent = File.dirname(normalized)
          mkdir_p(parent) unless parent == "." || parent == "/"

          @files[normalized] = content
        end

        sig { override.params(path: String).returns(T::Boolean) }
        def exist?(path)
          normalized = normalize_path(path)
          @files.key?(normalized) || @directories.include?(normalized)
        end

        sig { override.params(path: String).returns(T::Array[String]) }
        def list_directory(path)
          normalized = normalize_path(path)
          raise Errno::ENOENT, "No such directory: #{path}" unless @directories.include?(normalized)

          prefix = normalized == "/" ? "" : "#{normalized}/"

          entries = Set.new

          # Find files in this directory
          @files.keys.each do |file_path|
            if file_path.start_with?(prefix)
              relative = file_path[prefix.length..-1]
              next if relative.nil? || relative.empty?

              # Only include direct children
              entries.add(relative.split("/").first) if relative.include?("/") || !relative.empty?
            end
          end

          # Find subdirectories
          @directories.each do |dir_path|
            next if dir_path == normalized

            if dir_path.start_with?(prefix)
              relative = dir_path[prefix.length..-1]
              next if relative.nil? || relative.empty?

              entries.add(relative.split("/").first)
            end
          end

          entries.to_a
        end

        sig { override.params(path: String).void }
        def mkdir_p(path)
          normalized = normalize_path(path)

          # Create all parent directories
          parts = normalized.split("/").reject(&:empty?)
          current = "/"

          parts.each do |part|
            current = File.join(current, part)
            @directories.add(normalize_path(current))
          end

          @directories.add(normalized) unless normalized == "/"
        end

        sig { override.params(path: String).void }
        def remove(path)
          normalized = normalize_path(path)

          # Remove file if it exists
          @files.delete(normalized)

          # Remove directory and all contents
          if @directories.include?(normalized)
            @directories.delete(normalized)

            # Remove all files and subdirectories under this path
            prefix = "#{normalized}/"
            @files.delete_if { |file_path| file_path.start_with?(prefix) }
            @directories.delete_if { |dir_path| dir_path.start_with?(prefix) }
          end
        end

        sig { override.params(old_path: String, new_path: String).void }
        def rename(old_path, new_path)
          old_normalized = normalize_path(old_path)
          new_normalized = normalize_path(new_path)

          if @files.key?(old_normalized)
            @files[new_normalized] = T.must(@files.delete(old_normalized))
          elsif @directories.include?(old_normalized)
            @directories.delete(old_normalized)
            @directories.add(new_normalized)

            # Move all files under old path to new path
            prefix = "#{old_normalized}/"
            @files.transform_keys! do |file_path|
              if file_path.start_with?(prefix)
                new_normalized + file_path[old_normalized.length..-1]
              else
                file_path
              end
            end
          else
            raise Errno::ENOENT, "No such file or directory: #{old_path}"
          end
        end

        sig { override.params(path: String).returns(T::Boolean) }
        def directory?(path)
          normalized = normalize_path(path)
          @directories.include?(normalized)
        end

        # Test helper: Seed a file for testing
        sig { params(path: String, content: String).void }
        def seed_file(path, content)
          write(path, content)
        end

        # Test helper: Get all files (for debugging/assertions)
        sig { returns(T::Hash[String, String]) }
        attr_reader :files

        # Test helper: Clear all files and directories
        sig { void }
        def clear!
          @files.clear
          @directories.clear
          @directories.add("/")
        end

        private

        sig { params(path: String).returns(String) }
        def normalize_path(path)
          # Convert to absolute path and normalize
          absolute = path.start_with?("/") ? path : "/#{path}"
          Pathname.new(absolute).cleanpath.to_s
        end
      end
    end
  end
end
