# frozen_string_literal: true

module ReleaseTools
  module Deployments
    # Parallel updating of deployed merge requests.
    #
    # This class can be used to update deployed merge requests in parallel, such
    # as by adding a merge request comment and/or adding labels.
    class MergeRequestUpdater
      include ::SemanticLogger::Loggable

      # The base interval for retrying operations that failed, in seconds.
      RETRY_INTERVAL = 5

      # The separator between a scope and label name for scoped labels.
      SCOPE_SEPARATOR = '::'

      # Returns a MergeRequestUpdater operating on successful deployments.
      def self.for_successful_deployments(deployments)
        new(deployments.select(&:success?))
      end

      # deployments - An Array of DeploymentTracker::Deployment instances.
      def initialize(deployments)
        @deployments = deployments
      end

      # Adds the comment to all deployed merge requests.
      #
      # comment - The comment to add, as a String.
      def add_comment(comment)
        each_merge_request do |mr|
          with_retries do
            logger.info("Adding comment to merge request #{mr.web_url}")

            GitlabClient
              .create_merge_request_comment(mr.project_id, mr.iid, comment)
          end
        end
      end

      # Adds the label to all merge requests.
      #
      # This does not use slash commands, as comments that _only_ include slash
      # commands are rejected by our API.
      def add_label(label)
        scope = label_scope(label)

        each_merge_request do |mr|
          with_retries do
            logger.info(
              "Adding label #{label.inspect} to merge request #{mr.web_url}"
            )

            labels = mr.labels

            if scope
              labels.reject! { |l| l.start_with?("#{scope}#{SCOPE_SEPARATOR}") }
            end

            begin
              GitlabClient.update_merge_request(
                mr.project_id,
                mr.iid,
                labels: [label, *labels].join(',')
              )
            rescue Gitlab::Error::Unprocessable => ex
              # In rare cases the API will produce this error but seemingly
              # still update the merge request. To prevent such errors from
              # causing pipeline failures we catch them here and just log them.
              #
              # See https://gitlab.com/gitlab-org/release-tools/-/issues/418 for
              # more information.
              logger.error(ex.message, merge_request: mr.web_url)
            end
          end
        end
      end

      private

      def each_merge_request(&block)
        @deployments.each do |deploy|
          each_deployment_merge_request(deploy.project, deploy.id, &block)
        end
      end

      def each_deployment_merge_request(project, deployment_id, &block)
        page = with_retries do
          GitlabClient.deployed_merge_requests(
            project.canonical_or_security_path,
            deployment_id
          )
        end

        while page
          Parallel.each(page.each.to_a, in_threads: Etc.nprocessors, &block)

          with_retries do
            page = page.next_page
          end
        end
      end

      def with_retries(&block)
        Retriable.retriable(base_interval: RETRY_INTERVAL, &block)
      end

      def label_scope(label)
        segments = label.split(SCOPE_SEPARATOR)

        segments[0] if segments.length > 1
      end
    end
  end
end
