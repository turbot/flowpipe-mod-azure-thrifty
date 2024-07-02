locals {
  compute_disks_if_unattached_query = <<-EOQ
  select
    concat(d.id, ' [', d.resource_group, '/', d.subscription_id, ']') as title,
    d.name,
    d.resource_group,
    d.subscription_id,
    d.name || to_char(current_date, 'YYYYMMDD') as snapshot_name,
    d._ctx ->> 'connection_name' as cred
  from
    azure_compute_disk as d,
    azure_subscription as sub
  where
    d.disk_state = 'Unattached'
  and
    sub.subscription_id = d.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_compute_disks_if_unattached" {
  title         = "Detect & correct Compute unattached disks"
  description   = "Detects Compute disks unattached and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_if_unattached_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_if_unattached_trigger_enabled
  schedule = var.compute_disks_if_unattached_trigger_schedule
  database = var.database
  sql      = local.compute_disks_if_unattached_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_if_unattached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_if_unattached" {
  title         = "Detect & correct Compute disks unattached"
  description   = "Detects Compute disks unatatched and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_if_unattached.md")
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_if_unattached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_if_unattached
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

pipeline "correct_compute_disks_if_unattached" {
  title         = "Correct Compute unattached disks"
  description   = "Runs corrective action on a collection of Compute unattached disks."
  documentation = file("./compute/docs/correct_compute_disks_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      resource_group  = string
      snapshot_name   = string
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute disks unattached."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disks_if_unattached
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      snapshot_name      = each.value.snapshot_name
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

pipeline "correct_one_compute_disks_if_unattached" {
  title         = "Correct one Compute disk unattached"
  description   = "Runs corrective action on an Compute disk unattached."
  documentation = file("./compute/docs/correct_one_compute_disks_if_unattached.md")
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.title} is unattached."
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
            text     = "Skipped Compute disk ${param.title} unattached"
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
        }
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

variable "compute_disks_if_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disks_if_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_disks_if_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disks_if_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_disk"]
}

pipeline "snapshot_and_delete_compute_disk" {
  title       = "Delete Compute Disk"
  description = "Delete a managed disk."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "azure"
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "snapshot_name" {
    type        = string
    description = "The name of the snapshot."
  }

  param "disk_name" {
    type        = string
    description = "The name of the managed disk that is being deleted."
  }

  step "container" "create_compute_disk_snapshot" {
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "snapshot", "create",
      "-g", param.resource_group,
      "-n", param.snapshot_name,
      "--source", param.disk_name,
      "--subscription", param.subscription_id
    ]

    env = credential.azure[param.cred].env
  }

  step "container" "delete_compute_disk" {
    depends_on = [step.container.create_compute_disk_snapshot]
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = ["disk", "delete", "--yes", "-g", param.resource_group, "-n", param.disk_name, "--subscription", param.subscription_id]

    env = credential.azure[param.cred].env
  }

  output "disk" {
    description = "The deleted compute disk details."
    value       = jsondecode(step.container.delete_compute_disk.stdout)
  }
}
