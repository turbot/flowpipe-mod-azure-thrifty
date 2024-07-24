# Detect & correct Storage account without lifecycle policy

## Overview

Storage accounts can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects storage account without lifecycle policy and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `storage_accounts_without_lifecycle_policy_trigger_enabled` should be set to `true` as the default is `false`.
- `storage_accounts_without_lifecycle_policy_trigger_enabled` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `storage_accounts_without_lifecycle_policy_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_storage_account"` to delete the snapshot).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```