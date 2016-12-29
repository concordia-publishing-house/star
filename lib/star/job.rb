require "yaml"

class Star
  class Job < Struct.new(:project, :component, :job_number, :year, :deprecated)

    PROJECT_ALIASES = {
      "dayschool" => "oic",
      "lsb-editor" => "lsb3",
      "lsb" => "lsb3"
    }.freeze

    COMPONENT_ALIASES = {
      "incubation" =>   "planning",
      "ops" =>          "chore",
      "err" =>          "exception",
      "zendesk" =>      "itsm"
    }.freeze



    def self.projects(date: Date.today)
      @projects ||= entries(date: date).map(&:project).uniq
    end

    def self.legal_projects(date: Date.today)
      entries(date: date).reject(&:deprecated).map(&:project).uniq + PROJECT_ALIASES.keys
    end

    def self.valid_project?(project, date: Date.today)
      legal_projects(date: date).member? normalize_project(project)
    end

    def self.normalize_project(project)
      PROJECT_ALIASES.fetch(project, project)
    end



    def self.components_for_project(project, date: Date.today)
      entries_for_project(project, date: date).map(&:component)
    end

    def self.legal_components_for_project(project, date: Date.today)
      entries_for_project(project, date: date).reject(&:deprecated).map(&:component) + COMPONENT_ALIASES.keys
    end

    def self.valid_component_for_project?(component, project, date: Date.today)
      legal_components_for_project(project, date: date).member? normalize_component(component)
    end

    def self.normalize_component(component)
      COMPONENT_ALIASES.fetch(component, component)
    end



    def self.entry_for_project_and_component(project, component, date: Date.today)
      entries_for_project = entries_for_project(project, date: date)

      component = component.to_s
      component = COMPONENT_ALIASES.fetch(component, component)
      entry = entries_for_project.find { |entry| entry.component. == component }
      entry.job_number if entry
    end

    def self.project_and_component_for_entry(job_number)
      entry = all_entries.find { |entry| entry.job_number == job_number }
      [entry.project, entry.component] if entry
    end



  private

    def self.all_entries
      @entries ||= read_entries!
    end

    def self.entries(date:)
      all_entries.select { |entry| entry.year == date.year }
    end

    def self.read_entries!
      data = YAML.load File.read(JOB_NUMBERS_DATA_PATH)

      data["jobs"].flat_map { |year, jobs|
        jobs.flat_map { |project_number, job|
          job["components"].map { |component_number, component_slug| new(
            job["name"],
            component_slug,
            "#{project_number}-#{component_number}",
            year.to_i,
            !!job["deprecated"]) } } }
    end

    def self.entries_for_project(project, date:)
      project = normalize_project(project)
      all_entries.select { |entry| entry.project == project && entry.year == date.year }
    end

    JOB_NUMBERS_DATA_PATH = File.expand_path("../../../data/job_numbers.yml", __FILE__).freeze

  end
end
