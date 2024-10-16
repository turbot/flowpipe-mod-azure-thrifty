# Correct one Compute disk unattached

## Overview

Managing unattached disks is crucial for cost efficiency, as they continue to incur charges while not actively contributing to operational workloads. Regularly identifying and managing these resources can help optimize storage costs and organizational efficiency in Azure.

This pipeline allows you to specify a single unattached compute disk and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_if_unattached pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_compute_disks_if_unattached).