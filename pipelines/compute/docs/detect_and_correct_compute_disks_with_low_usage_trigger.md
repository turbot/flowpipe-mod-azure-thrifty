# Detect & correct Compute disks with low usage

## Overview

Compute disks can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects compute disks with low usage and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_disks_with_low_usage_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_disks_with_low_usage_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_disks_with_low_usage_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_disk"` to delete the disk).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```