# Detect & correct AppService plans if unused

## Overview

Azure AppService plans with no app attached still cost money and should be deleted.

This pipeline allows you to specify a collection of AppService plans with no app attached and either sends notifications or attempts to perform predefined corrective actions upon the collection.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `app_service_plans_if_unused_trigger_enabled` should be set to `true` as the default is `false`.
- `app_service_plans_if_unused_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `app_service_plans_if_unused_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_app_service_plan"` to delete app service plan).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```