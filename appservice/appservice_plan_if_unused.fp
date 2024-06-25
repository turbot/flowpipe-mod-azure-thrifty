locals {
  app_service_plans_if_unused = <<-EOQ
    select
      concat(asp.id, ' [', asp.resource_group, '/', asp.subscription_id, ']') as title,
      asp.id as id,
      asp.name,
      asp.resource_group,
      asp.subscription_id,
      asp._ctx ->> 'connection_name' as cred
    from
      azure_app_service_plan as asp
      left join azure_subscription as sub on sub.subscription_id = asp.subscription_id
    where
      apps is null
			-- and sku_tier <> 'Free';
  EOQ
}

trigger "query" "detect_and_delete_app_service_plans_if_unused" {
  title         = "Detect & delete App Service Plans if unused"
  description   = "Detects unused App Service Plans and runs your chosen action."
  documentation = file("./appservice/docs/detect_and_delete_app_service_plans_if_unused_trigger.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

  enabled  = var.app_service_plans_if_unused_trigger_enabled
  schedule = var.app_service_plans_if_unused_trigger_schedule
  database = var.database
  sql      = local.app_service_plans_if_unused

  capture "insert" {
    pipeline = pipeline.delete_app_service_plans_if_unused
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_delete_app_service_plans_if_unused" {
  title         = "Detect & delete App Service Plans if unused"
  description   = "Detects unused App Service Plans and runs your chosen action."
  documentation = file("./appservice/docs/detect_and_delete_app_service_plans_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused", type = "featured" })

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
    default     = var.app_service_plans_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.app_service_plans_if_unused
  }

  step "pipeline" "respond" {
    pipeline = pipeline.delete_app_service_plans_if_unused
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

pipeline "delete_app_service_plans_if_unused" {
  title         = "Delete App Service Plans if unused"
  description   = "Runs corrective action on a collection of App Service Plans which are unused."
  documentation = file("./appservice/docs/delete_app_service_plans_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

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
    default     = var.app_service_plans_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} unused App Service Plans."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "delete_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.delete_one_app_service_plan_if_unused
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

pipeline "delete_one_app_service_plan_if_unused" {
  title         = "Delete one App Service Plan if unused"
  description   = "Runs corrective action on a single App Service Plan which is unused."
  documentation = file("./appservice/docs/delete_one_app_service_plan_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the App Service Plan."
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
    default     = var.app_service_plans_if_unused_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unused App Service Plan ${param.title}."
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
            text     = "Skipped App Service Plan ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete" = {
          label        = "Delete App Service Plan"
          value        = "delete"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_app_service_plan
          pipeline_args = {
            service_plan_name = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            cred              = param.cred
          }
          success_msg = "Deleted App Service Plan ${param.title}."
          error_msg   = "Error deleting App Service Plan ${param.title}."
        }
      }
    }
  }
}

variable "app_service_plans_if_unused_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "app_service_plans_if_unused_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "app_service_plans_if_unused_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "delete"
}

variable "app_service_plans_if_unused_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete"]
}
