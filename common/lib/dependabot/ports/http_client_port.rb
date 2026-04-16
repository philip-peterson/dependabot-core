# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "http_response"

module Dependabot
  module Ports
    # Abstract port for HTTP operations
    # Provides a testable interface for making HTTP requests
    class HttpClientPort
      extend T::Sig
      extend T::Helpers

      abstract!

      # Perform an HTTP GET request
      sig do
        abstract.params(
          url: String,
          headers: T::Hash[String, String]
        ).returns(HttpResponse)
      end
      def get(url, headers: {}); end

      # Perform an HTTP POST request
      sig do
        abstract.params(
          url: String,
          body: String,
          headers: T::Hash[String, String]
        ).returns(HttpResponse)
      end
      def post(url, body:, headers: {}); end

      # Perform an HTTP HEAD request
      sig do
        abstract.params(
          url: String,
          headers: T::Hash[String, String]
        ).returns(HttpResponse)
      end
      def head(url, headers: {}); end
    end
  end
end
