# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Release::GitlabCeRelease, :slow do
  include RuggedMatchers

  # NOTE (rspeicher): There is some "magic" here that can be confusing.
  #
  # The release process checks out a remote to `/tmp/some_folder`, where
  # `some_folder` is based on the last part of a remote path, excluding `.git`.
  #
  # So `https://gitlab.com/foo/bar/repository.git` gets checked out to
  # `/tmp/repository`, and `/this/project/spec/fixtures/repositories/release`
  # gets checked out to `/tmp/release`.
  let(:repo_path)        { File.join(Dir.tmpdir, ReleaseFixture.repository_name) }
  let(:ob_repo_path)     { File.join(Dir.tmpdir, OmnibusReleaseFixture.repository_name) }
  let(:gitaly_repo_path) { File.join(Dir.tmpdir, GitalyReleaseFixture.repository_name) }

  # These three Rugged repositories are used for _verifying the result_ of the
  # release run. Not to be confused with the fixture repositories.
  let(:repository)        { Rugged::Repository.new(repo_path) }
  let(:ob_repository)     { Rugged::Repository.new(ob_repo_path) }
  let(:gitaly_repository) { Rugged::Repository.new(gitaly_repo_path) }

  # When enabled, operate as a security release
  let(:security_release) { false }

  before do
    cleanup!

    fixture        = ReleaseFixture.new
    ob_fixture     = OmnibusReleaseFixture.new
    gitaly_fixture = GitalyReleaseFixture.new

    enable_feature(:security_remote)
    enable_feature(:gitaly_tagging)
    allow(ReleaseTools::SharedStatus).to receive(:security_release?)
      .and_return(security_release)

    gitaly_fixture.rebuild_fixture!
    last_gitaly_commit = gitaly_fixture.repository.head.target_id

    fixture.rebuild_fixture!(gitaly_version: last_gitaly_commit)
    ob_fixture.rebuild_fixture!

    # Disable cleanup so that we can see what's the state of the temp Git repos
    allow_any_instance_of(ReleaseTools::RemoteRepository)
      .to receive(:cleanup)
      .and_return(true)

    # Override the actual remotes with our local fixture repositories
    allow_any_instance_of(described_class).to receive(:remotes)
      .and_return({ canonical: "file://#{fixture.fixture_path}" })

    allow_any_instance_of(ReleaseTools::Release::OmnibusGitlabRelease).to receive(:remotes)
      .and_return({ canonical: "file://#{ob_fixture.fixture_path}" })

    allow_any_instance_of(ReleaseTools::Release::GitalyRelease).to receive(:remotes)
      .and_return({ canonical: "file://#{gitaly_fixture.fixture_path}" })
  end

  after do
    cleanup!
  end

  def gitaly_stable_branch(version)
    ReleaseTools::Version.new(version).to_ce.stable_branch
  end

  def cleanup!
    # Manually perform the cleanup we disabled in the `before` block
    FileUtils.rm_rf(repo_path,    secure: true) if File.exist?(repo_path)
    FileUtils.rm_rf(ob_repo_path, secure: true) if File.exist?(ob_repo_path)
    FileUtils.rm_rf(gitaly_repo_path, secure: true) if File.exist?(gitaly_repo_path)
  end

  def execute(version, branch)
    cng_spy = spy
    meta = ReleaseTools::ReleaseMetadata.new

    allow(meta)
      .to receive(:add_auto_deploy_components)
      .with(an_instance_of(Hash))

    stub_const('ReleaseTools::Release::CNGImageRelease', cng_spy)

    described_class.new(version, release_metadata: meta).execute

    expect(cng_spy).to have_received(:execute)
    expect(meta).to have_received(:add_auto_deploy_components)

    repository.checkout(branch)
    ob_repository.checkout(branch)
    gitaly_repository.checkout(gitaly_stable_branch(version)) if Dir.exist?(gitaly_repo_path)
  end

  describe '#execute' do
    let(:changelog_manager) { double(release: true) }
    let(:ob_changelog_manager) { double(release: true) }
    let(:gitaly_changelog_manager) { double(release: true) }

    before do
      allow(ReleaseTools::Changelog::Manager).to receive(:new).with(repo_path).and_return(changelog_manager)
      allow(ReleaseTools::Changelog::Manager).to receive(:new).with(ob_repo_path, 'CHANGELOG.md').and_return(ob_changelog_manager)
      allow(ReleaseTools::Changelog::Manager).to receive(:new).with(gitaly_repo_path, 'CHANGELOG.md', exclude_date: true).and_return(gitaly_changelog_manager)
    end

    { ce: '', ee: '-ee' }.each do |edition, suffix|
      context 'with a security release' do
        let(:security_release) { true }
        let(:version) { "9.1.24#{suffix}" }
        let(:ob_version) { "9.1.24+#{edition}.0" }
        let(:gitaly_version) { '9.1.24' }

        it "does not prefix all branches" do
          branch = "9-1-stable#{suffix}"
          gitaly_branch = gitaly_stable_branch(version)

          execute(version, branch)

          aggregate_failures do
            expect(repository.branches.collect(&:name))
              .to include('master', branch)
            expect(repository.head.name).to eq "refs/heads/#{branch}"
            expect(repository.branches['master']).not_to be_nil
            expect(repository.branches['security/master']).to be_nil
            expect(repository.tags["v#{version}"]).not_to be_nil

            expect(gitaly_repository.branches.collect(&:name))
              .to include('master', gitaly_branch)
            expect(gitaly_repository.head.name).to eq "refs/heads/#{gitaly_branch}"
            expect(gitaly_repository.branches['master']).not_to be_nil
            expect(gitaly_repository.branches['security/master']).to be_nil
            expect(gitaly_repository.tags["v#{gitaly_version}"]).not_to be_nil

            expect(ob_repository.branches.collect(&:name))
              .to include('master', branch)
            expect(ob_repository.head.name).to eq "refs/heads/#{branch}"
            expect(ob_repository.branches['master']).not_to be_nil
            expect(ob_repository.branches['security/master']).to be_nil
            expect(ob_repository.tags[ob_version]).not_to be_nil
          end
        end
      end

      context "with an existing 9-1-stable#{suffix} stable branch, releasing a patch" do
        let(:version) { "9.1.24#{suffix}" }
        let(:ob_version) { "9.1.24+#{edition}.0" }
        let(:gitaly_version) { '9.1.24' }
        let(:branch) { "9-1-stable#{suffix}" }
        let(:gitaly_branch) { gitaly_stable_branch(version) }

        describe "release GitLab#{suffix.upcase}" do
          it 'performs changelog compilation' do
            expect(changelog_manager).to receive(:release).with(version)
            execute(version, branch)
          end

          it 'creates a new branch and updates the version in VERSION, and creates a new branch, a new tag and updates the version files in the omnibus-gitlab repo' do
            execute(version, branch)

            aggregate_failures do
              # GitLab expectations
              expect(repository.head.name).to eq "refs/heads/#{branch}"
              expect(repository).to have_version.at(version)
              expect(repository.tags["v#{version}"]).not_to be_nil

              # Gitaly expectations
              expect(gitaly_repository.head.name).to eq "refs/heads/#{gitaly_branch}"
              expect(gitaly_repository).to have_version.at(gitaly_version)
              expect(gitaly_repository.tags["v#{gitaly_version}"]).not_to be_nil

              # Omnibus-GitLab expectations
              expect(ob_repository.head.name).to eq "refs/heads/#{branch}"
              expect(ob_repository.tags[ob_version]).not_to be_nil
              expect(ob_repository).to have_version.at(version)
              expect(ob_repository).to have_version('shell').at('2.2.2')
              expect(ob_repository).to have_version('workhorse').at('3.3.3')
              expect(ob_repository).to have_version('pages').at('4.4.4')
              expect(ob_repository).to have_version('gitaly').at(gitaly_version)
            end
          end

          it 'does not fail if the tag already exists' do
            # Make sure we have the repository to create a conflicting tag
            described_class.new(version).__send__(:prepare_release)
            repository.tags.create("v#{version}", 'HEAD')

            expect(repository.tags["v#{version}"]).not_to be_nil
            expect { execute(version, branch) }.not_to raise_error
          end

          it 'does not fail when running twice' do
            expect { execute(version, branch) }.not_to raise_error
          end
        end
      end

      context "with a new 10-1-stable#{suffix} stable branch, releasing an RC" do
        let(:version) { "10.1.0-rc13#{suffix}" }
        let(:ob_version) { "10.1.0+rc13.#{edition}.0" }
        let(:gitaly_version) { GitalyReleaseFixture.new.repository.head.target_id }
        let(:branch) { "10-1-stable#{suffix}" }
        let(:gitaly_branch) { gitaly_stable_branch(version) }

        describe "release GitLab#{suffix.upcase}" do
          it 'does not perform changelog compilation' do
            expect(ReleaseTools::Changelog::Manager).not_to receive(:new)

            execute(version, branch)
          end

          it 'creates a new branch and updates the version in VERSION, and creates a new branch, a new tag and updates the version files in the omnibus-gitlab repo' do
            execute(version, branch)

            aggregate_failures do
              # GitLab expectations
              expect(repository.head.name).to eq "refs/heads/#{branch}"
              expect(repository).to have_version.at(version)

              # Gitaly expectations
              expect(Dir.exist?(gitaly_repo_path)).to be_falsey # rubocop:disable RSpec/PredicateMatcher

              # Omnibus-GitLab expectations
              expect(ob_repository.head.name).to eq "refs/heads/#{branch}"
              expect(ob_repository.tags[ob_version]).not_to be_nil
              expect(ob_repository).to have_version.at(version)
              expect(ob_repository).to have_version('shell').at('2.3.0')
              expect(ob_repository).to have_version('workhorse').at('3.4.0')
              expect(ob_repository).to have_version('pages').at('4.5.0')
              expect(ob_repository).to have_version('gitaly').at(gitaly_version)
            end
          end
        end
      end

      context "with a new 10-1-stable#{suffix} stable branch, releasing a stable .0" do
        let(:version) { "10.1.0#{suffix}" }
        let(:ob_version) { "10.1.0+#{edition}.0" }
        let(:gitaly_version) { '10.1.0' }
        let(:branch) { "10-1-stable#{suffix}" }
        let(:gitaly_branch) { gitaly_stable_branch(version) }

        describe "release GitLab#{suffix.upcase}" do
          it 'performs changelog compilation' do
            expect(changelog_manager).to receive(:release).with(version)

            execute(version, branch)
          end

          it 'creates a new branch and updates the version in VERSION, and creates a new branch, a new tag and updates the version files in the omnibus-gitlab repo' do
            execute(version, branch)

            aggregate_failures do
              # GitLab expectations
              expect(repository.head.name).to eq "refs/heads/#{branch}"
              expect(repository).to have_version.at(version)

              repository.checkout('master')

              if edition == :ee
                expect(repository).to have_version.at('1.2.0')
                expect(repository.tags['v10.1.0-ee']).not_to be_nil
              else
                expect(repository).to have_version.at('10.2.0-pre')
                expect(repository.tags['v10.2.0.pre']).not_to be_nil
              end

              # Gitaly expectations
              expect(gitaly_repository.head.name).to eq "refs/heads/#{gitaly_branch}"
              expect(gitaly_repository).to have_version.at(gitaly_version)
              gitaly_repository.checkout('master')
              expect(gitaly_repository).to have_version.at(gitaly_version)

              # Omnibus-GitLab expectations
              expect(ob_repository.head.name).to eq "refs/heads/#{branch}"
              expect(ob_repository.tags[ob_version]).not_to be_nil
              expect(ob_repository).to have_version.at(version)
              expect(ob_repository).to have_version('shell').at('2.3.0')
              expect(ob_repository).to have_version('workhorse').at('3.4.0')
              expect(ob_repository).to have_version('pages').at('4.5.0')
              expect(ob_repository).to have_version('gitaly').at(gitaly_version)
            end
          end
        end
      end
    end
  end
end
