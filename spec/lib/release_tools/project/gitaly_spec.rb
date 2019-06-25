# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::Gitaly do
  it_behaves_like 'project #remotes'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/gitaly' }
  end

  describe '.dev_path' do
    it { expect(described_class.dev_path).to eq 'gitlab/gitaly' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org' }
  end

  describe '.dev_group' do
    it { expect(described_class.dev_group).to eq 'gitlab' }
  end
end