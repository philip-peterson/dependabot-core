# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../../ports/http_client_port"
require_relative "../../ports/http_response"

module Dependabot
  module Adapters
    module Test
      # Stub HTTP client for testing without making real network requests
      class StubHttpClient < Ports::HttpClientPort
        extend T::Sig

        sig { void }
        def initialize
          @get_stubs = T.let({}, T::Hash[String, Ports::HttpResponse])
          @post_stubs = T.let({}, T::Hash[String, Ports::HttpResponse])
          @head_stubs = T.let({}, T::Hash[String, Ports::HttpResponse])
          @get_regex_stubs = T.let([], T::Array[[Regexp, Ports::HttpResponse]])
          @post_regex_stubs = T.let([], T::Array[[Regexp, Ports::HttpResponse]])
          @head_regex_stubs = T.let([], T::Array[[Regexp, Ports::HttpResponse]])
          @requests = T.let([], T::Array[[Symbol, String]])
        end

        sig do
          override.params(
            url: String,
            headers: T::Hash[String, String]
          ).returns(Ports::HttpResponse)
        end
        def get(url, headers: {})
          @requests << [:get, url]
          find_response(:get, url, @get_stubs, @get_regex_stubs)
        end

        sig do
          override.params(
            url: String,
            body: String,
            headers: T::Hash[String, String]
          ).returns(Ports::HttpResponse)
        end
        def post(url, body:, headers: {})
          @requests << [:post, url]
          find_response(:post, url, @post_stubs, @post_regex_stubs)
        end

        sig do
          override.params(
            url: String,
            headers: T::Hash[String, String]
          ).returns(Ports::HttpResponse)
        end
        def head(url, headers: {})
          @requests << [:head, url]
          find_response(:head, url, @head_stubs, @head_regex_stubs)
        end

        # Stub a GET request
        sig { params(url: String, response: Ports::HttpResponse).void }
        def stub_get(url, response)
          @get_stubs[url] = response
        end

        # Stub a POST request
        sig { params(url: String, response: Ports::HttpResponse).void }
        def stub_post(url, response)
          @post_stubs[url] = response
        end

        # Stub a HEAD request
        sig { params(url: String, response: Ports::HttpResponse).void }
        def stub_head(url, response)
          @head_stubs[url] = response
        end

        # Stub GET requests matching a pattern
        sig { params(pattern: Regexp, response: Ports::HttpResponse).void }
        def stub_get_pattern(pattern, response)
          @get_regex_stubs << [pattern, response]
        end

        # Stub POST requests matching a pattern
        sig { params(pattern: Regexp, response: Ports::HttpResponse).void }
        def stub_post_pattern(pattern, response)
          @post_regex_stubs << [pattern, response]
        end

        # Quick stub for successful GET
        sig { params(url: T.any(String, Regexp), body: String, status: Integer).void }
        def stub_get_success(url, body: "", status: 200)
          response = Ports::HttpResponse.new(
            status: status,
            body: body,
            headers: {}
          )

          case url
          when String
            stub_get(url, response)
          when Regexp
            stub_get_pattern(url, response)
          end
        end

        # Quick stub for failed GET
        sig { params(url: T.any(String, Regexp), status: Integer, body: String).void }
        def stub_get_failure(url, status: 404, body: "Not Found")
          response = Ports::HttpResponse.new(
            status: status,
            body: body,
            headers: {}
          )

          case url
          when String
            stub_get(url, response)
          when Regexp
            stub_get_pattern(url, response)
          end
        end

        # Get all requests made (for assertions)
        sig { returns(T::Array[[Symbol, String]]) }
        attr_reader :requests

        # Check if a request was made
        sig { params(method: Symbol, url: T.any(String, Regexp)).returns(T::Boolean) }
        def requested?(method, url)
          case url
          when String
            @requests.include?([method, url])
          when Regexp
            @requests.any? { |m, u| m == method && u.match?(url) }
          else
            false
          end
        end

        # Clear all stubs and history
        sig { void }
        def clear!
          @get_stubs.clear
          @post_stubs.clear
          @head_stubs.clear
          @get_regex_stubs.clear
          @post_regex_stubs.clear
          @head_regex_stubs.clear
          @requests.clear
        end

        private

        sig do
          params(
            method: Symbol,
            url: String,
            exact_stubs: T::Hash[String, Ports::HttpResponse],
            regex_stubs: T::Array[[Regexp, Ports::HttpResponse]]
          ).returns(Ports::HttpResponse)
        end
        def find_response(method, url, exact_stubs, regex_stubs)
          # Try exact match first
          return T.must(exact_stubs[url]) if exact_stubs.key?(url)

          # Try regex matches
          regex_stubs.each do |pattern, response|
            return response if url.match?(pattern)
          end

          # No stub found
          raise "Unstubbed HTTP #{method.upcase} request: #{url}\n\n" \
                "Available stubs:\n" \
                "  Exact: #{exact_stubs.keys.join(', ')}\n" \
                "  Regex: #{regex_stubs.map { |p, _| p.inspect }.join(', ')}"
        end
      end
    end
  end
end
