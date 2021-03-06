# frozen_string_literal: true

module ReleaseTools
  module Release
    class GitalyRelease < AutoDeployedComponentRelease
      private

      def project
        Project::Gitaly
      end

      def release_name
        'gitaly'
      end

      def bump_versions
        super

        file_name = 'ruby/proto/gitaly/version.rb'
        content = <<~PROTO_VERSION
          # This file was auto-generated by release-tools
          #  https://gitlab.com/gitlab-org/release-tools/-/blob/master/lib/release_tools/release/gitaly_release.rb
          module Gitaly
            VERSION = '#{version}'
          end
        PROTO_VERSION

        return if File.read(File.join(repository.path, file_name)).chomp == content.chomp

        logger.info('Bumping gitaly gem version', file_name: file_name, version: version)

        repository.write_file(file_name, content)

        # amend the version bump commit
        repository.commit(file_name, amend: true, no_edit: true)
      end
    end
  end
end
