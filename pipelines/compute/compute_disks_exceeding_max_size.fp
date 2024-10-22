locals {
  compute_disks_exceeding_max_size_query = <<-EOQ
    select
      concat(disk.id, ' [', '/', disk.resource_group, '/', disk.subscription_id, ']') as title,
      disk.id as resource,
      disk.name,
      disk.subscription_id,
      disk.resource_group,
      disk.name || to_char(current_date, 'YYYYMMDD') as snapshot_name,
      disk.disk_size_gb,
      disk.sp_connection_name as conn
    from
      azure_compute_disk as disk,
      azure_subscription as sub
    where
      disk.disk_size_gb >= ${var.compute_disk_exceeding_max_size}
      and sub.subscription_id = disk.subscription_id;
  EOQ

  compute_disks_exceeding_max_size_default_action_enum  = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]
  compute_disks_exceeding_max_size_enabled_actions_enum = ["skip", "delete_disk", "snapshot_and_delete_disk"]
}

variable "compute_disks_exceeding_max_size_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  enum        = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disk_exceeding_max_size" {
  type        = number
  description = "The maximum size (GB) allowed for disks."
  default     = 90
  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_disks_exceeding_max_size" {
  title         = "Detect & correct Compute disks exceeding max size"
  description   = "Detects Compute disks exceeding max size and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_disks_exceeding_max_size_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_exceeding_max_size_trigger_enabled
  schedule = var.compute_disks_exceeding_max_size_trigger_schedule
  database = var.database
  sql      = local.compute_disks_exceeding_max_size_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_exceeding_max_size
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_disks_exceeding_max_size" {
  title         = "Detect & correct Compute disks exceeding max size"
  description   = "Detects Compute disks exceeding max size and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_disks_exceeding_max_size.md")
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
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_exceeding_max_size_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_exceeding_max_size
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

pipeline "correct_compute_disks_exceeding_max_size" {
  title         = "Correct Compute disks exceeding max size"
  description   = "Runs corrective action on a collection of Compute disks exceeding max size."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      snapshot_name   = string
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
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} large Compute disks."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disks_exceeding_max_size
    args = {
      title              = each.value.title
      name               = each.value.name
      snapshot_name      = each.value.snapshot_name
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

pipeline "correct_one_compute_disks_exceeding_max_size" {
  title         = "Correct one Compute disk exceeding max size"
  description   = "Runs corrective action on Compute disk exceeding max size."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "snapshot_name" {
    type        = string
    description = "The snapshot name of the disk."
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
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected larger Compute disk ${param.title}."
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
            text     = "Skipped Compute disk ${param.title} exceeding max size. "
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_disk" = {
          label        = "Delete Disk"
          value        = "delete_disk"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_compute_disk
          pipeline_args = {
            disk_name       = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
          }
          success_msg = "Deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        },
        "snapshot_and_delete_disk" = {
          label        = "Snapshot & Delete Disk"
          value        = "snapshot_and_delete_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_and_delete_compute_disk
          pipeline_args = {
            disk_name       = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
            snapshot_name   = param.snapshot_name
          }
          success_msg = "Deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        }
      }
    }
  }
}

