# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "ports/file_system_port"
require_relative "ports/shell_executor_port"
require_relative "ports/http_client_port"
require_relative "ports/git_port"
require_relative "adapters/real_file_system"
require_relative "adapters/real_shell_executor"
require_relative "adapters/real_http_client"
require_relative "adapters/real_git"

module Dependabot
  # Simple dependency injection container
  # Provides a central registry for resolving service dependencies
  #
  # Usage:
  #   # In production code (uses defaults):
  #   fs = ServiceContainer.instance.resolve(:file_system)
  #
  #   # In tests (inject test doubles):
  #   container = ServiceContainer.new
  #   container.register(:file_system, InMemoryFileSystem.new)
  #   ServiceContainer.instance = container
  class ServiceContainer
    extend T::Sig

    sig { void }
    def initialize
      @services = T.let({}, T::Hash[Symbol, T.untyped])
      register_defaults
    end

    # Register a service implementation
    sig { params(name: Symbol, implementation: T.untyped).void }
    def register(name, implementation)
      @services[name] = implementation
    end

    # Resolve a service by name
    sig { params(name: Symbol).returns(T.untyped) }
    def resolve(name)
      @services.fetch(name) do
        raise ArgumentError, "Service not registered: #{name}. " \
                             "Available services: #{@services.keys.join(', ')}"
      end
    end

    # Check if a service is registered
    sig { params(name: Symbol).returns(T::Boolean) }
    def registered?(name)
      @services.key?(name)
    end

    # Get all registered service names
    sig { returns(T::Array[Symbol]) }
    def services
      @services.keys
    end

    private

    # Register default (real) implementations for all services
    sig { void }
    def register_defaults
      register(:file_system, Adapters::RealFileSystem.new)
      register(:shell_executor, Adapters::RealShellExecutor.new)
      register(:http_client, Adapters::RealHttpClient.new)
      register(:git, Adapters::RealGit.new)
    end

    # Singleton pattern for global access
    class << self
      extend T::Sig

      sig { returns(ServiceContainer) }
      def instance
        @instance ||= T.let(new, T.nilable(ServiceContainer))
      end

      sig { params(container: ServiceContainer).void }
      def instance=(container)
        @instance = container
      end

      # Reset to default instance (useful for tests)
      sig { void }
      def reset!
        @instance = new
      end
    end
  end
end
