require "multi_json"

class Star
  class Job < Struct.new(:project, :component, :job_number)
    
    PROJECT_ALIASES = {
      "360" => "members",
      "dayschool" => "oic",
      "lsb-editor" => "lsb3",
      "treeview" => "lsb3",
      "email_relay" => "members"
    }.freeze
    
    COMPONENT_ALIASES = {
      "incubation" =>   "planning",
      "enhancement" =>  "improvement",
      "bugfix" =>       "fix",
      "testfix" =>      "chore",
      "cifix" =>        "chore",
      "ciskip" =>       "chore",
      "ci" =>           "chore",
      "skip" =>         "chore",
      "refactor" =>     "chore"
    }.freeze
    
    
    def self.projects
      @projects ||= entries.map(&:project).uniq
    end
    
    def self.legal_projects
      projects + PROJECT_ALIASES.keys
    end
    
    def self.components
      @components ||= entries.map(&:component).uniq
    end
    
    def self.legal_components
      components + COMPONENT_ALIASES.keys
    end
    
    def self.valid_project?(project)
      projects.member? normalize_project(project)
    end
    
    def self.normalize_project(project)
      PROJECT_ALIASES.fetch(project, project)
    end
    
    def self.entries_for_project(project)
      project = normalize_project(project)
      entries.select { |entry| entry.project == project }
    end
    
    def self.components_for_project(project)
      entries_for_project(project).map(&:component)
    end
    
    def self.valid_component_for_project?(component, project)
      components_for_project(project).member? normalize_component(component)
    end
    
    def self.normalize_component(component)
      COMPONENT_ALIASES.fetch(component, component)
    end
    
    def self.entry_for_project_and_component(project, component)
      entries_for_project = entries_for_project(project)
      
      component = component.to_s
      component = COMPONENT_ALIASES.fetch(component, component)
      entry = entries_for_project.find { |entry| entry.component. == component }
      entry.job_number if entry
    end
    
    def self.project_and_component_for_entry(job_number)
      entry = entries.find { |entry| entry.job_number == job_number }
      [entry.project, entry.component] if entry
    end
    
  private
    
    def self.entries
      @entries ||= read_entries!
    end
    
    def self.read_entries!
      data = MultiJson.load File.read(JOB_NUMBERS_DATA_PATH)
      
      # Ensure that we have only one job number per 
      # project-component combination.
      entries_by_project_and_component = {}.tap do |map|
        data["projects"].each do |project_slug, job_number|
          data["components"].each do |component_slug, component_number|
            map[[project_slug, component_slug]] = "#{job_number}-#{component_number}"
          end
        end
        
        data.fetch("job_numbers", {}).each do |project_slug, job_number|
          map[project_slug.split("-")] = job_number
        end
      end
      
      entries_by_project_and_component.map do |(project, component), job_number|
        new(project, component, job_number)
      end
    end
    
    JOB_NUMBERS_DATA_PATH = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "job_numbers.json")).freeze
    
  end
end
