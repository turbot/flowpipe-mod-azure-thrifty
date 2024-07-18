## Detect & correct Compute disks attached to stopped virtual machine

## Overview

Compute disk can be attached to stopped virtual machine which can cost money. Detaching compute disks from stopped virtual machines can significantly reduce storage costs by eliminating charges for unused disk storage.

This query trigger detects compute disks attached to stopped virtual machine and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_disks_attached_to_stopped_virtual_machine_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_disks_attached_to_stopped_virtual_machine_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_disks_attached_to_stopped_virtual_machines_enabled_actions` should be set to your desired action (i.e. `"notify"` for notifications or `"snapshot_and_delete_disk"` to snapshot and delete the disk).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```