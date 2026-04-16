# typed: strict
# frozen_string_literal: true

require "excon"
require "sorbet-runtime"
require_relative "../ports/http_client_port"
require_relative "../ports/http_response"
require_relative "../shared_helpers"

module Dependabot
  module Adapters
    # Real HTTP client that delegates to Excon
    class RealHttpClient < Ports::HttpClientPort
      extend T::Sig

      sig do
        override.params(
          url: String,
          headers: T::Hash[String, String]
        ).returns(Ports::HttpResponse)
      end
      def get(url, headers: {})
        response = Excon.get(
          url,
          headers: headers,
          idempotent: true,
          **SharedHelpers.excon_defaults
        )

        build_response(response)
      end

      sig do
        override.params(
          url: String,
          body: String,
          headers: T::Hash[String, String]
        ).returns(Ports::HttpResponse)
      end
      def post(url, body:, headers: {})
        response = Excon.post(
          url,
          body: body,
          headers: headers,
          **SharedHelpers.excon_defaults
        )

        build_response(response)
      end

      sig do
        override.params(
          url: String,
          headers: T::Hash[String, String]
        ).returns(Ports::HttpResponse)
      end
      def head(url, headers: {})
        response = Excon.head(
          url,
          headers: headers,
          idempotent: true,
          **SharedHelpers.excon_defaults
        )

        build_response(response)
      end

      private

      sig { params(excon_response: Excon::Response).returns(Ports::HttpResponse) }
      def build_response(excon_response)
        Ports::HttpResponse.new(
          status: excon_response.status,
          body: excon_response.body,
          headers: T.cast(excon_response.headers, T::Hash[String, String])
        )
      end
    end
  end
end
