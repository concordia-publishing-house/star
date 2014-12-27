require "faraday"
require "faraday/raise_errors"
require "nokogiri"
require "bigdecimal"
require "star/job"
require "star/http_ntlm_adapter"
require "star/version"


class Star
  attr_reader :host, :credentials
  
  class InvalidCredentials < RuntimeError; end
  TIMEFMT = "%m/%d/%Y"
  PRODUCTION = "http://starweb".freeze
  STAGING = "http://starwebtest".freeze
  
  
  
  def initialize(host=Star::PRODUCTION, credentials)
    @host, @credentials = host, credentials
    @http = Faraday.new(url: host) do |http|
      http.use Faraday::RaiseErrors
      http.adapter :http_ntlm
    end
  end
  
  
  
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
    parse_response(credentials.with_credentials { |username, password|
      http.get path, nil, "X-NTLM" => [username, password].join("\n") })
  end
  
  
  
private
  attr_reader :http
  
  def parse_response(response)
    xml = response.body
    doc = Nokogiri::XML(xml, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET)
    doc.remove_namespaces!
    doc
  end
  
end
