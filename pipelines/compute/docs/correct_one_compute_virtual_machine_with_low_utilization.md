# Correct one Compute virtual machines with low utilization

## Overview

Azure Compute virtual machines with low utilization should be reviewed for either down-sizing or stopping if no longer required in order to reduce running costs.

This pipeline allows you to specify a Compute virtual machines and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_virtual_machines_with_low_utilization pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_compute_virtual_machines_with_low_utilization).