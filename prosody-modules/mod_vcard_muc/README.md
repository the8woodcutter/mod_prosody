---
labels:
- Stage-Obsolete
superseded_by: mod_muc
summary: Support for MUC vCards and avatars
---

::: {.alert .alert-info}
This feature is included in Prosody since version 13.0. It will not install from this version on.
:::

# Introduction

This module adds the ability to set vCard for MUC rooms. One of the most common use case is to be able to define an avatar for your own MUC room.

# Usage

Add "vcard_muc" to your modules_enabled list:

``` lua
Component "conference.example.org" "muc"
modules_enabled = {
  "vcard_muc",
}
```

# Compatibility

  ------ -----------------------------------------
  13     Room avatar feature included in Prosody
  0.12   Works
  ------ -----------------------------------------
