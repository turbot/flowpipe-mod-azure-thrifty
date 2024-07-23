# Detect & correct Virtual Machine Scale Sets if unused

## Overview

Virtual Machine Scale Sets with no instances attached still cost money and should be deleted.

This pipeline detects unused Virtual Machine Scale Sets and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `virtual_machine_scale_sets_if_unused_trigger_enabled` should be set to `true` as the default is `false`.
- `virtual_machine_scale_sets_if_unused_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `virtual_machine_scale_sets_if_unused_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_virtual_machine_scale_set"` to delete the virtual machine scale set).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```