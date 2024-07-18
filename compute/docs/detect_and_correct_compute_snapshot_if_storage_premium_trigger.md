# Detect & correct Compute snapshots if storage premium

## Overview

Migrating compute snapshot storage from premium to standard can lead to significant cost savings. Premium storage is more expensive due to its higher performance and reliability. By moving snapshots that do not require premium performance to standard storage, you can optimize costs without compromising on essential storage needs.

This pipeline allows you to specify a collection of compute snapshots with premium storage and then either send notifications or attempt to perform a predefined corrective action upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_snapshot_if_storage_premium_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_snapshot_if_storage_premium_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_snapshot_if_storage_premium_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"update_snapshot_sku"` to update the snapshot SKU).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```