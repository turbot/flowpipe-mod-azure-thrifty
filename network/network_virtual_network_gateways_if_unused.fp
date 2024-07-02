locals {
  network_virtual_network_gateways_if_unused = <<-EOQ
    select
      concat(g.id, ' [', g.resource_group, '/', g.subscription_id) as title,
      g.id,
      g.name,
      g.resource_group,
      g.subscription_id,
      g._ctx ->> 'connection_name' as cred
    from
      azure_virtual_network_gateway as g,
      azure_subscription as sub
    where
      g.gateway_connections is null
    and
      sub.subscription_id = g.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_network_virtual_network_gateways_if_unused" {
  title         = "Detect & correct network gateways if unused"
  description   = "Detects unused network gateways and runs your chosen action."
  documentation = file("./network/docs/detect_and_correct_network_virtual_network_gateways_if_unused.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  enabled  = var.network_virtual_network_gateways_if_unused_trigger_enabled
  schedule = var.network_virtual_network_gateways_if_unused_trigger_schedule
  database = var.database
  sql      = local.network_virtual_network_gateways_if_unused

  capture "insert" {
    pipeline = pipeline.correct_network_virtual_network_gateways_if_unused
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_virtual_network_gateways_if_unused" {
  title         = "Detect & correct network gateways if unused"
  description   = "Detects unused network gateways and runs your chosen action."
  documentation = file("./network/docs/detect_and_correct_network_virtual_network_gateways_if_unused.md")
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
    default     = var.network_virtual_network_gateways_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_virtual_network_gateways_if_unused_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_virtual_network_gateways_if_unused
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_virtual_network_gateways_if_unused
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

pipeline "correct_network_virtual_network_gateways_if_unused" {
  title         = "Correct Network Gateways if unused"
  description   = "Runs corrective action on a collection of Network Gateways which are unused."
  documentation = file("./network/docs/correct_network_virtual_network_gateways_if_unused.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

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
    default     = var.network_virtual_network_gateways_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_virtual_network_gateways_if_unused_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} unused Network Gateways."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_virtual_network_gateway_if_unused
    args = {
      title              = each.value.title
      resource_group     = each.value.resource_group
      name               = each.value.name
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

pipeline "correct_one_network_virtual_network_gateway_if_unused" {
  title         = "Correct one Network Gateways if unused"
  description   = "Runs corrective action on a single Network Gateway which is unused."
  documentation = file("./network/docs/correct_one_network_virtual_network_gateway_if_unused.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Network Gateway."
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
    default     = var.network_virtual_network_gateways_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_virtual_network_gateways_if_unused_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unused Network Gateways ${param.title}."
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
            text     = "Skipped Network Gateway ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_network_gateway" = {
          label        = "Delete Network Gateway"
          value        = "delete_network_gateway"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_network_virtual_network_gateway
          pipeline_args = {
            network_gateway_name = param.name
            resource_group       = param.resource_group
            subscription_id      = param.subscription_id
            cred                 = param.cred
          }
          success_msg = "Deleted Network Gateway ${param.title}."
          error_msg   = "Error deleting Network Gateway ${param.title}."
        }
      }
    }
  }
}

variable "network_virtual_network_gateways_if_unused_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "network_virtual_network_gateways_if_unused_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "network_virtual_network_gateways_if_unused_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "delete_network_gateway"
}

variable "network_virtual_network_gateways_if_unused_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_network_gateway"]
}