# Correct Compute virtual machines with low utilization

## Overview

Azure Compute virtual machines with low utilization should be reviewed for either down-sizing or stopping if no longer required in order to reduce running costs.

This pipeline allows you to specify a collection of Compute virtual machines and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_virtual_machines_with_low_utilization pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_compute_virtual_machines_with_low_utilization)
- [detect_and_correct_compute_virtual_machines_with_low_utilization trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_compute_virtual_machines_with_low_utilization)
