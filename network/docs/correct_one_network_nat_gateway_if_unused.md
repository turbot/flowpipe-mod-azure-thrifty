# Corect one Network NAT gateway if unused

## Overview

Azure Network NAT gateways with no subnets attached still cost money and should be deleted.

This pipeline allows you to specify a collection of Network load balancers and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from the [correct_network_nat_gateways_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_network_nat_gateways_if_unused).