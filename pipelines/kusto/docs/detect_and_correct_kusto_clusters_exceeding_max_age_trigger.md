# Detect & correct Kusto clusters exceeding max age

## Overview

Kusto clusters can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a collection of Kusto clusters and then either send notifications or attempt to perform a predefined corrective action upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `kusto_clusters_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `kusto_clusters_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `kusto_clusters_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_cluster"` to delete the Kusto cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```