# Correct one Virtual Machine Scale Sets if unused

## Overview

Virtual Machine Scale Sets with no instances attached still cost money and should be deleted.

This pipeline detects unused Virtual Machine Scale Sets and then either sends a notification or attempts to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_virtual_machine_scale_sets_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_virtual_machine_scale_sets_if_unused).
