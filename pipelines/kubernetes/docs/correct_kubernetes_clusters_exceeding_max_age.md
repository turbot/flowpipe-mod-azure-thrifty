# Correct Kubernetes clusters exceeding max age

## Overview

Kubernetes clusters can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a collection of Kubernetes clusters and then either send notifications or attempt to perform a predefined corrective action upon the collection.
Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_kubernetes_clusters_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_kubernetes_clusters_exceeding_max_age)
- [detect_and_correct_kubernetes_clusters_exceeding_max_age trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_kubernetes_clusters_exceeding_max_age)