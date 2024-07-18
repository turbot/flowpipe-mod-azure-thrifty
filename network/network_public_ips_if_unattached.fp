locals {
  network_public_ips_unattached_query = <<-EOQ
  select
    concat(ip.id, ' [', ip.resource_group, '/', ip.subscription_id, ']') as resource,
    ip.name,
    ip.subscription_id,
    ip.resource_group,
    ip._ctx ->> 'connection_name' as cred
  from
    azure_public_ip as ip,
    azure_subscription as sub
  where
    sub.subscription_id = ip.subscription_id
    and ip.ip_configuration_id is null;
  EOQ
}

trigger "query" "detect_and_correct_network_public_ips_unattached" {
  title         = "Detect & correct Network unattached public IPs"
  description   = "Detects unattached Network public IPs and runs your chosen action."
  documentation = file("./network/docs/detect_and_correct_network_public_ips_unattached_trigger.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  enabled  = var.network_public_ips_unattached_trigger_enabled
  schedule = var.network_public_ips_unattached_trigger_schedule
  database = var.database
  sql      = local.network_public_ips_unattached_query

  capture "insert" {
    pipeline = pipeline.correct_network_public_ips_unattached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_public_ips_unattached" {
  title         = "Detect & correct Network unattached public IPs"
  description   = "Detects unattached Network public IPs and runs your chosen action."
  documentation = file("./network/docs/detect_and_correct_network_public_ips_unattached.md")
  tags          = merge(local.network_common_tags, { class = "unused", type = "featured" })

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
    default     = var.network_public_ips_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_public_ips_unattached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_public_ips_unattached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_public_ips_unattached
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

pipeline "correct_network_public_ips_unattached" {
  title         = "Correct Network unattached public IPs"
  description   = "Runs corrective action on a collection of Network unattached public IPs."
  documentation = file("./network/docs/correct_network_public_ips_unattached.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      resource        = string
      name            = string
      subscription_id = string
      resource_group  = string
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
    default     = var.network_public_ips_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_public_ips_unattached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Network unattached public IPs."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.resource => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_public_ip_unattached
    args = {
      resource           = each.value.resource
      name               = each.value.name
      subscription_id    = each.value.subscription_id
      resource_group     = each.value.resource_group
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_network_public_ip_unattached" {
  title         = "Correct one Network unattached public IP"
  description   = "Runs corrective action on an unattached Network public IP."
  documentation = file("./network/docs/correct_one_network_public_ip_unattached.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  param "resource" {
    type        = string
    description = "The ID of the Network public IP."
  }

  param "name" {
    type        = string
    description = "The name of the Network public IP."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
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
    default     = var.network_public_ips_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_public_ips_unattached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Network public IP ${param.resource} is unattached."
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
            text     = "Skipped Network public IP ${param.resource} unattached"
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_ip" = {
          label        = "Delete IP"
          value        = "delete_ip"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_network_public_ip
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            public_ip_name  = param.name
            cred            = param.cred
          }
          success_msg = "Deleted Network public IP ${param.resource}."
          error_msg   = "Error deleting Network public IP ${param.resource}."
        }
      }
    }
  }
}

variable "network_public_ips_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "network_public_ips_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "network_public_ips_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "network_public_ips_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_ip"]
}
