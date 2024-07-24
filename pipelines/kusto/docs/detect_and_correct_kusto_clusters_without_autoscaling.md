# Detect & correct Kusto clusters without autoscaling

Enabling autoscaling for Azure Kusto clusters can significantly optimize costs, especially in environments with fluctuating workloads. Autoscaling adjusts the number of resources based on demand, ensuring you are not over-provisioning and paying for unused capacity.

## Getting Started

This control works out-of-the-box with sensible defaults, configurable via [variables](https://flowpipe.io/docs/build/mod-variables).

You should be able to simply run the following command in your terminal:

```sh
flowpipe pipeline run detect_and_correct_kusto_clusters_without_autoscaling
```

By default, Flowpipe runs in [wizard](https://hub.flowpipe.io/mods/turbot/azure_thrifty#wizard) mode and prompts directly in the terminal for a decision on the action(s) to take for each detected resource.

However, you can run Flowpipe in [server](https://flowpipe.io/docs/run/server) mode with [external integrations](https://flowpipe.io/docs/build/input#create-an-integration), allowing it to prompt for input via `http`, `slack`, `teams`, etc.

Alternatively, you can choose to configure and run in other modes:
* [Notify](https://hub.flowpipe.io/mods/turbot/azure_thrifty#notify): Provides detections without taking any corrective action.
* [Automatic](https://hub.flowpipe.io/mods/turbot/azure_thrifty#automatic): Performs corrective actions automatically without user intervention.