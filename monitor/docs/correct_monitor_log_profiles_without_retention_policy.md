# Correct Monitor log profiles without retention poliy

## Overview

Log profile retention in Azure can significantly impact cost management by controlling the amount of log data stored and the duration for which it is retained.

This pipeline allows you to specify a collection of log profiles without retention poliy and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_monitor_log_profiles_without_retention_policy pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_monitor_log_profiles_without_retention_policy)
- [detect_and_correct_monitor_log_profiles_without_retention_policy trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_monitor_log_profiles_without_retention_policy)