# Detect & correct Network Application Gateways without autoscaling

Autoscaling for Azure Application Gateways can provide significant cost optimization benefits by dynamically adjusting the number of instances based on traffic load. This ensures that you are only paying for the resources you need at any given time, avoiding over-provisioning during low traffic periods.

## Getting Started

This control works out-of-the-box with sensible defaults, configurable via [variables](https://flowpipe.io/docs/build/mod-variables).

You should be able to simply run the following command in your terminal:

```sh
flowpipe pipeline run detect_and_correct_network_application_gateways_without_autoscaling
```

By default, Flowpipe runs in [wizard](https://hub.flowpipe.io/mods/turbot/azure_thrifty#wizard) mode and prompts directly in the terminal for a decision on the action(s) to take for each detected resource.

However, you can run Flowpipe in [server](https://flowpipe.io/docs/run/server) mode with [external integrations](https://flowpipe.io/docs/build/input#create-an-integration), allowing it to prompt for input via `http`, `slack`, `teams`, etc.

Alternatively, you can choose to configure and run in other modes:
* [Notify](https://hub.flowpipe.io/mods/turbot/azure_thrifty#notify): Provides detections without taking any corrective action.
* [Automatic](https://hub.flowpipe.io/mods/turbot/azure_thrifty#automatic): Performs corrective actions automatically without user intervention.