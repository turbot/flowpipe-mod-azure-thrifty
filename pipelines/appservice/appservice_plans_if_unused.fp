locals {
  app_service_plans_if_unused                      = <<-EOQ
    select
      concat(asp.id, ' [', asp.resource_group, '/', asp.subscription_id, ']') as title,
      asp.id as id,
      asp.name,
      asp.resource_group,
      asp.subscription_id,
      asp.sp_connection_name as conn
    from
      azure_app_service_plan as asp
      left join azure_subscription as sub on sub.subscription_id = asp.subscription_id
    where
      apps is null
      and sku_tier <> 'Free';
  EOQ
  app_service_plans_if_unused_default_action_enum  = ["notify", "skip", "delete_app_service_plan"]
  app_service_plans_if_unused_enabled_actions_enum = ["skip", "delete_app_service_plan"]
}

variable "app_service_plans_if_unused_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/AppService"
  }
}

variable "app_service_plans_if_unused_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/AppService"
  }
}

variable "app_service_plans_if_unused_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_app_service_plan"]
  tags = {
    folder = "Advanced/AppService"
  }
}

variable "app_service_plans_if_unused_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_app_service_plan"]
  enum        = ["skip", "delete_app_service_plan"]
  tags = {
    folder = "Advanced/AppService"
  }
}

trigger "query" "detect_and_correct_app_service_plans_if_unused" {
  title         = "Detect & correct App Service plans if unused"
  description   = "Detects unused App Service plans and runs your chosen action."
  documentation = file("./pipelines/appservice/docs/detect_and_correct_app_service_plans_if_unused_trigger.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

  enabled  = var.app_service_plans_if_unused_trigger_enabled
  schedule = var.app_service_plans_if_unused_trigger_schedule
  database = var.database
  sql      = local.app_service_plans_if_unused

  capture "insert" {
    pipeline = pipeline.correct_app_service_plans_if_unused
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_app_service_plans_if_unused" {
  title         = "Detect & correct App Service plans if unused"
  description   = "Detects unused App Service plans and runs your chosen action."
  documentation = file("./pipelines/appservice/docs/detect_and_correct_app_service_plans_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.app_service_plans_if_unused_default_action
    enum        = local.app_service_plans_if_unused_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
    enum        = local.app_service_plans_if_unused_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.app_service_plans_if_unused
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_app_service_plans_if_unused
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

pipeline "correct_app_service_plans_if_unused" {
  title         = "Correct App Service plans if unused"
  description   = "Runs corrective action on a collection of App Service plans which are unused."
  documentation = file("./pipelines/appservice/docs/correct_app_service_plans_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" }, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
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
    default     = var.app_service_plans_if_unused_default_action
    enum        = local.app_service_plans_if_unused_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
    enum        = local.app_service_plans_if_unused_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} unused App Service plans."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_app_service_plan_if_unused
    args = {
      title              = each.value.title
      conn               = connection.azure[each.value.conn]
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

pipeline "correct_one_app_service_plan_if_unused" {
  title         = "Correct one App Service plan if unused"
  description   = "Runs corrective action on a single App Service plan which is unused."
  documentation = file("./pipelines/appservice/docs/correct_one_app_service_plan_if_unused.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" }, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the App Service plan."
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
    default     = var.app_service_plans_if_unused_default_action
    enum        = local.app_service_plans_if_unused_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.app_service_plans_if_unused_enabled_actions
    enum        = local.app_service_plans_if_unused_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unused App Service plan ${param.title}."
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
            text     = "Skipped App Service plan ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_app_service_plan" = {
          label        = "Delete App Service plan"
          value        = "delete_app_service_plan"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_app_service_plan
          pipeline_args = {
            service_plan_name = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            conn              = param.conn
          }
          success_msg = "Deleted App Service plan ${param.title}."
          error_msg   = "Error deleting App Service plan ${param.title}."
        }
      }
    }
  }
}
