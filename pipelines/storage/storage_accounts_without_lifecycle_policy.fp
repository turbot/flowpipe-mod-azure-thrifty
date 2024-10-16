locals {
  storage_accounts_without_lifecycle_policy_query = <<-EOQ
    select
      concat(ac.id, ' [', ac.resource_group, '/', ac.subscription_id, ']') as title,
      ac.id as resource,
      ac.name,
      ac.subscription_id,
      ac.resource_group,
      ac.title,
      ac.sp_connection_name as conn
    from
      azure_storage_account as ac
      left join azure_subscription as sub on ac.subscription_id = sub.subscription_id
    where
      (ac.lifecycle_management_policy -> 'properties' -> 'policy' -> 'rules') is null;
  EOQ
}

trigger "query" "detect_and_correct_storage_accounts_without_lifecycle_policy" {
  title         = "Detect & correct Storage accounts without lifecycle policy"
  description   = "Detects Storage accounts without lifecycle policy and runs your chosen action."
  documentation = file("./pipelines/storage/docs/detect_and_correct_storage_accounts_without_lifecycle_policy_trigger.md")
  tags          = merge(local.storage_common_tags, { class = "unused" })

  enabled  = var.storage_accounts_without_lifecycle_policy_trigger_enabled
  schedule = var.storage_accounts_without_lifecycle_policy_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_without_lifecycle_policy_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_without_lifecycle_policy
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_without_lifecycle_policy" {
  title         = "Detect & correct Storage accounts without lifecycle policy"
  description   = "Detects Storage accounts without lifecycle policy and runs your chosen action."
  documentation = file("./pipelines/storage/docs/detect_and_correct_storage_accounts_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.storage_accounts_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_without_lifecycle_policy_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_accounts_without_lifecycle_policy_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_without_lifecycle_policy
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

pipeline "correct_storage_accounts_without_lifecycle_policy" {
  title         = "Correct Storage accounts without lifecycle policy"
  description   = "Runs corrective action on a collection of Storage accounts without lifecycle policy."
  documentation = file("./pipelines/storage/docs/correct_storage_accounts_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      resource_group  = string
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
    default     = var.storage_accounts_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_without_lifecycle_policy_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage Accounts without lifecycle policy."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_account_without_lifecycle_policy
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
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

pipeline "correct_one_storage_account_without_lifecycle_policy" {
  title         = "Correct one Storage account without lifecycle policy"
  description   = "Runs corrective action on Storage account without lifecycle policy."
  documentation = file("./pipelines/storage/docs/correct_one_storage_account_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Storage account."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
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
    default     = var.storage_accounts_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_without_lifecycle_policy_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Storage account ${param.title} without lifecycle policy."
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
            text     = "Skipped Storage account ${param.title} without lifecycle policy."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_storage_account" = {
          label        = "Delete Storage Account"
          value        = "delete_storage_account"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_storage_account
          pipeline_args = {
            account_name      = param.name
            resource_group   = param.resource_group
            subscription_id  = param.subscription_id
            conn             = param.conn
          }
          success_msg = "Deleted Storage account ${param.title}."
          error_msg   = "Error deleting Storage account ${param.title}."
        }
      }
    }
  }
}

variable "storage_accounts_without_lifecycle_policy_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_without_lifecycle_policy_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_without_lifecycle_policy_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_without_lifecycle_policy_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_storage_account"]
  tags = {
    folder = "Advanced/Storage"
  }
}
