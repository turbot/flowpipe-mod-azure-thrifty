locals {
  compute_snapshots_if_storage_premium_query = <<-EOQ
		select
			concat(s.id, ' [', s.resource_group, '/', s.subscription_id, ']') as title,
			s.name,
			s.resource_group,
			s.subscription_id,
			s._ctx ->> 'connection_name' as cred
		from
			azure_compute_snapshot as s,
			azure_subscription as sub
		where
			sub.subscription_id = s.subscription_id
			and s.sku_tier <> 'Standard';
  EOQ
}

trigger "query" "detect_and_correct_compute_snapshots_if_storage_premium" {
  title         = "Detect & correct Compute snapshots with premium storage"
  description   = "Detects Compute snapshots with premium storage and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_snapshots_if_storage_premium_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_snapshots_if_storage_premium_trigger_enabled
  schedule = var.compute_snapshots_if_storage_premium_trigger_schedule
  database = var.database
  sql      = local.compute_snapshots_if_storage_premium_query

  capture "insert" {
    pipeline = pipeline.correct_compute_snapshots_if_storage_premium
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_snapshots_if_storage_premium" {
  title         = "Detect & correct Compute snapshots with premium storage"
  description   = "Detects Compute snapshots with premium storage and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_snapshots_if_storage_premium.md")
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
    default     = var.compute_snapshots_if_storage_premium_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_if_storage_premium_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_snapshots_if_storage_premium_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_snapshots_if_storage_premium
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

pipeline "correct_compute_snapshots_if_storage_premium" {
  title         = "Correct Compute snapshots with premium storage"
  description   = "Runs corrective action on a collection of Compute snapshots with premium storage."
  documentation = file("./pipelines/compute/docs/correct_compute_snapshots_if_storage_premium.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
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
    default     = var.compute_snapshots_if_storage_premium_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_if_storage_premium_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute snapshots with premium storage."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_snapshot_if_storage_premium
    args = {
      title              = each.value.title
      name               = each.value.name
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

pipeline "correct_one_compute_snapshot_if_storage_premium" {
  title         = "Correct one Compute snapshot with premium storage"
  description   = "Runs corrective action on a Compute snapshot with premium storage."
  documentation = file("./pipelines/compute/docs/correct_one_compute_snapshot_if_storage_premium.md")
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
    default     = var.compute_snapshots_if_storage_premium_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_snapshots_if_storage_premium_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute snapshot ${param.title} is using premium storage."
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
            text     = "Skipped Compute snapshots ${param.title} with premium storage."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_snapshot_sku" = {
          label        = "Update Snapshot SKU"
          value        = "update_snapshot_sku"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_compute_snapshot
          pipeline_args = {
            snapshot_name   = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
						sku             = "Standard_LRS"
            cred            = param.cred
          }
          success_msg = "Updated Compute snapshot ${param.title}."
          error_msg   = "Error updating Compute snapshot ${param.title}."
        },
      }
    }
  }
}

variable "compute_snapshots_if_storage_premium_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_snapshots_if_storage_premium_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_snapshots_if_storage_premium_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_snapshots_if_storage_premium_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_snapshot_sku"]
}
