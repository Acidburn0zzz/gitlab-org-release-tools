require 'active_support'
require 'active_support/core_ext/date'
require 'active_support/core_ext/date_time'
require 'active_support/core_ext/hash/transform_values'
require 'active_support/core_ext/integer'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/indent'
require 'active_support/core_ext/string/inflections'
require 'active_support/inflector'
require 'cgi'
require 'colorize'
require 'date'
require 'erb'
require 'etc'
require 'fileutils'
require 'forwardable'
require 'gitlab'
require 'http'
require 'json'
require 'open3'
require 'ostruct'
require 'parallel'
require 'rugged'
require 'semantic_logger'
require 'set'
require 'stringio'
require 'time'
require 'uri'
require 'yaml'
require 'retriable'

$LOAD_PATH.unshift(__dir__)

require 'release_tools/version'
require 'release_tools/project/base_project'
require 'release_tools/project/cng_image'
require 'release_tools/project/deployer'
require 'release_tools/project/gitaly'
require 'release_tools/project/gitlab_ce'
require 'release_tools/project/gitlab_ee'
require 'release_tools/project/gitlab_elasticsearch_indexer'
require 'release_tools/project/gitlab_pages'
require 'release_tools/project/gitlab_provisioner'
require 'release_tools/project/gitlab_shell'
require 'release_tools/project/gitlab_workhorse'
require 'release_tools/project/helm_gitlab'
require 'release_tools/project/merge_train'
require 'release_tools/project/omnibus_gitlab'
require 'release_tools/project/release/tasks'
require 'release_tools/project/release_tools'

require 'release_tools/shared_status'
require 'release_tools/feature'
require 'release_tools/logger'
require 'release_tools/preflight'

require 'release_tools/auto_deploy/naming'
require 'release_tools/auto_deploy/builder/cng_image'
require 'release_tools/auto_deploy/builder/omnibus'
require 'release_tools/auto_deploy/tagger/release_metadata_tracking'
require 'release_tools/auto_deploy/tagger/cng_image'
require 'release_tools/auto_deploy/tagger/helm'
require 'release_tools/auto_deploy/tagger/omnibus'
require 'release_tools/auto_deploy/version'
require 'release_tools/auto_deploy_branch'
require 'release_tools/branch'
require 'release_tools/branch_creation'
require 'release_tools/branch_status'
require 'release_tools/changelog'
require 'release_tools/changelog/config'
require 'release_tools/changelog/entry'
require 'release_tools/changelog/manager'
require 'release_tools/changelog/markdown_generator'
require 'release_tools/changelog/updater'
require 'release_tools/cherry_pick'
require 'release_tools/cherry_pick/comment_notifier'
require 'release_tools/cherry_pick/console_notifier'
require 'release_tools/cherry_pick/result'
require 'release_tools/cherry_pick/service'
require 'release_tools/cng_version'
require 'release_tools/commits'
require 'release_tools/component_versions'
require 'release_tools/deployments/deployment_version_parser'
require 'release_tools/deployments/omnibus_deployment_version_parser'
require 'release_tools/deployments/deployment_tracker'
require 'release_tools/deployments/merge_request_labeler'
require 'release_tools/deployments/merge_request_updater'
require 'release_tools/deployments/released_merge_request_notifier'
require 'release_tools/deployments/metadata'
require 'release_tools/deployments/sentry_tracker'
require 'release_tools/gemfile_parser'
require 'release_tools/gitlab_client'
require 'release_tools/gitlab_dev_client'
require 'release_tools/gitlab_ops_client'
require 'release_tools/helm/chart_file'
require 'release_tools/helm/version_manager'
require 'release_tools/helm_chart_version'
require 'release_tools/helm_gitlab_version'
require 'release_tools/issuable'
require 'release_tools/issue'
require 'release_tools/merge_request'
require 'release_tools/monthly_issue'
require 'release_tools/omnibus_gitlab_version'
require 'release_tools/passing_build'
require 'release_tools/patch_issue'
require 'release_tools/pick_into_label'
require 'release_tools/pipeline'
require 'release_tools/preparation_merge_request'
require 'release_tools/qa'
require 'release_tools/qa/formatters/merge_requests_formatter'
require 'release_tools/qa/issuable_omitter_by_labels'
require 'release_tools/qa/issuable_sort_by_labels'
require 'release_tools/qa/issue'
require 'release_tools/qa/issue_closer'
require 'release_tools/qa/issue_presenter'
require 'release_tools/qa/merge_requests'
require 'release_tools/qa/project_changeset'
require 'release_tools/qa/ref'
require 'release_tools/qa/security_issue'
require 'release_tools/qa/services/build_qa_issue_service'
require 'release_tools/qa/username_extractor'
require 'release_tools/release'
require 'release_tools/release/base_release'
require 'release_tools/release/gitlab_based_release'
require 'release_tools/release/auto_deployed_component_release'
require 'release_tools/release/cng_image_release'
require 'release_tools/release/gitaly_release'
require 'release_tools/release/gitlab_ce_release'
require 'release_tools/release/gitlab_ee_release'
require 'release_tools/release/helm_gitlab_release'
require 'release_tools/release/omnibus_gitlab_release'
require 'release_tools/release_managers/client'
require 'release_tools/release_managers/definitions'
require 'release_tools/release_managers/sync_result'
require 'release_tools/release_managers/schedule'
require 'release_tools/release_metadata'
require 'release_tools/release_metadata_uploader'
require 'release_tools/remote_repository'
require 'release_tools/security_patch_issue'
require 'release_tools/services/auto_deploy_branch_service'
require 'release_tools/services/component_update_service'
require 'release_tools/services/monthly_preparation_service'
require 'release_tools/services/publish_service/base_publish_service'
require 'release_tools/services/publish_service/cng_publish_service'
require 'release_tools/services/publish_service/omnibus_publish_service'
require 'release_tools/services/sync_remotes_service'
require 'release_tools/slack/webhook'
require 'release_tools/slack/channel'
require 'release_tools/slack/auto_deploy_notification'
require 'release_tools/slack/chatops_notification'
require 'release_tools/slack/tag_notification'
require 'release_tools/support/tasks_helper'
require 'release_tools/time_util'
require 'release_tools/security/client'
require 'release_tools/security/cherry_picker'
require 'release_tools/security/dev_client'
require 'release_tools/security/implementation_issue'
require 'release_tools/security/issue_result'
require 'release_tools/security/pipeline'
require 'release_tools/security/projects_validator'
require 'release_tools/security/merge_requests_validator'
require 'release_tools/security/merge_request_validator'
require 'release_tools/security/merge_requests_batch_merger'
require 'release_tools/security/merge_result'
require 'release_tools/security/mirrors'
require 'release_tools/security/issue_crawler'
require 'release_tools/version_client'
require 'release_tools/versions'
require 'release_tools/automatic_release_candidate'

ReleaseTools::Preflight.check
