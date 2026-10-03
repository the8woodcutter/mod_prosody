---
summary: Strip XEP-0224 Attention from affiliations in rooms
labels:
- Stage-Beta
...

# Introduction

This module can strip [XEP-0224 Attention] for certain affiliations in rooms.
By default it will only allow *Attention* from admins or above.
This can prevent unwanted noise, made with big public channels in mind.

# Configuring

## Enabling

``` {.lua}
Component "rooms.example.net" "muc"
modules_enabled = {
    "muc_restrict_attention";
}
```

## Settings

A default setting for all rooms can be provided in the config file, ("members", "participants", false), defaults to *"members"*.
A loglevel can be set ("debug", "info", "warn", "error").
Defaults to *"debug"*: 

``` {.lua}
muc_restrict_attention_by_default = "members"
muc_restrict_attention_loglevel = "debug"
```

The module adds a room configuration option to choose the behavior for members, overriding the defaults per room.

# Todo

- Restrict fine tuned, per every affiliation in the room config with nice dropdown config option. 

# Compatibility

Work with Prosody >= 13.0
