# Correct one Network Application Gateway without autoscaling

## Overview

Autoscaling for Azure Application Gateways can provide significant cost optimization benefits by dynamically adjusting the number of instances based on traffic load. This ensures that you are only paying for the resources you need at any given time, avoiding over-provisioning during low traffic periods.

This pipeline allows you to specify a collection of Application Gateway with autoscaling disabled and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from the [correct_network_application_gateway_without_autoscaling pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_one_network_application_gateway_without_autoscaling).