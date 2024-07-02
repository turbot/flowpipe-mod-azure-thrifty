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
      disk._ctx ->> 'connection_name' as cred
    from
      azure_compute_disk as disk,
      azure_subscription as sub
    where
      disk.disk_size_gb >= ${var.compute_disk_exceeding_max_size}
      and sub.subscription_id = disk.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_disks_exceeding_max_size" {
  title         = "Detect & correct Compute disk exceeding max size"
  description   = "Detects Compute disks exceeding max size and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_disks_exceeding_max_size_trigger.md")
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
  documentation = file("./compute/docs/detect_and_correct_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "unused", type = "featured" })

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
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
  documentation = file("./compute/docs/correct_compute_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      snapshot_name   = string
      resource_group  = string
      subscription_id = string
      cred            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
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
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_disks_exceeding_max_size" {
  title         = "Correct one Compute disks exceeding max size"
  description   = "Runs corrective action on compute disks exceeding max size."
  documentation = file("./compute/docs/correct_one_compute_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

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

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
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
          pipeline_ref = local.pipeline_optional_message
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
          pipeline_ref = local.azure_pipeline_delete_compute_disk
          pipeline_args = {
            disk_name       = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            cred            = param.cred
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
            cred            = param.cred
            snapshot_name   = param.snapshot_name
          }
          success_msg = "Deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        }
      }
    }
  }
}

variable "compute_disks_exceeding_max_size_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disks_exceeding_max_size_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_disks_exceeding_max_size_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disks_exceeding_max_size_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_disk"]
}

variable "compute_disk_exceeding_max_size" {
  type        = number
  description = "The maximum size (GB) allowed for disks."
  default     = 90
}