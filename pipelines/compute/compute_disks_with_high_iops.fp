locals {
  compute_disks_with_high_iops_query = <<-EOQ
    select
      concat(d.id, ' [', d.resource_group, '/', d.subscription_id, ']') as title,
      d.id as resource,
      d.name as disk_name,
      d.resource_group,
      d.subscription_id,
      d.name || to_char(current_date, 'YYYYMMDD') as snapshot_name,
      d._ctx ->> 'connection_name' as cred
    from
      azure_compute_disk as d
      left join azure_subscription as sub on sub.subscription_id = d.subscription_id
    where
      d.disk_iops_read_write > var.compute_disk_max_iops_threshold;
  EOQ
}

trigger "query" "detect_and_correct_compute_disks_with_high_iops" {
  title         = "Detect & correct Compute disks with high IOPS"
  description   = "Detects Compute disks with high IOPS and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_high_iops_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_with_high_iops_trigger_enabled
  schedule = var.compute_disks_with_high_iops_trigger_schedule
  database = var.database
  sql      = local.compute_disks_with_high_iops_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_with_high_iops
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_with_high_iops" {
  title         = "Detect & correct Compute disks with high IOPS"
  description   = "Detects Compute disks with high IOPS and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_high_iops.md")
  tags          = merge(local.compute_common_tags, { class = "unused", type = "recommended" })

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
    default     = var.compute_disks_with_high_iops_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_high_iops_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_with_high_iops_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_with_high_iops
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

pipeline "correct_compute_disks_with_high_iops" {
  title         = "Correct Compute disks with high IOPS"
  description   = "Runs corrective action on a collection of Compute disks with high IOPS."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_with_high_iops.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      disk_name       = string
      snapshot_name   = string
      resource_group  = string
      subscription_id = string
      cred            = string
    }))
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
    default     = var.compute_disks_with_high_iops_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_high_iops_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute disks with high IOPS."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.disk_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_with_high_iops
    args = {
      title              = each.value.title
      disk_name          = each.value.disk_name
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

pipeline "correct_one_compute_disk_with_high_iops" {
  title         = "Correct one Compute disk with high IOPS"
  description   = "Runs corrective action on a single Compute disk with high IOPS."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_with_high_iops.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "snapshot_name" {
    type        = string
    description = "The snapshot name of the disk."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
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
    default     = var.compute_snapshots_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_high_iops_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected disk with high IOPS ${param.title}."
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
            text     = "Skipped Compute disk ${param.title} with high IOPS."
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
            disk_name       = param.disk_name
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
            disk_name       = param.disk_name
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

variable "compute_disks_with_high_iops_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "snapshot_and_delete_disk", "delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_high_iops_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_high_iops_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_high_iops_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disk_max_iops_threshold" {
  type        = number
  description = "The maximum IOPS threshold to consider a disk as having high IOPS."
  default     = 20000
  tags = {
    folder = "Advanced/Compute"
  }
}