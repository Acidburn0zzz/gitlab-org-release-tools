# frozen_string_literal: true

module ReleaseTools
  module Release
    class GitlabCeRelease < BaseRelease
      private

      def remotes
        Project::GitlabCe.remotes
      end

      def before_execute_hook
        compile_changelog

        super
      end

      def after_execute_hook
        Release::OmnibusGitlabRelease.new(
          version.to_omnibus(ee: version.ee?),
          options.merge(gitlab_repo_path: repository.path)
        ).execute

        begin
          Release::CNGImageRelease
            .new(version, options.merge(gitlab_repo_path: repository.path))
            .execute
        rescue StandardError => ex
          logger.fatal('CNG image release failed', error: ex.message)
        end
      end

      def after_release
        tag_next_minor_pre_version

        super
      end

      def compile_changelog
        return if version.rc?

        logger.info('Compiling changelog', version: version)

        Changelog::Manager.new(repository.path).release(version)
      rescue Changelog::NoChangelogError => ex
        logger.error('Changelog update failed', version: version, path: ex.changelog_path)
      end

      def tag_next_minor_pre_version
        return unless version.release? && version.patch.zero?

        repository.ensure_branch_exists(master_branch)
        repository.pull_from_all_remotes(master_branch)
        bump_version('VERSION', "#{version.next_minor}-pre")
        push_ref('branch', master_branch)

        next_minor_pre_tag = "v#{version.next_minor}.pre"
        create_tag(next_minor_pre_tag)
        push_ref('tag', next_minor_pre_tag)
      end
    end
  end
end
