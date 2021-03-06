# frozen_string_literal: true

module ReleaseTools
  module Security
    class ImplementationIssue
      # Number of merge requests that has to be associated to every Security Issue
      MERGE_REQUESTS_SIZE = 4

      # Internal ID of GitLab Release Bot
      GITLAB_RELEASE_BOT_ID = 2_324_599

      # Format of stable branches on GitLab repos
      STABLE_BRANCH_REGEX = /^(\d+-\d+-stable(-ee)?)$/.freeze

      attr_reader :project_id, :iid, :merge_requests, :web_url

      def initialize(project_id, iid, merge_requests, web_url)
        @project_id = project_id
        @iid = iid
        @merge_requests = merge_requests
        @web_url = web_url
      end

      def merge_requests_ready?
        merge_requests.length >= MERGE_REQUESTS_SIZE &&
          merge_requests_assigned_to_the_bot?
      end

      def merge_request_targeting_master
        merge_requests
          .detect { |merge_request| merge_request.target_branch == 'master' }
      end

      def merge_requests_targeting_stable
        merge_requests
          .select { |merge_request| merge_request.target_branch.match?(STABLE_BRANCH_REGEX) }
      end

      private

      def merge_requests_assigned_to_the_bot?
        merge_requests.all? do |merge_request|
          merge_request
            .assignees
            .map { |assignee| assignee.transform_keys(&:to_sym)[:id] }.include?(GITLAB_RELEASE_BOT_ID)
        end
      end
    end
  end
end
