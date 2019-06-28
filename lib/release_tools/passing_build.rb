# frozen_string_literal: true

module ReleaseTools
  class PassingBuild
    attr_reader :project, :ref

    def initialize(project, ref)
      @project = project
      @ref = ref
    end

    def execute(args)
      commits = ReleaseTools::Commits.new(project, ref: ref)

      commit =
        if SharedStatus.security_release?
          # Passing builds on dev are few and far between; for a security
          # release we'll just use the latest commit on the branch
          commits.latest
        else
          commits.latest_dev_green_build_commit
        end

      if commit.nil?
        raise "Unable to find a passing #{project} build for `#{ref}` on dev"
      end

      version_map = ReleaseTools::ComponentVersions.get(project, commit.id)
      component_strings(version_map).each do |string|
        $stdout.puts string.indent(4)
      end

      trigger_build(version_map) if args.trigger_build
    end

    def trigger_build(version_map)
      if ref.match?(/\A\d+-\d+-auto-deploy-\d+\z/)
        update_omnibus_for_autodeploy(version_map)
      else
        trigger_branch_build(version_map)
      end
    end

    private

    def update_omnibus_for_autodeploy(version_map)
      unless ReleaseTools::ComponentVersions.omnibus_version_changes?(ref, version_map)
        $stdout.puts "No version changes for components, not tagging omnibus"
        return
      end

      update_omnibus(version_map).tap do |commit|
        tag_name = ReleaseTools::AutoDeploy::Naming.tag(
          timestamp: commit.created_at.to_s,
          omnibus_ref: commit.id,
          ee_ref: version_map['VERSION']
        )

        tag_message = +"Auto-deploy #{tag_name}\n\n"
        tag_message << component_strings(version_map).join("\n")

        tag_omnibus(tag_name, tag_message, commit)
        tag_deployer(tag_name, tag_message, "master")
      end
    end

    def component_strings(version_map)
      version_map.map { |component, version| "#{component}: #{version}" }
    end

    def update_omnibus(version_map)
      commit = ReleaseTools::ComponentVersions.update_omnibus(ref, version_map)

      url = commit_url(ReleaseTools::Project::OmnibusGitlab, commit.id)
      $stdout.puts "Updated Omnibus versions at #{url}".indent(4)

      commit
    end

    def tag_omnibus(name, message, commit)
      project = ReleaseTools::Project::OmnibusGitlab

      $stdout.puts "Creating `#{project}` tag `#{name}`".indent(4)

      client =
        if SharedStatus.security_release?
          ReleaseTools::GitlabDevClient
        else
          ReleaseTools::GitlabClient
        end

      client.create_tag(client.project_path(project), name, commit.id, message)
    end

    def tag_deployer(name, message, ref)
      project = ReleaseTools::Project::Deployer

      $stdout.puts "Creating `#{project}` tag `#{name}`".indent(4)

      ReleaseTools::GitlabOpsClient
        .create_tag(project, name, ref, message)
    end

    def trigger_branch_build(version_map)
      pipeline_id = ENV.fetch('CI_PIPELINE_ID', 'pipeline_id_unset')
      branch_name = "#{ref}-#{pipeline_id}"

      $stdout.puts "Creating `#{project}` branch `#{branch_name}`"
      ReleaseTools::GitlabDevClient.create_branch(branch_name, ref, project)

      # NOTE: `trigger` always happens on dev here
      ReleaseTools::Pipeline.new(
        project,
        ref,
        version_map
      ).trigger

      $stdout.puts "Deleting `#{project}` branch `#{branch_name}`"
      ReleaseTools::GitlabDevClient.delete_branch(branch_name, project)
    end

    # See https://gitlab.com/gitlab-org/gitlab-ce/issues/25392
    def commit_url(project, id)
      if SharedStatus.security_release?
        "https://dev.gitlab.org/#{project}/commit/#{id}"
      else
        "https://gitlab.com/#{project}/commit/#{id}"
      end
    end
  end
end
