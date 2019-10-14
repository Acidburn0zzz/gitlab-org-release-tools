# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::GitlabShell do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .security_group'
  it_behaves_like 'project .security_path', 'gitlab-org/security/gitlab-shell'
  it_behaves_like 'project .to_s'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/gitlab-shell' }
  end

  describe '.dev_path' do
    it { expect(described_class.dev_path).to eq 'gitlab/gitlab-shell' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org' }
  end

  describe '.dev_group' do
    it { expect(described_class.dev_group).to eq 'gitlab' }
  end

  describe '.version_file' do
    it { expect(described_class.version_file).to eq 'GITLAB_SHELL_VERSION' }
  end
end
