# Correct Compute snapshots if storage premium

## Overview

Migrating compute snapshot storage from premium to standard can lead to significant cost savings. Premium storage is more expensive due to its higher performance and reliability. By moving snapshots that do not require premium performance to standard storage, you can optimize costs without compromising on essential storage needs.

This pipeline allows you to specify a collection of compute snapshots with premium storage and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_snapshot_if_storage_premium pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_compute_snapshot_if_storage_premium)
- [detect_and_correct_compute_snapshot_if_storage_premium trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_compute_snapshot_if_storage_premium)