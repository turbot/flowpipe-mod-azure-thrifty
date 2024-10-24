locals {
  compute_disks_with_low_usage_query = <<-EOQ
    with disk_usage as (
      select
        name,
        resource_group
        subscription_id,
        round(avg(max)) as avg_max,
        count(max) as days
      from
        (
          select
            name,
            resource_group,
            subscription_id,
            cast(maximum as numeric) as max
          from
            azure_compute_disk_metric_read_ops_daily
          where
            date_part('day', now() - timestamp) <= 30
          union all
          select
            name,
            resource_group,
            subscription_id,
            cast(maximum as numeric) as max
          from
            azure_compute_disk_metric_write_ops_daily
          where
            date_part('day', now() - timestamp) <= 30
        ) as read_and_write_ops
      group by
        name,
        resource_group,
        subscription_id
    )
    select
      concat(d.id, ' [', d.resource_group, '/', d.subscription_id, ']') as resource,
      d.name as disk_name,
      u.avg_max,
      d.name || ' averaging ' || avg_max || ' read and write ops over the last ' || days / 2 || ' days.' as title,
      u.resource_group,
      u.subscription_id,
      d.sp_connection_name as conn
    from
      disk_usage as u left join azure_compute_disk as d on u.name = d.name
      left join azure_subscription as sub on sub.subscription_id = d.subscription_id
    where
      u.avg_max <= ${var.compute_disk_avg_max_usage};
  EOQ

  compute_disks_with_low_usage_default_action_enum  = ["notify", "skip", "delete_disk"]
  compute_disks_with_low_usage_enabled_actions_enum = ["skip", "delete_disk"]
}

variable "compute_disks_with_low_usage_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_low_usage_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_low_usage_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_low_usage_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk"]
  enum        = ["skip", "delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disk_avg_max_usage" {
  type        = number
  description = "The compute disks average read and write operations."
  default     = 90
  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_disks_with_low_usage" {
  title         = "Detect & correct Compute disks with low usage"
  description   = "Detects Compute disks with low usage and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_low_usage_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_with_low_usage_trigger_enabled
  schedule = var.compute_disks_with_low_usage_trigger_schedule
  database = var.database
  sql      = local.compute_disks_with_low_usage_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_with_low_usage
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_with_low_usage" {
  title         = "Detect & correct Compute disk with low usage"
  description   = "Detects Compute disk with low usage."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_low_usage.md")
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_with_low_usage_default_action
    enum        = local.compute_disks_with_low_usage_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
    enum        = local.compute_disks_with_low_usage_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_with_low_usage_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_with_low_usage
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

pipeline "correct_compute_disks_with_low_usage" {
  title         = "Correct Compute disks with low usage"
  description   = "Runs corrective action on a collection of Compute Disks with low usage."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_with_low_usage.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      disk_name       = string
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_with_low_usage_default_action
    enum        = local.compute_disks_with_low_usage_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
    enum        = local.compute_disks_with_low_usage_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disks with low usage."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.disk_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_with_low_usage
    args = {
      title              = each.value.title
      disk_name          = each.value.disk_name
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

pipeline "correct_one_compute_disk_with_low_usage" {
  title         = "Correct one Compute disk with low usage"
  description   = "Runs corrective action on a Compute disk with low usage."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_with_low_usage.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_with_low_usage_default_action
    enum        = local.compute_disks_with_low_usage_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
    enum        = local.compute_disks_with_low_usage_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.title}."
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
            text     = "Skipped Compute disk ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_disk" = {
          label        = "Delete disk"
          value        = "delete_disk"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_compute_disk
          pipeline_args = {
            disk_name       = param.disk_name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
          }
          success_msg = "Deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        }
      }
    }
  }
}

