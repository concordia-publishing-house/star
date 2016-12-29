require "faraday"
require "faraday/raise_errors"
require "nokogiri"
require "bigdecimal"
require "star/errors"
require "star/job"
require "star/http_ntlm_adapter"
require "star/version"


class Star
  attr_reader :host, :credentials

  TIMEFMT = "%m/%d/%Y".freeze
  PRODUCTION = "http://starweb".freeze
  STAGING = "http://starwebtest".freeze
  PAY_TYPES = {
    "BR"   => :timeoff,  # Bereavement
    "BR20" => :timeoff,  # Bereavement 20%
    "BR30" => :timeoff,  # Bereavement 30%
    "BR50" => :timeoff,  # Bereavement 50%

    "HP"   => :holiday,  # Holiday Pay
    "HP20" => :holiday,  # Holiday Pay 20%
    "HP30" => :holiday,  # Holiday Pay 30%
    "HP50" => :holiday,  # Holiday Pay 50%
    "HPRP" => :holiday,  # Holiday RPT Exempt
    "HR50" => :holiday,  # Holiday Pay RPT 50%

    "JR"   => :timeoff,  # Jury Duty
    "JR20" => :timeoff,  # Jury Duty 20%
    "JR30" => :timeoff,  # Jury Duty 30%
    "JR50" => :timeoff,  # Jury Duty 50%

    "REG"  => :regular,  # Regular pay
    "MR20" => :regular,  # Minister Earn. 20%
    "MR30" => :regular,  # Minister Earn. 30%
    "MR50" => :regular,  # Minister Earn 50%

    "MW"   => :timeoff,  # Mission Work
    "MW20" => :timeoff,  # Mission Work 20%
    "MW30" => :timeoff,  # Mission Work 30%
    "MW50" => :timeoff,  # Mission Work 50%

    "OT"   => :overtime, # OverTime
    "SOT"  => :overtime, # Salary Over Time

    "TO"   => :timeoff,  # PaidTime Off-Salary
    "TO20" => :timeoff,  # Paid Time Off 20%
    "TO30" => :timeoff,  # Paid Time Off 30%
    "TO50" => :timeoff,  # Paid Time Off 50%
    "TO-H" => :timeoff   # PaidTime Off-Hourly
  }.freeze

  def initialize(host=Star::PRODUCTION, credentials)
    @host, @credentials = host, credentials
    @http = Faraday.new(url: host) do |http|
      http.use Faraday::RaiseErrors
      http.adapter :http_ntlm
    end
  end



  def record_time!(project, component, date, hours)

    unless project =~ /^\d{6}$/ and component =~ /^\d{2}$/
      entry = Job.entry_for_project_and_component(project, component, date: date)

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

      { date: date,
        project: project,
        component: component,
        hours: BigDecimal.new(entry.xpath("Hours").text) }
    end
  end

  def get_unitime!(date, user)
    doc = get! "/WebService.asmx/GetEmpowerTimeForDay?date=#{date.strftime(TIMEFMT)}&user=#{user}"

    doc.root.xpath("//DetailData/EmpowerTimeDetailData").map do |entry|
      pay_type = entry.xpath("PayType").text
      pay_code = PAY_TYPES.fetch(pay_type)
      { date: date,
        pay_type: pay_type,
        pay_code: pay_code,
        hours: BigDecimal.new(entry.xpath("Hours").text) }
    end
  end

  def submit!
    doc = get! "/WebService.asmx/SubmitTimeSheet"
    { message: doc.root.xpath("//ReturnMessage").text,
      success: doc.root.xpath("//Success").text == "true" }
  end



  def get!(path)
    parse_response get(path)
  end

  def get(path)
    credentials.with_credentials { |username, password|
      http.get path, nil, "X-NTLM" => [username, password].join("\n") }
  end



private
  attr_reader :http

  def parse_response(response)
    xml = response.body
    doc = Nokogiri::XML(xml, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET)
    doc.remove_namespaces!
    raise Star::Error, doc unless doc.root.xpath("//Success").text == "true"
    doc
  end

end
