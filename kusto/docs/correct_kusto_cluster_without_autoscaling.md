# Correct Kusto Clusters without autoscaling

## Overview

Enabling autoscaling for Azure Kusto clusters can significantly optimize costs, especially in environments with fluctuating workloads. Autoscaling adjusts the number of resources based on demand, ensuring you are not over-provisioning and paying for unused capacity.

This pipeline allows you to specify a collection of Kusto clusters with autoscaling disabled and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from either:

- [detect_and_correct_kusto_cluster_without_autoscaling pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_kusto_cluster_without_autoscaling)
- [detect_and_correct_kusto_cluster_without_autoscaling trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_kusto_cluster_without_autoscaling)