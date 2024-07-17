// Tags
locals {
  azure_thrifty_common_tags = {
    category = "Cost"
    plugin   = "azure"
    service  = "Azure"
  }
}

// Consts
locals {
  level_verbose = "verbose"
  level_info    = "info"
  level_error   = "error"
  style_ok      = "ok"
  style_info    = "info"
  style_alert   = "alert"
}

// Common Texts
locals {
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_resource_group   = "Azure Resource Group of the resource(s)."
  description_subscription_id  = "Azure Subscription ID of the resource(s)."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}

// Pipeline References
locals {
  pipeline_optional_message                                  = detect_correct.pipeline.optional_message
  azure_pipeline_delete_compute_snapshot                     = azure.pipeline.delete_compute_snapshot
  azure_pipeline_delete_network_nat_gateway                  = azure.pipeline.delete_network_nat_gateway
  azure_pipeline_delete_network_load_balancer                = azure.pipeline.delete_network_load_balancer
  azure_pipeline_delete_virtual_machine_scale_set            = azure.pipeline.delete_virtual_machine_scale_set
  azure_pipeline_delete_app_service_plan                     = azure.pipeline.delete_app_service_plan
  azure_pipeline_stop_compute_virtual_machine                = azure.pipeline.stop_compute_virtual_machine
  azure_pipeline_resize_compute_virtual_machine              = azure.pipeline.resize_compute_virtual_machine
  azure_pipeline_update_monitor_log_profile_retention_policy = azure.pipeline.update_monitor_log_profile_retention_policy
  azure_pipeline_delete_compute_disk                         = azure.pipeline.delete_compute_disk
  azure_pipeline_delete_network_public_ip                    = azure.pipeline.delete_network_public_ip
  azure_pipeline_delete_network_virtual_network_gateway      = azure.pipeline.delete_network_virtual_network_gateway
  azure_pipeline_delete_compute_virtual_machine              = azure.pipeline.delete_compute_virtual_machine
  azure_pipeline_delete_storage_account                      = azure.pipeline.delete_storage_account
  azure_pipeline_detach_compute_disk                         = azure.pipeline.detach_compute_disk
  azure_pipeline_update_compute_snapshot                     = azure.pipeline.update_compute_snapshot
  azure_pipeline_stop_kusto_cluster                          = azure.pipeline.stop_kusto_cluster
  azure_pipeline_stop_network_application_gateway            = azure.pipeline.stop_network_application_gateway
  azure_pipeline_delete_sql_database                         = azure.pipeline.delete_sql_database
  azure_pipeline_delete_kusto_cluster                        = azure.pipeline.delete_kusto_cluster
  azure_pipeline_delete_service_fabric_cluster               = azure.pipeline.delete_service_fabric_cluster
  azure_pipeline_delete_hdinsight_cluster                    = azure.pipeline.delete_hdinsight_cluster
  azure_pipeline_delete_kubernetes_cluster                   = azure.pipeline.delete_kubernetes_cluster
}