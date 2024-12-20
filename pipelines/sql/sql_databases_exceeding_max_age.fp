locals {
  sql_databases_exceeding_max_age_query = <<-EOQ
    select
      concat(db.id, ' [', db.resource_group, '/', db.subscription_id, ']') as title,
      db.name,
      db.resource_group,
      db.subscription_id,
      db.server_name as server_name,
      db.sp_connection_name as conn
    from
      azure_sql_database as db,
      azure_subscription as sub
    where
      date_part('day', now() - creation_date) > ${var.sql_databases_exceeding_max_age_days}
      and sub.subscription_id = db.subscription_id;
  EOQ

  sql_databases_exceeding_max_age_default_action_enum  = ["notify", "skip", "delete_sql_database"]
  sql_databases_exceeding_max_age_enabled_actions_enum = ["skip", "delete_sql_database"]
}

variable "sql_databases_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_databases_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_databases_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_sql_database"]
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_databases_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_sql_database"]
  enum        = ["skip", "delete_sql_database"]
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_databases_exceeding_max_age_days" {
  type        = number
  description = "The maximum number of days SQL Databases can be retained."
  default     = 90
  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_databases_exceeding_max_age" {
  title         = "Detect & correct SQL databases exceeding max age"
  description   = "Detects SQL databases exceeding max age and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_databases_exceeding_max_age_trigger.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  enabled  = var.sql_databases_exceeding_max_age_trigger_enabled
  schedule = var.sql_databases_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.sql_databases_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_sql_databases_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_databases_exceeding_max_age" {
  title         = "Detect & correct SQL databases exceeding max age"
  description   = "Detects SQL databases exceeding max age and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_databases_exceeding_max_age.md")
  tags          = merge(local.sql_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.sql_databases_exceeding_max_age_default_action
    enum        = local.sql_databases_exceeding_max_age_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_exceeding_max_age_enabled_actions
    enum        = local.sql_databases_exceeding_max_age_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_databases_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_databases_exceeding_max_age
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

pipeline "correct_sql_databases_exceeding_max_age" {
  title         = "Correct SQL databases exceeding max age"
  description   = "Runs corrective action on a collection of SQL databases exceeding max age."
  documentation = file("./pipelines/sql/docs/correct_sql_databases_exceeding_max_age.md")
  tags          = merge(local.sql_common_tags, { class = "unused" }, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      resource_group  = string
      server_name     = string
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
    default     = var.sql_databases_exceeding_max_age_default_action
    enum        = local.sql_databases_exceeding_max_age_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_exceeding_max_age_enabled_actions
    enum        = local.sql_databases_exceeding_max_age_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} SQL Databases exceeding maximum age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_database_exceeding_max_age
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      server_name        = each.value.server_name
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

pipeline "correct_one_sql_database_exceeding_max_age" {
  title         = "Correct one SQL database exceeding max age"
  description   = "Runs corrective action on an SQL database exceeding max age."
  documentation = file("./pipelines/sql/docs/correct_one_sql_database_exceeding_max_age.md")
  tags          = merge(local.sql_common_tags, { class = "unused" }, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the SQL Database."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "server_name" {
    type        = string
    description = "The name of the server."
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
    default     = var.sql_databases_exceeding_max_age_default_action
    enum        = local.sql_databases_exceeding_max_age_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_exceeding_max_age_enabled_actions
    enum        = local.sql_databases_exceeding_max_age_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL database ${param.title} exceeding maximum age."
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
            text     = "Skipped SQL database ${param.title} exceeding maximum age."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_sql_database" = {
          label        = "Delete SQL Database"
          value        = "delete_sql_database"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_sql_database
          pipeline_args = {
            database_name   = param.name
            resource_group  = param.resource_group
            server_name     = param.server_name
            subscription_id = param.subscription_id
            conn            = param.conn
          }
          success_msg = "Deleted SQL Database ${param.title}."
          error_msg   = "Error deleting SQL Database ${param.title}."
        }
      }
    }
  }
}
