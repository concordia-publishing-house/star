require "net/http"
require "ntlm/http"
require "nokogiri"
require "bigdecimal"
require "star/job"
require "star/version"

class Star
  
  class InvalidCredentials < RuntimeError; end
  TIMEFMT = "%m/%d/%Y"
  PRODUCTION = "starweb".freeze
  STAGING = "starwebtest".freeze
  
  
  
  def initialize(host=Star::PRODUCTION, port=80, credentials)
    @host, @port, @credentials = host, port, credentials
  end
  
  def http
    # Create a new connection
    #
    # This is the only way to run Net::HTTP with Keep-Alive
    # In other scenarios it adds the header Connection: Close
    #
    # We want a connection because NTML authenticates a connection
    # If we keep it alive, we can send multiple requests through
    # without re-authenticating.
    #
    @http ||= Net::HTTP.start(host, port)
  end
  
  attr_reader :host, :port, :credentials
  
  def record_time!(project, component, date, hours)
    
    unless project =~ /^\d{6}$/ and component =~ /^\d{2}$/
      entry = Job.entry_for_project_and_component(project, component)
      
      unless entry
        print_missing_component_message!(project, component)
        exit
      end
      
      project, component = entry.split("-")
    end
    
    doc = get! "/WebService.asmx/SubmitTime?jobNumber=#{project}&component=#{component}&date=#{date.strftime(TIMEFMT)}&duration=%.2f" % hours
    
    { message: doc.root.xpath("//ReturnMessage").text,
      success: doc.root.xpath("//Success").text == "true",
      date: Date.strptime(doc.root.xpath("//Date").text, TIMEFMT),
      hours: BigDecimal.new(doc.root.xpath("//Duration").text),
      total: BigDecimal.new(doc.root.xpath("//TotalDurationForDay").text) }
  end
  
  def get_time!(date, user=nil)
    doc = if user
      get! "/WebService.asmx/GetUserTimeForDay?date=#{date.strftime(TIMEFMT)}&user=#{user}"
    else
      get! "/WebService.asmx/GetTimeForDay?date=#{date.strftime(TIMEFMT)}"
    end
    
    doc.root.xpath("//JobTime/JobTimeData").map do |entry|
      job = entry.xpath("JobNumber").text
      code = entry.xpath("ComponentCode").text
      jobno = "#{job}-#{code}"
      project, component = Job.project_and_component_for_entry(jobno)
      project, component = [job, code] if project.nil?
      
      { project: project,
        component: component,
        hours: BigDecimal.new(entry.xpath("Hours").text) }
    end
  end
  
  def submit!
    doc = get! "/WebService.asmx/SubmitTimeSheet"
    { message: doc.root.xpath("//ReturnMessage").text,
      success: doc.root.xpath("//Success").text == "true" }
  end
  
  
  
  def get!(path)
    request = Net::HTTP::Get.new(path)
    response = send_request(request)
    parse_response(response)
  end
  
  
  
  def send_request(request)
    credentials.with_credentials do |username, password|
      request.ntlm_auth(username, "cph.pri", password)
      response = http.request(request)
    end
  end
  
  def parse_response(response)
    xml = response.body
    doc = Nokogiri::XML(xml, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET)
    doc.remove_namespaces!
    doc
  end
  
  
  
end
