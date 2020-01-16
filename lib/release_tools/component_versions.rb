# frozen_string_literal: true

module ReleaseTools
  class ComponentVersions
    class VersionNotFoundError < StandardError; end

    include ::SemanticLogger::Loggable

    FILES = [
      Project::Gitaly.version_file,
      Project::GitlabElasticsearchIndexer.version_file,
      Project::GitlabPages.version_file,
      Project::GitlabShell.version_file,
      Project::GitlabWorkhorse.version_file
    ].freeze

    GEMS = [
      Project::GitlabMailroom
    ].freeze

    def self.get(project, commit_id)
      versions = { 'VERSION' => commit_id }

      FILES.each_with_object(versions) do |file, memo|
        memo[file] = get_component(project, commit_id, file)
      end

      gemfile_lock = client.file_contents(client.project_path(project), 'Gemfile.lock', commit_id)
      GEMS.each_with_object(versions) do |gem, memo|
        memo[gem.version_file] = version_string_from_gemfile(gemfile_lock, gem.gem_name).chomp
      end

      logger.info({ project: project }.merge(versions))

      versions
    end

    def self.get_component(project, commit_id, file)
      client
        .file_contents(client.project_path(project), file, commit_id)
        .chomp
    end

    def self.version_string_from_gemfile(gemfile_lock, gem_name)
      lock_parser = Bundler::LockfileParser.new(gemfile_lock)
      spec = lock_parser.specs.find { |x| x.name == gem_name.to_s }

      raise VersionNotFoundError.new("Unable to find version for gem `#{gem_name}`") if spec.nil?

      version = spec.version.to_s

      logger.trace("#{gem_name} version", version: version)

      version
    end

    def self.update_cng(target_branch, version_map)
      return if SharedStatus.dry_run?

      cng_variables = get_cng_variables(target_branch)
      helm_compatible_versions = versions_to_cng_variables(version_map)
      cng_variables['variables'].merge!(helm_compatible_versions)

      action =
        {
          action: 'update',
          file_path: '/ci_files/variables.yml',
          content: cng_variables.to_yaml
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
        next if filename == 'MAILROOM_VERSION'

        logger.trace('Finding changes', filename: filename, content: contents)
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
        next if filename == 'MAILROOM_VERSION'

        client.file_contents(
          client.project_path(ReleaseTools::Project::OmnibusGitlab),
          "/#{filename}",
          target_branch
        ).chomp != contents
      end
    end

    def self.cng_version_changes?(target_branch, version_map)
      cng_variables = get_cng_variables(target_branch)

      helm_compatible_versions = versions_to_cng_variables(version_map)

      helm_compatible_versions.any? do |component, new_version|
        chart_component_version = cng_variables['variables'][component]

        chart_component_version != new_version
      end
    end

    def self.get_cng_variables(target_branch)
      variables_file = client.file_contents(
        client.project_path(ReleaseTools::Project::CNGImage),
        "/ci_files/variables.yml",
        target_branch
      ).chomp

      YAML.safe_load(variables_file)
    end

    def self.versions_to_cng_variables(version_map)
      cng_variables = version_map.dup
      gitlab_version = cng_variables.delete('VERSION')

      %w[GITLAB_VERSION GITLAB_REF_SLUG GITLAB_ASSETS_TAG].each do |component|
        cng_variables[component] = gitlab_version
      end

      cng_variables.each do |component, version|
        next if component == 'MAILROOM_VERSION'

        parsed_version = ReleaseTools::Version.new(version)
        if parsed_version.valid?
          cng_variables[component] = parsed_version.tag
        else
          cng_variables[component] = version
        end
      end
    end

    def self.client
      if SharedStatus.security_release?
        ReleaseTools::GitlabDevClient
      else
        ReleaseTools::GitlabClient
      end
    end
  end
end
