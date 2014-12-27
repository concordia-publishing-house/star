require "faraday/adapter/net_http"
require "net/http"
require "ntlm/http"

class Star
  class HttpNtlmAdapter < Faraday::Adapter::NetHttp
    
    # https://github.com/lostisland/faraday/blob/master/lib/faraday/adapter/net_http.rb#L60-L74
    def create_request(env)
      request = super
      binding.pry
      request
    end
    
  end
end
