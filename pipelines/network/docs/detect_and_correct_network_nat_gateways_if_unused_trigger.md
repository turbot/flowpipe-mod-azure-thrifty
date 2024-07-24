# Detect & correct Network NAT gateways if unused

## Overview

Azure Network NAT gateways with no subnets attached still cost money and should be deleted. This pipeline identifies Network NAT gateways with no subnets attached and either sends notifications or attempts predefined corrective actions.


### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `network_nat_gateways_if_unused_trigger_schedule` should be set to `true` as the default is `false`.
- `network_load_balancers_if_unused_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `network_nat_gateways_if_unused_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_nat_gateway"` to delete the NAT gateway).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```