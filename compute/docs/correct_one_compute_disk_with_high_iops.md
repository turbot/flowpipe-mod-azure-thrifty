# Correct one Compute disks with high IOPS

## Overview

Compute disk with high IOPS cost money.

This pipeline allows you to specify a collection of compute disks with high IOPS and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disk_with_high_iops pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_compute_disk_with_high_iops).