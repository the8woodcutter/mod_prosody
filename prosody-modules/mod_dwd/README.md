---
summary: 'Dialback-without-Dialback'
labels:
  - Stage-Deprecated
...

::: {.alert .alert-warning}
**Warning:** Between 0.10.0 and 0.11.9 this feature was merged into [mod_dialback], however it was found to have a security issue and was removed in 0.11.9. Do not enable this feature beside experimenting.
:::


Introduction
============

This module implements an optimization of the Dialback protocol, by
skipping the dialback step for servers presenting a valid certificate.

Configuration
=============

Simply add the module to the `modules_enabled` list.

        modules_enabled = {
            ...
            "dwd";
        }

Compatibility
=============

  ------------------ --------------------------
  0.10               Built into mod\_dialback
  0.9 + LuaSec 0.5   Works
  0.8                Doesn't work
  ------------------ --------------------------
