# frozen_string_literal: true

module ReleaseTools
  class ComponentVersions
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

    def self.get(project, commit_id)
      get_omnibus_compat_versions(project, commit_id)
    end

    def self.get_omnibus_compat_versions(project, commit_id)
      versions = { 'VERSION' => commit_id }

      FILES.each_with_object(versions) do |file, memo|
        memo[file] = get_component(project, commit_id, file)
      end

      logger.info({ project: project }.merge(versions))

      versions
    end

    def self.sanitize_cng_versions(versions)
      versions['GITLAB_VERSION'] = versions['GITLAB_ASSETS_TAG'] = versions.delete('VERSION')

      versions.each_pair do |component, version|
        # If it looks like SemVer, assume it's a tag, which we prepend with `v`
        if version.match?(/\A\d+\.\d+\.\d+\z/)
          versions[component] = "v#{version}"
        end
      end

      versions
    end

    def self.get_component(project, commit_id, file)
      client
        .file_contents(client.project_path(project), file, commit_id)
        .chomp
    end

    def self.update_omnibus(target_branch, version_map)
      return if SharedStatus.dry_run?

      actions = version_map.map do |filename, contents|
        {
          action: 'update',
          file_path: "/#{filename}",
          content: "#{contents}\n"
        }
      end

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

    def self.client
      if SharedStatus.security_release?
        ReleaseTools::GitlabDevClient
      else
        ReleaseTools::GitlabClient
      end
    end
  end
end
