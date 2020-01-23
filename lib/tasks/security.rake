namespace :security do
  # Undocumented; should be a pre-requisite for every task in this namespace!
  task :force_security do
    unless ReleaseTools::SharedStatus.critical_security_release?
      ENV['SECURITY'] = 'true'
    end
  end

  desc 'Create a security release task issue'
  task :issue, [:version] => :force_security do |_t, args|
    version = get_version(args)

    issue = ReleaseTools::SecurityPatchIssue.new(version: version)

    create_or_show_issue(issue)
  end

  desc 'Merges valid security merge requests'
  task :merge, [:merge_master] => :force_security do |_t, args|
    merge_master =
      if args[:merge_master] && !args[:merge_master].empty?
        true
      else
        false
      end

    client = ReleaseTools::Security::DevClient.new

    ReleaseTools::Security::MergeRequestsMerger
      .new(client, merge_master: merge_master)
      .execute

    if ReleaseTools::Feature.enabled?(:security_remote)
      if ReleaseTools::Feature.enabled?(:security_mirror_toggle)
        ReleaseTools::Security::Mirrors.disable
      end

      client = ReleaseTools::Security::Client.new

      ReleaseTools::Security::MergeRequestsMerger
        .new(client, merge_master: merge_master)
        .execute
    end
  end

  desc 'Prepare for a new security release'
  task :prepare, [:version] => :force_security do |_t, _args|
    issue_task = Rake::Task['security:issue']

    ReleaseTools::Versions.next_security_versions.each do |version|
      issue_task.execute(version: version)
    end
  end

  desc 'Create a security QA issue'
  task :qa, [:from, :to] => :force_security do |_t, args|
    Rake::Task['release:qa'].invoke(*args)
  end

  desc "Check a security release's build status"
  task status: :force_security do |t, _args|
    status = ReleaseTools::BranchStatus.for_security_release

    status.each_pair do |project, results|
      results.each do |result|
        ReleaseTools.logger.tagged(t.name) do
          ReleaseTools.logger.info(project, result.to_h)
        end
      end
    end

    ReleaseTools::Slack::ChatopsNotification.branch_status(status)
  end

  desc 'Tag a new security release'
  task :tag, [:version] => :force_security do |_t, args|
    $stdout
      .puts "Security Release - using security repository only!\n"
      .colorize(:red)

    Rake::Task['release:tag'].invoke(*args)
  end

  desc 'Validates security merge requests'
  task validate: :force_security do
    ReleaseTools::Security::MergeRequestsValidator
      .new(ReleaseTools::Security::DevClient.new)
      .execute

    if ReleaseTools::Feature.enabled?(:security_remote)
      ReleaseTools::Security::MergeRequestsValidator
        .new(ReleaseTools::Security::Client.new)
        .execute
    end
  end

  namespace :gitaly do
    desc 'Tag a new Gitaly security release'
    task :tag, [:version] => :force_security do |_, args|
      version = get_version(args)

      ReleaseTools::Release::GitalyRelease.new(version).execute
      ReleaseTools::Slack::TagNotification.release(version) unless dry_run?
    end
  end
end
