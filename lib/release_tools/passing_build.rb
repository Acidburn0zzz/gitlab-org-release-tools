# frozen_string_literal: true

module ReleaseTools
  class PassingBuild
    include ::SemanticLogger::Loggable

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

      @version_map = ReleaseTools::ComponentVersions.get(project, commit.id)

      trigger_build if args.trigger_build
    end

    def trigger_build
      if ref.match?(/\A\d+-\d+-auto-deploy-\d+\z/)
        update_omnibus_for_autodeploy
      else
        trigger_branch_build
      end
    end

    def tag(target_commit)
      tag_name = ReleaseTools::AutoDeploy::Naming.tag(
        timestamp: target_commit.created_at.to_s,
        omnibus_ref: target_commit.id,
        ee_ref: @version_map['VERSION']
      )

      tag_message = +"Auto-deploy #{tag_name}\n\n"
      tag_message << @version_map
        .map { |component, version| "#{component}: #{version}" }
        .join("\n")

      tag_omnibus(tag_name, tag_message, target_commit)
      tag_deployer(tag_name, tag_message, 'master')
    end

    private

    def update_omnibus_for_autodeploy
      if ReleaseTools::ComponentVersions.omnibus_version_changes?(ref, @version_map)
        commit = update_omnibus

        tag(commit)
      elsif omnibus_changes?
        commit = ReleaseTools::Commits
          .new(ReleaseTools::Project::OmnibusGitlab, ref: ref)
          .latest

        tag(commit)
      else
        logger.warn('No changes to component versions or Omnibus, nothing to tag')
      end
    end

    def omnibus_changes?
      project = ReleaseTools::Project::OmnibusGitlab
      refs = GitlabClient.commit_refs(project, ref)

      # When our auto-deploy branch `ref` has no associated tags, then there
      # have been changes on the branch since we last tagged it, and should be
      # considered changed
      refs.none? { |ref| ref.type == 'tag' }
    end

    def update_omnibus
      commit = ReleaseTools::ComponentVersions.update_omnibus(ref, @version_map)

      url = commit_url(ReleaseTools::Project::OmnibusGitlab, commit.id)
      logger.info('Updated Omnibus versions', commit_url: url)

      commit
    end

    def tag_omnibus(name, message, commit)
      project = ReleaseTools::Project::OmnibusGitlab

      logger.info('Creating project tag', project: project.to_s, tag: name)

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

      logger.info('Creating project tag', project: project.to_s, tag: name)

      ReleaseTools::GitlabOpsClient
        .create_tag(project, name, ref, message)
    end

    def trigger_branch_build
      pipeline_id = ENV.fetch('CI_PIPELINE_ID', 'pipeline_id_unset')
      branch_name = "#{ref}-#{pipeline_id}"

      logger.info('Creating project branch', project: project.to_s, branch: branch_name)
      ReleaseTools::GitlabDevClient.create_branch(branch_name, ref, project)

      # NOTE: `trigger` always happens on dev here
      ReleaseTools::Pipeline.new(
        project,
        ref,
        @version_map
      ).trigger

      logger.info('Deleting project branch', project: project.to_s, branch: branch_name)
      ReleaseTools::GitlabDevClient.delete_branch(branch_name, project)
    end

    # See https://gitlab.com/gitlab-org/gitlab-foss/issues/25392
    def commit_url(project, id)
      if SharedStatus.security_release?
        "https://dev.gitlab.org/#{project}/commit/#{id}"
      else
        "https://gitlab.com/#{project}/commit/#{id}"
      end
    end
  end
end
