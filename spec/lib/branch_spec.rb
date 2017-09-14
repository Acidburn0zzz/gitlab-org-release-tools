require 'spec_helper'

require 'branch'

describe Branch do
  let(:branch) { described_class.new(name: 'release-tools-create-branch', project: Project::GitlabCe) }

  describe 'create', vcr: { cassette_name: 'branches/create' } do
    it 'creates a new branch in the given project' do
      expect(branch.create(ref: '9-4-stable')).to be_truthy
    end

    it 'points the branch to the correct ref' do
      response = branch.create(ref: '9-4-stable')

      expect(response.commit.short_id).to eq 'b125d211'
    end
  end
end