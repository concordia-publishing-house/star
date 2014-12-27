class Star
  
  class InvalidCredentials < RuntimeError; end
  
  class Error < RuntimeError
    attr_reader :response
    
    def initialize(xml_response)
      @response = xml_response
      super response.root.xpath("//ReturnMessage").text
    end
  end

end
