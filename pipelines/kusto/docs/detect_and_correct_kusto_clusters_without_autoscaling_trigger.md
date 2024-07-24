# Detect & correct Kusto clusters without autoscaling

Enabling autoscaling for Azure Kusto clusters can significantly optimize costs, especially in environments with fluctuating workloads. Autoscaling adjusts the number of resources based on demand, ensuring you are not over-provisioning and paying for unused capacity.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `kusto_clusters_without_autoscaling_trigger_enabled` should be set to `true` as the default is `false`.
- `kusto_clusters_without_autoscaling_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `kusto_clusters_without_autoscaling_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"stop_kusto_cluster"` to stop the kusto cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```