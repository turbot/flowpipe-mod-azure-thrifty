# Detect & correct Network Application Gateways without autoscaling

## Overview

Autoscaling for Azure Application Gateways can provide significant cost optimization benefits by dynamically adjusting the number of instances based on traffic load. This ensures that you are only paying for the resources you need at any given time, avoiding over-provisioning during low traffic periods.

This pipeline allows you to specify a collection of Application Gateway with autoscaling disabled and either sends notifications or attempts to perform predefined corrective actions upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `network_application_gateways_without_autoscaling_trigger_enabled` should be set to `true` as the default is `false`.
- `network_application_gateways_without_autoscaling_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `network_application_gateways_without_autoscaling_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"stop_application_gateway"` to stop the application gateway).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```