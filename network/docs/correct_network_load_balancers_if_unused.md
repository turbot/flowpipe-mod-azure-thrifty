# Correct Network load balancers if unused

## Overview

Azure Network load balancers with no backend service instance attached still cost money and should be deleted.

This pipeline allows you to specify a collection of Network load balancers with no backend service instance attached and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from either:

- [detect_and_correct_network_load_balancers_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_network_load_balancers_if_unused)
- [detect_and_correct_network_load_balancers_if_unused trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_network_load_balancers_if_unused)