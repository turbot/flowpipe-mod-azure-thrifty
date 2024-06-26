# Detect & correct Compute disks unattached

## Overview

Managing unattached disks is crucial for cost efficiency, as they continue to incur charges while not actively contributing to operational workloads. Regularly identifying and managing these resources can help optimize storage costs and organizational efficiency in Azure.

This query trigger detects unused health checks and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_disks_if_unattached_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_disks_if_unattached_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_disks_if_unattached_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_snapshot"` to delete the snapshot).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```