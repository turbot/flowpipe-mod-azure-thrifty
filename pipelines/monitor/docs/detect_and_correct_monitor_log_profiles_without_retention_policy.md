# Detect & correct Monitor log profiles without retention poliy

## Overview

Log profile retention in Azure can significantly impact cost management by controlling the amount of log data stored and the duration for which it is retained.

This pipeline allows you to specify a collection of log profiles without retention poliy and then either send notifications or attempt to perform a predefined corrective action upon the collection.

## Getting Started

This control will work out-of-the-box with some sensible defaults (configurable via [variables](https://flowpipe.io/docs/build/mod-variables)).

You should be able to simply run the following command in your terminal:

```sh
flowpipe pipeline run detect_and_correct_monitor_log_profiles_without_retention_policy
```

By default, Flowpipe runs in [wizard](https://hub.flowpipe.io/mods/turbot/azure_thrifty#wizard) mode and prompts directly in the terminal for a decision on the action(s) to take for each detected resource.

However, you can run Flowpipe in [server](https://flowpipe.io/docs/run/server) mode with [external integrations](https://flowpipe.io/docs/build/input#create-an-integration), allowing it to prompt for input via `http`, `slack`, `teams`, etc.

Alternatively, you can choose to configure and run in other modes:
* [Notify](https://hub.flowpipe.io/mods/turbot/azure_thrifty#notify): Provides detections without taking any corrective action.
* [Automatic](https://hub.flowpipe.io/mods/turbot/azure_thrifty#automatic): Performs corrective actions automatically without user intervention.