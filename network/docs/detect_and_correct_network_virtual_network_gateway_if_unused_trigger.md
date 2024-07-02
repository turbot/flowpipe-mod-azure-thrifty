# Detect & correct Virtual network gateways exceeding max age

## Overview

Virtual network gateways can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects unused health checks and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `network_virtual_network_gateways_if_unused_trigger_enabled` should be set to `true` as the default is `false`.
- `network_virtual_network_gateways_if_unused_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `network_virtual_network_gateways_if_unused_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_network_gateway"` to delete the network gateway).


Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```