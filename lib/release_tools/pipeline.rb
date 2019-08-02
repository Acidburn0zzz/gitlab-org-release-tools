module ReleaseTools
  class Pipeline
    include ::SemanticLogger::Loggable

    attr_reader :project, :sha

    def initialize(project, sha, versions)
      @project = project
      @sha = sha
      @token = ENV.fetch('OMNIBUS_BUILD_TRIGGER_TOKEN') do |name|
        raise "Missing environment variable `#{name}`"
      end
      @versions = versions
    end

    def trigger
      logger.info('Trigger pipeline', project: project, sha: sha)

      trigger = ReleaseTools::GitlabDevClient.run_trigger(
        ReleaseTools::Project::OmnibusGitlab,
        @token,
        'master',
        build_variables
      )

      logger.info('Triggered pipeline', url: trigger.web_url)

      wait(trigger.id)
    end

    private

    def status(id)
      ReleaseTools::GitlabDevClient.pipeline(ReleaseTools::Project::OmnibusGitlab, id).status
    end

    def wait(id)
      interval = 60 # seconds
      max_duration = 3600 * 3 # 3 hours
      start = Time.now.to_i

      logger.info("Waiting on pipeline success", id: id, timeout: max_duration)

      logger.measure_info('Waiting for pipeline', metric: 'pipeline/waiting') do
        loop do
          if ReleaseTools::TimeUtil.timeout?(start, max_duration)
            raise "Pipeline timeout after waiting for #{max_duration} seconds."
          end

          case status(id)
          when 'created', 'pending', 'running'
            sleep(interval)
          when 'success'
            break
          else
            raise 'Pipeline did not succeed.'
          end
        end
      end
    end

    def build_variables
      @versions.merge(
        'GITLAB_VERSION' => @sha,
        'NIGHTLY' => 'true',
        'ee' => @project == ReleaseTools::Project::GitlabEe
      )
    end
  end
end
