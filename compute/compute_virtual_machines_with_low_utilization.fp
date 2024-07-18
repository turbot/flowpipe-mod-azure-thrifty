locals {
  compute_virtual_machines_with_low_utilization_query = <<-EOQ
    with compute_virtual_machine_utilization as (
    select
      name,
      max(average) as avg_max,
      count(average) days
    from
      azure_compute_virtual_machine_metric_cpu_utilization_daily
    where
      date_part('day', now() - timestamp) <= 30
    group by
      name
    having max(average) < 40
  ), compute_virtual_machine_current as (
    select
      i.title,
      i.id,
      i.name,
      i.region,
      i.size,
      i.resource_group,
      i.subscription_id,
      i._ctx->'connection_name' as cred,
      i.size as instance_size,
      case when security_profile ->>  'securityType' = 'TrustedLaunch' then 'trusted_launch' else 'not_trusted_launch' end as trusted_launch_config,
      split_part(i.size, '_', 1) as tier
    from
      compute_virtual_machine_utilization u
      left join azure_compute_virtual_machine i on u.name = i.name
  ), distinct_families as (
    select distinct instance_size, tier, region, trusted_launch_config from compute_virtual_machine_current
  ), capability_values as (
    select
      instance_size,
      region,
      name,
      tier,
      capability ->> 'name' as capability_name,
      capability ->> 'value' as capability_value
    from (
      select
        f.instance_size,
        f.region,
        s.name,
        f.tier,
        jsonb_array_elements(capabilities) as capability
      from distinct_families f
        join azure_compute_resource_sku s on s.name like f.tier || '_%' and s.resource_type = 'virtualMachines'
        cross join jsonb_array_elements_text(s.locations) as l
        where l = f.region
    ) as capability_expanded
  ),
  family_details as (
    select
      instance_size,
      name,
      tier,
      region,
      MAX(case when capability_name = 'vCPUs' then capability_value::int else null end) as vcpus,
      MAX(case when capability_name = 'MemoryGB' then capability_value::float else null end) as memorygb,
      case when capability_name = 'HyperVGenerations' then capability_value else null end as hyper_v_generations,
      case when capability_name = 'TrustedLaunchDisabled' then capability_value::bool else null end as trusted_launch_disabled
    from capability_values
    group by instance_size, name, region, tier, hyper_v_generations, trusted_launch_disabled
  ),
  ranked_families as (
    select
      instance_size,
      name,
      region,
      tier,
      hyper_v_generations,
      trusted_launch_disabled,
      RANK() over (
        partition by instance_size
        order by vcpus asc, memorygb asc
      ) as weight
    from family_details
  )
  select
    concat(id,' (', title, ') [', size, '/', region, '/', resource_group, ']') as title,
    id,
    name as vm_name,
    size as current_type,
    resource_group,
    subscription_id,
    coalesce((
      select name
      from ranked_families fd
      where
        fd.tier = c.tier
      and fd.weight < (select weight from ranked_families where name = c.size  limit 1)
      order by fd.weight desc
      limit 1),'') as suggested_type,
    region,
    cred
  from
    compute_virtual_machine_current c;
  EOQ
}

