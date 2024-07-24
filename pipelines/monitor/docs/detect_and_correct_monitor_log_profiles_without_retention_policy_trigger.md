# Detect & correct Monitor log profiles without retention poliy

## Overview

Log profile retention in Azure can significantly impact cost management by controlling the amount of log data stored and the duration for which it is retained.

This pipeline allows you to specify a collection of log profiles without retention poliy and then either send notifications or attempt to perform a predefined corrective action upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `monitor_log_profiles_without_retention_policy_trigger_enabled` should be set to `true` as the default is `false`.
- `monitor_log_profiles_without_retention_policy_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `monitor_log_profiles_without_retention_policy_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"enable_log_profile_retention"` to enable log profile retention).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```