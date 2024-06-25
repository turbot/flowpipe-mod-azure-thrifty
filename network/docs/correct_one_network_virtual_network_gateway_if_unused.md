# Correct one unused Virtual Network Gateway

## Overview

Virtual Network Gateway can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a single Network Gateway and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_network_virtual_network_gateway_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_network_virtual_network_gateway_if_unused).