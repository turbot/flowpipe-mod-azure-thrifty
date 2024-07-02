# Correct one Monitor log profile without retention poliy

## Overview

Log profile retention in Azure can significantly impact cost management by controlling the amount of log data stored and the duration for which it is retained.

This pipeline allows you to specify a collection of log profiles without retention poliy and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_monitor_log_profiles_without_retention_policy pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_monitor_log_profiles_without_retention_policy).