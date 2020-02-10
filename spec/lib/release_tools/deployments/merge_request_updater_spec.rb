# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Deployments::MergeRequestUpdater do
  describe '.for_successful_deployments' do
    it 'returns a MergeRequestUpdater operating only on successful deployments' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe, 1, 'failed')

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:deployed_merge_requests)

      described_class.for_successful_deployments([deploy]).add_comment('foo')
    end
  end

  describe '#add_comment' do
    it 'adds a comment to every deployed merge request' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe, 1, 'success')

      mr1 = double(:merge_request, project_id: 2, iid: 3)
      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_comment)
        .with(2, 3, 'foo')

      described_class.new([deploy]).add_comment('foo')
    end

    it 'retries retrieving of merge requests when this fails' do
      stub_const(
        'ReleaseTools::Deployments::MergeRequestUpdater::RETRY_INTERVAL',
        0
      )

      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe, 1, 'success')

      page1_raised = false
      page2_raised = false

      mr1 = double(:merge_request, project_id: 2, iid: 3, labels: %w[foo])
      mr2 = double(:merge_request, project_id: 2, iid: 4, labels: %w[bar])

      page1 = Gitlab::PaginatedResponse.new([mr1])
      page2 = Gitlab::PaginatedResponse.new([mr2])

      allow(ReleaseTools::GitlabClient).to receive(:deployed_merge_requests) do
        if page1_raised
          page1
        else
          page1_raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      allow(page1).to receive(:has_next_page?).and_return(true)

      allow(page1).to receive(:next_page) do
        if page2_raised
          page2
        else
          page2_raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      expect(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_comment)
        .with(2, 3, 'foo')

      expect(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_comment)
        .with(2, 4, 'foo')

      described_class.new([deploy]).add_comment('foo')
    end
  end
end
