# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Dependabot
  module Ports
    # Response from an HTTP request
    class HttpResponse < T::Struct
      extend T::Sig

      const :status, Integer
      const :body, String
      const :headers, T::Hash[String, String]

      sig { returns(T::Boolean) }
      def success?
        status >= 200 && status < 300
      end

      sig { returns(String) }
      def to_s
        "HttpResponse(status=#{status}, body_length=#{body.length})"
      end
    end
  end
end
