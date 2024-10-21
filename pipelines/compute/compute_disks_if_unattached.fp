locals {
  compute_disks_if_unattached_query = <<-EOQ
  select
    concat(d.id, ' [', d.resource_group, '/', d.subscription_id, ']') as title,
    d.name,
    d.resource_group,
    d.subscription_id,
    d.name || to_char(current_date, 'YYYYMMDD') as snapshot_name,
    d.sp_connection_name as conn
  from
    azure_compute_disk as d,
    azure_subscription as sub
  where
    d.disk_state = 'Unattached'
  and
    sub.subscription_id = d.subscription_id;
  EOQ

  compute_disks_if_unattached_default_action_enum  = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]
  compute_disks_if_unattached_enabled_actions_enum = ["skip", "delete_disk", "snapshot_and_delete_disk"]
}

variable "compute_disks_if_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_if_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_if_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_if_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  enum        = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_disks_if_unattached" {
  title         = "Detect & correct Compute unattached disks"
  description   = "Detects Compute disks unattached and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_if_unattached_trigger.md")
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
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_if_unattached.md")
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
    default     = var.compute_disks_if_unattached_default_action
    enum        = local.compute_disks_if_unattached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
    enum        = local.compute_disks_if_unattached_enabled_actions_enum
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
  documentation = file("./pipelines/compute/docs/correct_compute_disks_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      resource_group  = string
      snapshot_name   = string
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
    default     = var.compute_disks_if_unattached_default_action
    enum        = local.compute_disks_if_unattached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
    enum        = local.compute_disks_if_unattached_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disks unattached."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_if_unattached
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      snapshot_name      = each.value.snapshot_name
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

pipeline "correct_one_compute_disk_if_unattached" {
  title         = "Correct one Compute disk unattached"
  description   = "Runs corrective action on an Compute disk unattached."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" }, { folder = "Internal" })

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
    default     = var.compute_disks_if_unattached_default_action
    enum        = local.compute_disks_if_unattached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
    enum        = local.compute_disks_if_unattached_enabled_actions_enum
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
          pipeline_ref = detect_correct.pipeline.optional_message
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
          pipeline_ref = azure.pipeline.delete_compute_disk
          pipeline_args = {
            disk_name       = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
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

pipeline "snapshot_and_delete_compute_disk" {
  title       = "Delete Compute Disk"
  description = "Delete a managed disk."

  tags = {
    folder = "Internal"
  }

  param "conn" {
    type        = connection.azure
    description = local.description_connection
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
    cmd = [
      "snapshot", "create",
      "-g", param.resource_group,
      "-n", param.snapshot_name,
      "--source", param.disk_name,
      "--subscription", param.subscription_id
    ]

    env = param.conn.env
  }

  step "container" "delete_compute_disk" {
    depends_on = [step.container.create_compute_disk_snapshot]
    image      = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd        = ["disk", "delete", "--yes", "-g", param.resource_group, "-n", param.disk_name, "--subscription", param.subscription_id]

    env = param.conn.env
  }

  output "disk" {
    description = "The deleted compute disk details."
    value       = jsondecode(step.container.delete_compute_disk.stdout)
  }
}
