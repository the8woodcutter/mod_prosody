---
labels:
- 'Stage-Alpha'
summary: 'Send invites to MUC affiliated remote JIDs on startup'
...

Purpose
=======

This module sends invites to non-local JIDs that are affiliated as "member",
"owner" or "admin" of rooms. It is a workaround for situations where
participants are kicked of a room by a server shutdown, to signal to their
client that they can join the room again.

Configuration
=============

Add the module to the MUC host (not the global modules\_enabled):

```lua
Component "conference.example.com" "muc"
    modules_enabled = { "muc_invite_affiliated" }
```

You can configure a message associated to the invite with the
`muc_invite_affiliated_reason` configuration entry.

Compatibility
=============

  ------- -------
  trunk*  Works
  ------- -------

*as of 2026-06-08
