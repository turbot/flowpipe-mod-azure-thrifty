# Correct one Compute disk exceeding max age

## Overview

Compute disk can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a single compute disks exceeding max age and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_exceeding_max_size pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_compute_disks_exceeding_max_size).