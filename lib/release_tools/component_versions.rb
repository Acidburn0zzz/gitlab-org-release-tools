# frozen_string_literal: true

module ReleaseTools
  class ComponentVersions
    class VersionNotFoundError < StandardError
      def initialize(gem_name)
        super("Unable to find a version for gem #{gem_name}")
      end
    end

    include ::SemanticLogger::Loggable

    FILES = [
      Project::Gitaly.version_file,
      Project::GitlabElasticsearchIndexer.version_file,
      Project::GitlabPages.version_file,
      Project::GitlabShell.version_file,
      Project::GitlabWorkhorse.version_file
    ].freeze

    GEMS = [
      Project::GitlabEe::Components::Mailroom
    ].freeze

    def self.get_omnibus_versions(project, commit_id)
      versions = { 'VERSION' => commit_id }

      FILES.each_with_object(versions) do |file, memo|
        memo[file] = get_component(project, commit_id, file)
      end

      logger.info({ project: project }.merge(versions))

      versions
    end

    def self.get_cng_versions(project, commit_id)
      versions = get_omnibus_versions(project, commit_id)

      gemfile_lock = client.file_contents(client.project_path(project), 'Gemfile.lock', commit_id)
      GEMS.each_with_object(versions) do |gem, memo|
        memo[gem.version_file] = version_from_gemfile(gemfile_lock, gem.gem_name).chomp
      end

      logger.info({ project: project }.merge(versions))

      versions
    end

    def self.get_component(project, commit_id, file)
      client
        .file_contents(client.project_path(project), file, commit_id)
        .chomp
    end

    def self.version_from_gemfile(gemfile_lock, gem_name)
      lock_parser = Bundler::LockfileParser.new(gemfile_lock)
      spec = lock_parser.specs.find { |x| x.name == gem_name }

      raise VersionNotFoundError, gem_name if spec.nil?

      version = spec.version.to_s

      logger.trace('Version from Gemfile.lock', gem: gem_name, version: version)

      version
    end

    def self.update_cng(target_branch, version_map)
      return if SharedStatus.dry_run?

      variables = cng_variables(target_branch)
      helm_compatible_versions = versions_to_cng_variables(version_map)
      variables['variables'].merge!(helm_compatible_versions)

      action =
        {
          action: 'update',
          file_path: '/ci_files/variables.yml',
          content: variables.to_yaml
        }

      client.create_commit(
        client.project_path(ReleaseTools::Project::CNGImage),
        target_branch,
        'Update component versions',
        [action]
      )
    end

    def self.update_omnibus(target_branch, version_map)
      return if SharedStatus.dry_run?

      actions = version_map.map do |filename, contents|
        {
          action: 'update',
          file_path: "/#{filename}",
          content: "#{contents}\n"
        }
      end.compact

      client.create_commit(
        client.project_path(ReleaseTools::Project::OmnibusGitlab),
        target_branch,
        'Update component versions',
        actions
      )
    end

    def self.omnibus_version_changes?(target_branch, version_map)
      version_map.any? do |filename, contents|
        client.file_contents(
          client.project_path(ReleaseTools::Project::OmnibusGitlab),
          "/#{filename}",
          target_branch
        ).chomp != contents
      end
    end

    def self.cng_version_changes?(target_branch, version_map)
      variables = cng_variables(target_branch).fetch('variables', {})

      helm_compatible_versions = versions_to_cng_variables(version_map)

      helm_compatible_versions.any? do |component, new_version|
        chart_component_version = variables[component]

        chart_component_version != new_version
      end
    end

    def self.versions_to_cng_variables(version_map)
      cng_variables = version_map.dup
      cng_variables['GITALY_VERSION'] = cng_variables.delete('GITALY_SERVER_VERSION')
      gitlab_version = cng_variables.delete('VERSION')

      %w[GITLAB_VERSION GITLAB_REF_SLUG GITLAB_ASSETS_TAG].each do |component|
        cng_variables[component] = gitlab_version
      end

      cng_variables.each do |component, version|
        parsed_version = ReleaseTools::Version.new(version)

        cng_variables[component] = parsed_version.valid? ? parsed_version.tag : version
      end
    end

    def self.client
      if SharedStatus.security_release?
        ReleaseTools::GitlabDevClient
      else
        ReleaseTools::GitlabClient
      end
    end

    def self.cng_variables(target_branch)
      variables_file = client.file_contents(
        client.project_path(ReleaseTools::Project::CNGImage),
        "/ci_files/variables.yml",
        target_branch
      ).chomp

      YAML.safe_load(variables_file)
    end
  end
end
