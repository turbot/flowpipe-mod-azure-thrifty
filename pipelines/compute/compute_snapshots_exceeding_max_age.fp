locals {
  compute_snapshots_exceeding_max_age_query = <<-EOQ
  select
    concat(unique_id, ' [', s.resource_group, '/', s.subscription_id, ']') as title,
    s.name,
    s.resource_group,
    s.subscription_id,
    s.sp_connection_name as conn
  from
    azure_compute_snapshot as s,
    azure_subscription as sub
  where
    date_part('day', now()-time_created) > ${var.compute_snapshots_exceeding_max_age_days}
    and sub.subscription_id = s.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_compute_snapshots_exceeding_max_age" {
  title         = "Detect & correct Compute snapshots exceeding max age"
  description   = "Detects Compute snapshots exceeding max age and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_snapshots_exceeding_max_age_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_snapshots_exceeding_max_age_trigger_enabled
  schedule = var.compute_snapshots_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.compute_snapshots_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_compute_snapshots_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_snapshots_exceeding_max_age" {
  title         = "Detect & correct Compute snapshots exceeding max age"
  description   = "Detects Compute snapshots exceeding max age and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_snapshots_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.compute_snapshots_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_exceeding_max_age_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_snapshots_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_snapshots_exceeding_max_age
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

pipeline "correct_compute_snapshots_exceeding_max_age" {
  title         = "Correct Compute snapshots exceeding max age"
  description   = "Runs corrective action on a collection of Compute snapshots exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_compute_snapshots_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

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
    default     = var.compute_snapshots_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_exceeding_max_age_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute snapshots exceeding maximum age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_snapshot_exceeding_max_age
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

pipeline "correct_one_compute_snapshot_exceeding_max_age" {
  title         = "Correct one Compute snapshot exceeding max age"
  description   = "Runs corrective action on an Compute snapshot exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_one_compute_snapshot_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Compute snapshot."
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
    default     = var.compute_snapshots_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_exceeding_max_age_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute snapshot ${param.title} exceeding maximum age."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped Compute snapshot ${param.title} exceeding maximum age."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_snapshot" = {
          label        = "Delete Snapshot"
          value        = "delete_snapshot"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_compute_snapshot
          pipeline_args = {
            snapshot_name    = param.name
            resource_group   = param.resource_group
            subscription_id  = param.subscription_id
            conn             = param.conn
          }
          success_msg = "Deleted Compute snapshot ${param.title}."
          error_msg   = "Error deleting Compute snapshot ${param.title}."
        }
      }
    }
  }
}

variable "compute_snapshots_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_snapshots_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_snapshots_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_snapshots_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_snapshot"]
}

variable "compute_snapshots_exceeding_max_age_days" {
  type        = number
  description = "The maximum number of days Compute snapshots can be retained."
  default     = 90
}