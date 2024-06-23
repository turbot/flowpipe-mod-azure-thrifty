# Corect one Virtual NAT gateways if unused

## Overview

Azure Virtual NAT gateways with no subnets attached still cost money and should be deleted.

This pipeline allows you to specify a collection of Network load balancers and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from the [correct_one_virtual_nat_gateway_if_unused pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_one_virtual_nat_gateway_if_unused).