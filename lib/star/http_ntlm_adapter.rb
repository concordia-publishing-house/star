require "faraday/adapter/net_http"
require "net/http"
require "ntlm/http"

module Faraday
  class Adapter
    class HttpNtlmAdapter < Faraday::Adapter::NetHttp

      # https://github.com/lostisland/faraday/blob/v0.8.9/lib/faraday/adapter/net_http.rb#L70
      def perform_request(http, env)
        http.request create_request(env)
      end

      # https://github.com/lostisland/faraday/blob/master/lib/faraday/adapter/net_http.rb#L60-L74
      def create_request(env)
        ntlm = env[:request_headers].delete "X-NTLM"
        super.tap do |request|
          username, password = ntlm.split("\n")
          request.ntlm_auth(username, "cph.pri", password)
        end
      end

    end
  end
end

Faraday::Adapter.register_middleware http_ntlm: Faraday::Adapter::HttpNtlmAdapter
