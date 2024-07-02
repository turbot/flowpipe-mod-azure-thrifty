locals {
  virtual_machine_scale_sets_if_unused = <<-EOQ
		with scale_set_vm_count as (
      select
        count(*),
        scale_set_name,
        resource_group,
        region,
        subscription_id
      from
        azure_compute_virtual_machine_scale_set_vm
      group by
        scale_set_name,
        resource_group,
        region,
        subscription_id
    ) select
				concat(vmss.id, ' [', vmss.resource_group, '/', vmss.subscription_id, ']') as title,
				vmss.id as id,
				vmss.name,
				vmss.resource_group,
				vmss.subscription_id,
				vmss._ctx ->> 'connection_name' as cred
			from
				azure_compute_virtual_machine_scale_set as vmss
				left join scale_set_vm_count as vm on vm.scale_set_name = vmss.name and vm.resource_group = vmss.resource_group and vm.region = vmss.region
				left join azure_subscription as sub on sub.subscription_id = vmss.subscription_id
			where
				vm.scale_set_name is null;
  EOQ
}

trigger "query" "detect_and_correct_virtual_machine_scale_sets_if_unused" {
  title         = "Detect & correct Virtual Machine Scale Sets if unused"
  description   = "Detects unused Virtual Machine Scale Sets and runs your chosen action."
  // documentation = file("./compute/docs/detect_and_correct_virtual_machine_scale_sets_if_unused.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.virtual_machine_scale_sets_if_unused_trigger_enabled
  schedule = var.virtual_machine_scale_sets_if_unused_trigger_schedule
  database = var.database
  sql      = local.virtual_machine_scale_sets_if_unused

  capture "insert" {
    pipeline = pipeline.correct_virtual_machine_scale_sets_if_unused
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_virtual_machine_scale_sets_if_unused" {
  title         = "Detect & correct Virtual Machine Scale Sets if unused"
  description   = "Detects unused Virtual Machine Scale Sets and runs your chosen action."
  // documentation = file("./compute/docs/detect_and_correct_virtual_machine_scale_sets_if_unused.md")
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
    default     = var.virtual_machine_scale_sets_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.virtual_machine_scale_sets_if_unused_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.virtual_machine_scale_sets_if_unused
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_virtual_machine_scale_sets_if_unused
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

pipeline "correct_virtual_machine_scale_sets_if_unused" {
  title         = "Correct Virtual Machine Scale Sets if unused"
  description   = "Runs corrective action on a collection of Virtual Machine Scale Sets which are unused."
  // documentation = file("./compute/docs/correct_virtual_machine_scale_sets_if_unused.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      id              = string
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
    default     = var.virtual_machine_scale_sets_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.virtual_machine_scale_sets_if_unused_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} unused Virtual Machine Scale Sets."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_virtual_machine_scale_set_if_unused
    args = {
      title              = each.value.title
      cred               = each.value.cred
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      name               = each.value.name
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_virtual_machine_scale_set_if_unused" {
  title         = "Correct one Virtual Machine Scale Set if unused"
  description   = "Runs corrective action on a single Virtual Machine Scale Set which is unused."
  // documentation = file("./compute/docs/correct_one_virtual_machine_scale_set_if_unused.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Virtual Machine Scale Set."
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
    default     = "default"
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
    default     = var.virtual_machine_scale_sets_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.virtual_machine_scale_sets_if_unused_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unused Virtual Machine Scale Set ${param.title}."
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
            text     = "Skipped Virtual Machine Scale Set ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_virtual_machine_scale_set" = {
          label        = "Delete Virtual Machine Scale Set"
          value        = "delete_virtual_machine_scale_set"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_virtual_machine_scale_set
          pipeline_args = {
            vmss_name        = param.name
            resource_group   = param.resource_group
            subscription_id  = param.subscription_id
            cred             = param.cred
          }
          success_msg = "Deleted Virtual Machine Scale Set ${param.title}."
          error_msg   = "Error deleting Virtual Machine Scale Set ${param.title}."
        }
      }
    }
  }
}

variable "virtual_machine_scale_sets_if_unused_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "virtual_machine_scale_sets_if_unused_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "virtual_machine_scale_sets_if_unused_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "virtual_machine_scale_sets_if_unused_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_virtual_machine_scale_set"]
}