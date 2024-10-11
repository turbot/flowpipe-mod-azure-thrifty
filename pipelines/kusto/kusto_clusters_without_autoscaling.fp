locals {
  kusto_clusters_without_autoscaling_query = <<-EOQ
    select
      concat(kc.id, ' [', kc.resource_group, '/', kc.subscription_id, ']') as title,
      kc.id as id,
      kc.name,
      kc.resource_group,
      kc.subscription_id,
      kc.sp_connection_name as conn
    from
      azure_kusto_cluster as kc,
      azure_subscription as sub
    where
      sub.subscription_id = kc.subscription_id
      and optimized_autoscale is null;
  EOQ
}

trigger "query" "detect_and_correct_kusto_clusters_without_autoscaling" {
  title         = "Detect & correct Kusto clusters without autoscaling"
  description   = "Detects Kusto clusters without autoscaling enabled and runs your chosen action."
  documentation = file("./pipelines/kusto/docs/detect_and_correct_kusto_clusters_without_autoscaling_trigger.md")
  tags          = merge(local.kusto_common_tags, { class = "unused" })

  enabled  = var.kusto_clusters_without_autoscaling_trigger_enabled
  schedule = var.kusto_clusters_without_autoscaling_trigger_schedule
  database = var.database
  sql      = local.kusto_clusters_without_autoscaling_query

  capture "insert" {
    pipeline = pipeline.correct_kusto_clusters_without_autoscaling
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_kusto_clusters_without_autoscaling" {
  title         = "Detect & correct Kusto clusters without autoscaling"
  description   = "Detects Kusto clusters without autoscaling enabled and runs your chosen action."
  documentation = file("./pipelines/kusto/docs/detect_and_correct_kusto_clusters_without_autoscaling.md")
  tags          = merge(local.kusto_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.kusto_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kusto_clusters_without_autoscaling_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.kusto_clusters_without_autoscaling_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_kusto_clusters_without_autoscaling
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

pipeline "correct_kusto_clusters_without_autoscaling" {
  title         = "Correct Kusto clusters without autoscaling"
  description   = "Runs corrective action on a collection of Kusto clusters without autoscaling enabled."
  documentation = file("./pipelines/kusto/docs/correct_kusto_clusters_without_autoscaling.md")
  tags          = merge(local.kusto_common_tags, { class = "unused" })

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
    default     = var.kusto_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kusto_clusters_without_autoscaling_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Kusto Clusters without autoscaling enabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "update_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_kusto_cluster_without_autoscaling
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

pipeline "correct_one_kusto_cluster_without_autoscaling" {
  title         = "Correct one Kusto cluster without autoscaling"
  description   = "Runs corrective action on a single Kusto cluster without autoscaling enabled."
  documentation = file("./pipelines/kusto/docs/correct_one_kusto_cluster_without_autoscaling.md")
  tags          = merge(local.kusto_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Kusto Cluster."
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
    default     = var.kusto_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kusto_clusters_without_autoscaling_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Kusto cluster ${param.title} without autoscaling enabled."
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
            text     = "Skipped Kusto cluster ${param.title} without autoscaling enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "stop_kusto_cluster" = {
          label        = "Stop Kusto Cluster"
          value        = "stop_kusto_cluster"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_stop_kusto_cluster
          pipeline_args = {
            cluster_name     = param.name
            resource_group   = param.resource_group
            subscription_id  = param.subscription_id
            conn             = param.conn
          }
          success_msg = "Stopped Kusto cluster ${param.title}."
          error_msg   = "Error stopping Kusto cluster ${param.title}."
        }
      }
    }
  }
}

variable "kusto_clusters_without_autoscaling_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Kusto"
  }
}

variable "kusto_clusters_without_autoscaling_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Kusto"
  }
}

variable "kusto_clusters_without_autoscaling_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Kusto"
  }
}

variable "kusto_clusters_without_autoscaling_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_kusto_cluster"]
  tags = {
    folder = "Advanced/Kusto"
  }
}
