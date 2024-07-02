# Correct one Kusto Cluster without autoscaling

## Overview

Enabling autoscaling for Azure Kusto clusters can significantly optimize costs, especially in environments with fluctuating workloads. Autoscaling adjusts the number of resources based on demand, ensuring you are not over-provisioning and paying for unused capacity.

This pipeline allows you to specify a collection of Kusto clusters with autoscaling disabled and either sends notifications or attempts to perform predefined corrective actions upon the collection.

Whilst it is possible to utilize this pipeline standalone, it is usually called from the [correct_kusto_cluster_without_autoscaling pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.correct_kusto_cluster_without_autoscaling).