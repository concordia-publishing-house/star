require "yaml"

class Star
  class Job < Struct.new(:project, :component, :job_number, :deprecated)
    
    PROJECT_ALIASES = {
      "360" => "members",
      "dayschool" => "oic",
      "lsb-editor" => "lsb3",
      "treeview" => "lsb3",
      "email_relay" => "members"
    }.freeze
    
    COMPONENT_ALIASES = {
      "incubation" =>   "planning",
      "enhancement" =>  "feature",
      "improvement" =>  "feature",
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
      entries.reject(&:deprecated).map(&:project).uniq + PROJECT_ALIASES.keys
    end
    
    def self.valid_project?(project)
      legal_projects.member? normalize_project(project)
    end
    
    def self.normalize_project(project)
      PROJECT_ALIASES.fetch(project, project)
    end
    
    
    
    def self.components_for_project(project)
      entries_for_project(project).map(&:component)
    end
    
    def self.legal_components_for_project(project)
      entries_for_project(project).reject(&:deprecated).map(&:component) + COMPONENT_ALIASES.keys
    end
    
    def self.valid_component_for_project?(component, project)
      legal_components_for_project(project).member? normalize_component(component)
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
      data = YAML.load File.read(JOB_NUMBERS_DATA_PATH)
      
      data["jobs"].flat_map { |project_number, job|
        job["components"].map { |component_number, component_slug| new(
          job["name"],
          component_slug,
          "#{project_number}-#{component_number}",
          !!job["deprecated"]) } }
    end
    
    def self.entries_for_project(project)
      project = normalize_project(project)
      entries.select { |entry| entry.project == project }
    end
    
    JOB_NUMBERS_DATA_PATH = File.expand_path("../../../data/job_numbers.yml", __FILE__).freeze
    
  end
end
