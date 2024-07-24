# Detect & correct Network load balancers if unused

## Overview

Azure Network load balancers with no backend service instance attached still cost money and should be deleted.

This pipeline allows you to specify a collection of Network load balancers and either sends notifications or attempts to perform predefined corrective actions upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `network_load_balancers_if_unused_trigger_enabled` should be set to `true` as the default is `false`.
- `network_load_balancers_if_unused_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `network_load_balancers_if_unused_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_lb"` to delete the load balancer).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```