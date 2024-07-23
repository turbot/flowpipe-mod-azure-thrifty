# Correct Storage account without lifecycle policy

## Overview

Storage account can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a collection of Storage account and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_storage_accounts_without_lifecycle_policy pipeline](https://hub.flowpipe.io/mods/turbot/azure_thrifty/pipelines/azure_thrifty.pipeline.detect_and_correct_storage_accounts_without_lifecycle_policy)
- [detect_and_correct_storage_accounts_without_lifecycle_policy trigger](https://hub.flowpipe.io/mods/turbot/azure_thrifty/triggers/azure_thrifty.trigger.query.detect_and_correct_storage_accounts_without_lifecycle_policy)