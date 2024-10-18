locals {
  monitor_log_profiles_without_retention_policy_query = <<-EOQ
  select
    concat(lp.id, ' [', sub.subscription_id, ']') as title,
    lp.name,
    lp.subscription_id,
    lp.title,
    lp.sp_connection_name as conn
  from
    azure_log_profile as lp
    left join azure_subscription as sub on lp.subscription_id = sub.subscription_id
  where
    lp.retention_policy ->> 'enabled' <> 'true';
  EOQ

  monitor_log_profiles_without_retention_policy_default_action_enum  = ["notify", "skip", "enable_log_profile_retention"]
  monitor_log_profiles_without_retention_policy_enabled_actions_enum = ["skip", "enable_log_profile_retention"]
}

variable "monitor_log_profiles_without_retention_policy_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "monitor_log_profiles_without_retention_policy_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "monitor_log_profiles_without_retention_policy_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "enable_log_profile_retention"]
  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "monitor_log_profiles_without_retention_policy_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_log_profile_retention"]
  enum        = ["skip", "enable_log_profile_retention"]
  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_monitor_log_profiles_without_retention_policy" {
  title         = "Detect & correct Monitor log profiles without retention policy"
  description   = "Detects Monitor log profiles without retention policy and runs your chosen action."
  documentation = file("./pipelines/monitor/docs/detect_and_correct_monitor_log_profiles_without_retention_policy_trigger.md")
  tags          = merge(local.monitor_common_tags, { class = "unused" })

  enabled  = var.monitor_log_profiles_without_retention_policy_trigger_enabled
  schedule = var.monitor_log_profiles_without_retention_policy_trigger_schedule
  database = var.database
  sql      = local.monitor_log_profiles_without_retention_policy_query

  capture "insert" {
    pipeline = pipeline.correct_monitor_log_profiles_without_retention_policy
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_monitor_log_profiles_without_retention_policy" {
  title         = "Detect & correct Monitor log profiles without retention policy"
  description   = "Detects Monitor log profiles without retention policy and runs your chosen action."
  documentation = file("./pipelines/monitor/docs/detect_and_correct_monitor_log_profiles_without_retention_policy.md")
  tags          = merge(local.monitor_common_tags, { class = "unused", recommended = "true" })

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_log_profiles_without_retention_policy_default_action
    enum        = local.monitor_log_profiles_without_retention_policy_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_profiles_without_retention_policy_enabled_actions
    enum        = local.monitor_log_profiles_without_retention_policy_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.monitor_log_profiles_without_retention_policy_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_monitor_log_profiles_without_retention_policy
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_monitor_log_profiles_without_retention_policy" {
  title         = "Correct Monitor log profiles without retention policy"
  description   = "Runs corrective action on a collection of Monitor log profiles without retention policy."
  documentation = file("./pipelines/monitor/docs/correct_monitor_log_profiles_without_retention_policy.md")
  tags          = merge(local.monitor_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      subscription_id = string
      conn            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_log_profiles_without_retention_policy_default_action
    enum        = local.monitor_log_profiles_without_retention_policy_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_profiles_without_retention_policy_enabled_actions
    enum        = local.monitor_log_profiles_without_retention_policy_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Monitor Log Profiles without retention policy."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_monitor_log_profile_without_retention_policy
    args = {
      title              = each.value.title
      name               = each.value.name
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_monitor_log_profile_without_retention_policy" {
  title         = "Correct one Monitor log profile without retention policy"
  description   = "Runs corrective action on a Monitor log profile without retention policy."
  documentation = file("./pipelines/monitor/docs/correct_one_monitor_log_profile_without_retention_policy.md")
  tags          = merge(local.monitor_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Monitor Log Profile."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "conn" {
    type        = connection.azure
    description = local.description_connection
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_log_profiles_without_retention_policy_default_action
    enum        = local.monitor_log_profiles_without_retention_policy_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_profiles_without_retention_policy_enabled_actions
    enum        = local.monitor_log_profiles_without_retention_policy_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Monitor log profile ${param.title} without retention policy."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped Monitor log profile ${param.title} without retention policy."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_log_profile_retention" = {
          label        = "Enable Log Profile Retention"
          value        = "enable_log_profile_retention"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_monitor_log_profile_retention_policy
          pipeline_args = {
            log_profile_name  = param.name
            subscription_id   = param.subscription_id
            retention_enabled = true
            location          = "global"
            retention_days    = 365
            conn              = param.conn
          }
          success_msg = "Updated Monitor log profile ${param.title}."
          error_msg   = "Error updating Monitor log profile ${param.title}."
        }
      }
    }
  }
}