trigger "query" "detect_and_correct_compute_virtual_machines_with_low_utilization" {
  title         = "Detect & correct Compute virtual machine with low utilization"
  description   = "Detects Compute virtual machines with low utilization and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_virtual_machines_with_low_utilization_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_virtual_machines_with_low_utilization_trigger_enabled
  schedule = var.compute_virtual_machines_with_low_utilization_trigger_schedule
  database = var.database
  sql      = local.compute_virtual_machines_with_low_utilization_query

  capture "insert" {
    pipeline = pipeline.correct_compute_virtual_machines_with_low_utilization
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_virtual_machines_with_low_utilization" {
  title         = "Detect & correct Compute virtual machines with low utilization"
  description   = "Detects Compute virtual machines with low utilization and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_virtual_machines_with_low_utilization.md")
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
    default     = var.compute_virtual_machines_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_with_low_utilization_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_virtual_machines_with_low_utilization_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_virtual_machines_with_low_utilization
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

pipeline "correct_compute_virtual_machines_with_low_utilization" {
  title         = "Correct Compute virtual machines with low utilization"
  description   = "Corrects Compute virtual machines with low utilization based on the chosen action."
  documentation = file("./compute/docs/correct_compute_virtual_machines_with_low_utilization.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title           = string
      id              = string
      vm_name         = string
      current_type    = string
      suggested_type  = string
      region          = string
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
    default     = var.compute_virtual_machines_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_with_low_utilization_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute virtual machines without graviton processor."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_virtual_machine_with_low_utilization
    args = {
      title              = each.value.title
      id                 = each.value.id
      current_type       = each.value.current_type
      suggested_type     = each.value.suggested_type
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      vm_name            = each.value.vm_name
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_virtual_machine_with_low_utilization" {
  title         = "Correct one Compute virtual machine with low utilization"
  description   = "Runs corrective action on a single Compute virtual machine with low utilization."
  documentation = file("./compute/docs/correct_one_compute_virtual_machine_with_low_utilization.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "id" {
    type        = string
    description = "The ID of the Compute virtual machine."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "vm_name" {
    type        = string
    description = "The name of ompute virtual machine."
  }

  param "current_type" {
    type        = string
    description = "The current Compute virtual machine type."
  }

  param "suggested_type" {
    type        = string
    description = "The suggested Compute virtual machine type."
  }

  param "region" {
    type        = string
    description = "The region of the Compute virtual machine."
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
    default     = var.compute_virtual_machines_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_virtual_machines_with_low_utilization_enabled_actions
  }

  step transform "build_non_optional_actions" {
    value = {
      "skip" = {
        label        = "Skip"
        value        = "skip"
        style        = local.style_info
        pipeline_ref = local.pipeline_optional_message
        pipeline_args = {
          notifier = param.notifier
          send     = param.notification_level == local.level_verbose
          text     = "Skipped Compute virtual machine ${param.title} with low utilization."
        }
        success_msg = "Skipping Compute virtual machine ${param.title}."
        error_msg   = "Error skipping Compute virtual machine ${param.title}."
      },
      "stop_virtual_machine" = {
        label        = "Stop virtual_machine"
        value        = "stop_virtual_machine"
        style        = local.style_alert
        pipeline_ref = local.azure_pipeline_stop_compute_virtual_machine
        pipeline_args = {
          vm_name         = param.vm_name
          resource_group  = param.resource_group
          subscription_id = param.subscription_id
          cred            = param.cred
        }
        success_msg = "Stopped Compute virtual_machine ${param.title}."
        error_msg   = "Error stoping Compute virtual_machine ${param.title}."
      }
    }
  }

  step "transform" "build_all_actions" {
    value = merge(
      step.transform.build_non_optional_actions.value,
      param.suggested_type == "" ? {} : {
        "downgrade_instance_type" = {
          label        = "Downgrade to ${param.suggested_type}"
          value        = "downgrade_instance_type"
          style        = local.style_ok
          pipeline_ref = local.azure_pipeline_stop_compute_virtual_machine
          pipeline_args = {
            vm_name         = param.vm_name
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            new_size        = param.suggested_type
            cred            = param.cred
          }
          success_msg = "Downgraded Compute virtual machine ${param.title} from ${param.current_type} to ${param.suggested_type}."
          error_msg   = "Error downgrading Compute virtual machine ${param.title} type to ${param.suggested_type}."
        }
      }
    )
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute virtual machine ${param.title} with low utilization."
      default_action     = param.default_action
      enabled_actions    = [for action in param.enabled_actions : action if contains(keys(step.transform.build_all_actions.value), action)]
      actions            = step.transform.build_all_actions.value
    }
  }
}

variable "compute_virtual_machines_with_low_utilization_avg_cpu_utilization" {
  type        = number
  default     = 20
  description = "The average CPU utilization below which an instance is considered to have low utilization."
}

variable "compute_virtual_machines_with_low_utilization_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_virtual_machines_with_low_utilization_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_virtual_machines_with_low_utilization_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_virtual_machines_with_low_utilization_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_virtual_machine", "downgrade_instance_type"]
}

pipeline "mock_update_compute_virtual_machine_type" {
  param "id" {
    type = string
  }

  param "instance_type" {
    type = string
  }

  param "region" {
    type = string
  }

  param "cred" {
    type = string
  }

  step "transform" "mock" {
    value = "Mocked update Compute virtual machine type for ${param.instance_id} to ${param.instance_type}."
  }
}