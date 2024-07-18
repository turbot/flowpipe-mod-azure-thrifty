# Correct one Compute disks attached to stopped virtual machine

## Overview

Compute disk can be attached to stopped virtual machine which can cost money. Detaching compute disks from stopped virtual machines can significantly reduce storage costs by eliminating charges for unused disk storage.

This pipeline allows you to specify a collection of compute disks attached to stopped virtual machine and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_attached_to_stopped_virtual_machines pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_compute_disks_attached_to_stopped_virtual_machines).