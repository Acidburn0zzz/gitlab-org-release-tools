require 'colorize'
require 'dotenv'
Dotenv.load

require_relative 'lib/version'
require_relative 'lib/project/gitlab_ce'
require_relative 'lib/project/gitlab_ee'
require_relative 'lib/project/omnibus_gitlab'
require_relative 'lib/monthly_issue'
require_relative 'lib/patch_issue'
require_relative 'lib/branch'
require_relative 'lib/patch_preparation_merge_request'
require_relative 'lib/regression_issue'
require_relative 'lib/merge_request'
require_relative 'lib/security_patch_issue'
require_relative 'lib/release/gitlab_ce_release'
require_relative 'lib/release/gitlab_ee_release'
require_relative 'lib/sync'
