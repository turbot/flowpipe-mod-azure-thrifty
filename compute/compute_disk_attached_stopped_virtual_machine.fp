locals {
  compute_disks_attached_to_stopped_virtual_machine_query = <<-EOQ
 with attached_disk_with_vm as (
  select
    concat(vm.id, ' [', vm.resource_group, '/', vm.subscription_id, ']') as title,
    vm.name,
    vm.power_state as virtual_machine_state,
    vm.os_disk_name,
    jsonb_agg(data_disk ->> 'name') as data_disk_names
  from
    azure_compute_virtual_machine as vm
    left join jsonb_array_elements(vm.data_disks) as data_disk on true
  group by vm.id, vm.resource_group, vm.subscription_id, vm.name, vm.os_disk_name, vm.power_state
)
select
  m.title,
  d.id as resource,
  d.name as disk_name,
  m.name as vm_name,
  d.resource_group,
  d.subscription_id,
  d._ctx ->> 'connection_name' as cred
from
  azure_compute_disk as d
  left join attached_disk_with_vm as m on (d.name = m.os_disk_name or m.data_disk_names ?| array[d.name])
  left join azure_subscription as sub on sub.subscription_id = d.subscription_id
where
  d.disk_state != 'Unattached' or m.virtual_machine_state != 'running';
  EOQ
}

trigger "query" "detect_and_correct_compute_disks_attached_to_stopped_virtual_machines" {
  title         = "Detect & correct Compute disks attached to stopped VMs"
  description   = "Detects Compute disks attached to compute virtual machines and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_attached_to_stopped_virtual_machine_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_attached_to_stopped_virtual_machine_trigger_enabled
  schedule = var.compute_disks_attached_to_stopped_virtual_machine_trigger_schedule
  database = var.database
  sql      = local.compute_disks_attached_to_stopped_virtual_machine_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_attached_to_stopped_virtual_machines
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_attached_to_stopped_virtual_machines" {
  title         = "Detect & correct Compute disks attached to stopped VMs"
  description   = "Detects Compute disks attached to compute virtual machines and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_attached_to_stopped_virtual_machines.md")
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
    default     = var.compute_disks_attached_to_stopped_virtual_machines_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_attached_to_stopped_virtual_machines_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_attached_to_stopped_virtual_machine_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_attached_to_stopped_virtual_machines
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

pipeline "correct_compute_disks_attached_to_stopped_virtual_machines" {
  title         = "Correct Compute disks attached to stopped VMs"
  description   = "Runs corrective action on a collection of Compute disks attached to stopped virtual machines."
  documentation = file("./compute/docs/correct_compute_disks_attached_to_stopped_virtual_machines.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      disk_name       = string
      vm_name         = string
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
    default     = var.compute_disks_attached_to_stopped_virtual_machines_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_attached_to_stopped_virtual_machines_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute Disks attached to stopped VMs."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.disk_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disks_attached_to_stopped_virtual_machines
    args = {
      title              = each.value.title
      vm_name            = each.value.vm_name
      disk_name               = each.value.disk_name
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

pipeline "correct_one_compute_disks_attached_to_stopped_virtual_machines" {
  title         = "Correct one Compute disks attached to stopped VMs"
  description   = "Runs corrective action on a collection of Compute disks attached to stopped virtual machines."
  documentation = file("./compute/docs/correct_one_compute_disks_attached_to_stopped_virtual_machines.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "vm_name" {
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
    default     = var.compute_disks_attached_to_stopped_virtual_machines_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected disks attached to stopped VMs ${param.title}."
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
            text     = "Skipped Compute disks ${param.title}  attached to stopped VMs."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_delete_disks" = {
          label        = "Delete Snapshot"
          value        = "delete_snapshot"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_compute_snapshot
          pipeline_args = {
            disk_name            = param.disk_name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            cred            = param.cred
          }
          success_msg = "Deleted Compute snapshot ${param.title}."
          error_msg   = "Error deleting Compute snapshot ${param.title}."
        }
      }
    }
  }
}

pipeline "detach_and_delete_compute_disk" {
  title       = "Detach and Delete compute disk."
  description = "A utility pipeline which detach and delete an EBS volume."

  documentation = file("./compute/docs/detach_and_delete_compute_disk.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "vm_name" {
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
    default     = var.compute_disks_attached_to_stopped_virtual_machines_enabled_actions
  }

  step "pipeline" "detach_compute_disk" {
    pipeline = azure.pipeline.detach_compute_disk
    args = {
      cred            = param.cred
      disk_name       = param.disk_name
      vm_name         = param.vm_name
      subscription_id = param.subscription_id
      resource_group  = param.resource_group
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.detach_compute_disk]
    pipeline   = azure.pipeline.delete_compute_disk
    args = {
      cred            = param.cred
      disk_name       = param.disk_name
      subscription_id = param.subscription_id
      resource_group  = param.resource_group
    }
  }
}

variable "compute_disks_attached_to_stopped_virtual_machines_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "detach_delete_disks"]
}

variable "compute_disks_attached_to_stopped_virtual_machines_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disks_attached_to_stopped_virtual_machine_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disks_attached_to_stopped_virtual_machine_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}