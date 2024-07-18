# Detect & correct SQL Databases exceeding max age

## Overview

SQL Databases can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a collection of SQL Databases and then either send notifications or attempt to perform a predefined corrective action upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `sql_database_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `sql_database_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `sql_database_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_sql_database"` to delete the SQL database).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```