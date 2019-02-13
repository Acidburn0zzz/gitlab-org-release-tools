require 'colorize'
require 'dotenv'
Dotenv.load

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'shared_status'

unless ENV['TEST']
  require 'sentry-raven'

  Raven.user_context(
    git_user: SharedStatus.user,
    release_user: ENV['RELEASE_USER']
  )
end

require 'version'
require 'project'
require 'pick_into_label'
require 'cherry_pick'
require 'monthly_issue'
require 'patch_issue'
require 'packages'
require 'qa'
require 'qa/services/build_qa_issue_service'
require 'qa/issue_closer'
require 'branch'
require 'preparation_merge_request'
require 'merge_request'
require 'security_patch_issue'
require 'release/gitlab_ce_release'
require 'release/gitlab_ee_release'
require 'release/helm_gitlab_release'
require 'release_managers'
require 'services/upstream_merge_service'
require 'slack'
require 'sync'
require 'upstream_merge'
require 'upstream_merge_request'
