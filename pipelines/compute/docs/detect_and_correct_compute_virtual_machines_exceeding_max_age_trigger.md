# Detect & correct Compute virtual machine exceeding max age

## Overview

Compute virtual machine can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects virtual machines exceeding max age and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_virtual_machines_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_virtual_machines_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_virtual_machines_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_virtual_machine"` to delete the snapshot).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```