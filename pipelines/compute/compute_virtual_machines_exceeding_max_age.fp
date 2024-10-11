locals {
  compute_virtual_machines_exceeding_max_age_query = <<-EOQ
  select
    concat(vm.id,' (', vm.title, ') [', vm.size, '/', vm.region, '/', vm.resource_group, ']') as title,
    vm.id,
    vm.name,
    vm.subscription_id,
    vm.resource_group,
    vm.title,
    vm.sp_connection_name as conn
  from
    azure_compute_virtual_machine as vm,
    jsonb_array_elements(statuses) as s,
    azure_subscription as sub
  where
    sub.subscription_id = vm.subscription_id
    and vm.power_state in ('running', 'starting')
    and s ->> 'time' is not null
    and date_part('day', now() - (s ->> 'time') :: timestamptz) > ${var.compute_running_vm_age_max_days};
  EOQ
}

trigger "query" "detect_and_correct_compute_virtual_machines_exceeding_max_age" {
  title         = "Detect & correct Compute virtual machines"
  description   = "Detects Compute VM exceeding max age and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_virtual_machines_exceeding_max_age_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_virtual_machines_exceeding_max_age_trigger_enabled
  schedule = var.compute_virtual_machines_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.compute_virtual_machines_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_compute_virtual_machines_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_virtual_machines_exceeding_max_age" {
  title         = "Detect & correct Compute virtual machines exceeding max age"
  description   = "Detects Compute virtual machines exceeding max age and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_virtual_machines_exceeding_max_age.md")
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
    default     = var.compute_virtual_machines_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_exceeding_max_age_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_virtual_machines_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_virtual_machines_exceeding_max_age
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

pipeline "correct_compute_virtual_machines_exceeding_max_age" {
  title         = "Correct Compute virtual machines exceeding max age"
  description   = "Runs corrective action on a collection of Compute virtual machines exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_compute_virtual_machines_exceeding_max_age.md")
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
    default     = var.compute_virtual_machines_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_exceeding_max_age_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute virtual machines exceeding maximum age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_virtual_machine_exceeding_max_age
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

pipeline "correct_one_compute_virtual_machine_exceeding_max_age" {
  title         = "Correct one Compute virtual machine exceeding max age"
  description   = "Runs corrective action on an Compute virtual machine exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_one_compute_virtual_machine_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Compute virtual machine."
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
    default     = var.compute_virtual_machines_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_exceeding_max_age_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute virtual machine ${param.title} exceeding maximum age."
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
            text     = "Skipped Compute virtual machine ${param.title} exceeding maximum age."
          }
          success_msg = ""
          error_msg   = ""
        },
        "stop_virtual_machine" = {
          label        = "Stop Virtual Machine"
          value        = "stop_virtual_machine"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_stop_compute_virtual_machine
          pipeline_args = {
            vm_name         = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
          }
          success_msg = "Stopped Compute virtual machine ${param.title}."
          error_msg   = "Error stoping Compute virtual machine ${param.title}."
        }
        "delete_virtual_machine" = {
          label        = "Delete Virtual Machine"
          value        = "delete_virtual_machine"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_compute_virtual_machine
          pipeline_args = {
            vm_name         = param.name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            conn            = param.conn
          }
          success_msg = "Deleted Compute virtual machine ${param.title}."
          error_msg   = "Error deleting Compute virtual machine ${param.title}."
        }
      }
    }
  }
}

variable "compute_virtual_machines_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_virtual_machines_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_virtual_machines_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_virtual_machines_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_virtual_machine"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_running_vm_age_max_days" {
  type        = number
  description = "The maximum number of days Compute VM can be retained."
  default     = 90
  tags = {
    folder = "Advanced/Compute"
  }
}
