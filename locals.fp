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

locals {
  notification_level_enum = ["info", "verbose", "error"]
}

// Common Texts
locals {
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_connection       = "Name of the Azure connection to be used for any authenticated actions."
  description_resource_group   = "Azure Resource Group of the resource(s)."
  description_subscription_id  = "Azure Subscription ID of the resource(s)."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}
