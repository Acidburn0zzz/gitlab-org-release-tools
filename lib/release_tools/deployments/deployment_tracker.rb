# frozen_string_literal: true

module ReleaseTools
  module Deployments
    # Tracking of deployments using the GitLab API
    class DeploymentTracker
      include ::SemanticLogger::Loggable

      # A regex to use for ensuring that we only track Gitaly deployments for
      # SHAs, not tagged versions.
      GIT_SHA_REGEX = /\A[0-9a-f]{40}\z/.freeze

      # The deployment statuses that we support.
      DEPLOYMENT_STATUSES = Set.new(%w[success failed]).freeze

      # The ref to use for recording Gitaly deployments
      GITALY_DEPLOY_REF = 'master'

      # A deployment created using the GitLab API
      Deployment = Struct.new(:project, :id, :status) do
        def success?
          status == 'success'
        end
      end

      # environment - The name of the environment that was deployed to.
      # status - The status of the deployment, such as "success" or "failed".
      # raw_version - The raw deployment version.
      def track(environment, status, raw_version)
        logger.info(
          'Recording GitLab deployment',
          environment: environment,
          status: status,
          version: raw_version
        )

        unless DEPLOYMENT_STATUSES.include?(status)
          raise(
            ArgumentError,
            "The deployment status #{status} is not supported"
          )
        end

        version = DeploymentVersionParser.new.parse(raw_version)

        gitlab_deployment =
          track_gitlab_deployment(environment, status, version)

        gitaly_deployment =
          track_gitaly_deployment(environment, status, version.sha)

        [gitlab_deployment, gitaly_deployment].compact
      end

      private

      def track_gitlab_deployment(environment, status, version)
        logger.info(
          'Recording GitLab Rails deployment',
          environment: environment,
          status: status,
          sha: version.sha,
          ref: version.ref
        )

        data = GitlabClient.create_deployment(
          Project::GitlabEe,
          environment,
          version.ref,
          version.sha,
          status,
          tag: version.tag?
        )

        Deployment.new(Project::GitlabEe, data.id, data.status)
      end

      def track_gitaly_deployment(environment, status, gitlab_sha)
        sha = ComponentVersions.get_component(
          Project::GitlabEe,
          gitlab_sha,
          Project::Gitaly.version_file
        )

        return unless sha.match?(GIT_SHA_REGEX)

        logger.info(
          'Recording Gitaly deployment',
          environment: environment,
          status: status,
          sha: sha,
          ref: GITALY_DEPLOY_REF
        )

        data = GitlabClient.create_deployment(
          Project::Gitaly,
          environment,
          GITALY_DEPLOY_REF,
          sha,
          status
        )

        Deployment.new(Project::Gitaly, data.id, data.status)
      end
    end
  end
end
