# Detect & correct Network Public IPs unattached

## Overview

Network Public IP can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects unattached public IP and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `network_public_ips_unattached_trigger_enabled` should be set to `true` as the default is `false`.
- `network_public_ips_unattached_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `network_public_ips_unattached_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_snapshot"` to delete the snapshot).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```