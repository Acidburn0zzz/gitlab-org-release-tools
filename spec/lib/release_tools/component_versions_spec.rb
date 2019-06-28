# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ComponentVersions do
  let(:fake_client) { spy }

  before do
    stub_const('ReleaseTools::GitlabClient', fake_client)
  end

  describe '.get' do
    it 'returns a Hash of component versions' do
      project = ReleaseTools::Project::GitlabEe
      commit_id = 'abcdefg'
      file = described_class::FILES.sample

      allow(fake_client).to receive(:project_path).and_return(project.path)
      expect(fake_client).to receive(:file_contents)
        .with(project.path, file, commit_id)
        .and_return("1.2.3\n")

      expect(described_class.get(project, commit_id)).to match(
        a_hash_including(
          'VERSION' => commit_id,
          file => '1.2.3'
        )
      )
    end
  end

  describe '.update_omnibus' do
    let(:project) { ReleaseTools::Project::OmnibusGitlab }
    let(:version_map) do
      {
        'GITALY_SERVER_VERSION' => '1.33.0',
        'GITLAB_PAGES_VERSION' => '1.5.0',
        'GITLAB_SHELL_VERSION' => '9.0.0',
        'GITLAB_WORKHORSE_VERSION' => '8.6.0',
        'VERSION' => '0cfa69752d82b8e134bdb8e473c185bdae26ccc2'
      }
    end
    let(:commit) { double('commit', id: 'abcd') }

    it 'commits version updates for the specified ref' do
      allow(fake_client).to receive(:project_path).and_return(project.path)

      without_dry_run do
        described_class.update_omnibus('foo-branch', version_map)
      end

      expect(fake_client).to have_received(:create_commit).with(
        project.path,
        'foo-branch',
        anything,
        array_including(
          action: 'update',
          file_path: '/VERSION',
          content: "#{version_map['VERSION']}\n"
        )
      )
    end
  end

  describe '.omnibus_version_changes?' do
    let(:project) { ReleaseTools::Project::OmnibusGitlab }
    let(:version_map) { { 'GITALY_SERVER_VERSION' => '1.33.0' } }

    it 'keeps omnibus versions that have changed' do
      allow(fake_client).to receive(:project_path).and_return(project.path)

      expect(fake_client).to receive(:file_contents)
        .with(project.path, "/GITALY_SERVER_VERSION", 'foo-branch')
        .and_return("1.2.3\n")

      expect(described_class.omnibus_version_changes?('foo-branch', version_map)).to be(true)
    end

    it 'rejects omnibus versions that have not changed' do
      allow(fake_client).to receive(:project_path).and_return(project.path)

      expect(fake_client).to receive(:file_contents)
        .with(project.path, "/GITALY_SERVER_VERSION", 'foo-branch')
        .and_return("1.33.0\n")

      expect(described_class.omnibus_version_changes?('foo-branch', version_map)).to be(false)
    end
  end
end
