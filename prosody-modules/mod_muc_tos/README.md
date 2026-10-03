---
summary: Send a PM to newly joined users
labels:
- Stage-Alpha
...

## Introduction

This module adds a Terms of Service message to Prosody rooms.
Unlike [mod_muc_require_tos] this module does not enforce anything. (so far)
It is an informational message.
The message is configured through the room configuration form and is sent as a groupchat message but only to unaffiliated users when they join the room.
The module keeps a per-room cache of users who have already received the message, so that the message is not sent repeatedly.

The module will reserve the nickname *mod_muc_tos* to send messages with it.

## Configuration

Add the module to the MUC host:

```lua
Component "conference.example.com" "muc"
  modules_enabled = {
    "muc_tos";
  }
```

The following global or per-MUC Component configuration option is available:

```lua
--Maximum number of users kept in the per-room cache
muc_tos_max_users = 200
```

It defaults to 200, Range 1-10000

## Usage

The TOS message itself is configured by the room owner from the room configuration form with ad-hoc enabled clients.
Leave the message empty to disable the feature for a room.

## Storage

The module uses a `keyval+` store named `muc_tos_store`.
Assuming file based storage, the information will be stored at your storage location under /path/to/prosody_data/your-muc-component/muc_tos_store/
For a huge muc_tos_max_users value, I would recommend an sql based store, but actual numbers were not tested.

## Compatibility

Requires Prosody 13.0 or higher.
