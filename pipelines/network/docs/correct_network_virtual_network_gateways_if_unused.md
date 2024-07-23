# Correct Virtual Network Gateways if unused

## Overview

Azure Virtual Network Gateways with no connections still cost money and should be deleted. This pipeline identifies Virtual Network Gateways with no connections and either sends notifications or attempts predefined corrective actions.

This pipeline allows you to specify a collection of Network Gateways with no connections and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_network_virtual_network_gateways_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_network_virtual_network_gateways_if_unused)
- [detect_and_correct_network_virtual_network_gateways_if_unused trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_network_virtual_network_gateways_if_unused)