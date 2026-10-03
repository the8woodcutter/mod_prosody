---
labels:
- Stage-Alpha
summary: Smart retention for MAM archives - expire delivered messages faster
...

Description
===========

This module removes messages from the archive after they have been delivered
to one or all of the user's clients.

Background
==========

The first module for allowing clients to "catch up" with messages that were
received while they were offline was mod_offline. Due to the design of that
protocol, offline messages could only be delivered to a single client before
the server deleted them.

The newer XEP-0313 protocol, implemented by mod_mam, allows servers to cache
messages for a configurable retention period. This allows clients to
synchronize with the user's incoming and outgoing messages, providing a more
flexible "catch up" protocol that is compatible with multiple devices.

The ideal retention period is long enough for all devices to catch up, but not
too long (increased storage and processing requirements on the server,
metadata accumulation, etc.).

This module takes a middle approach. If successful delivery of messages is
known, then they can be removed from the message archive before the global
retention period.

Caveats
=======

To work properly, this module expects clients that:

- Always use XEP-0198 Stream Management
- Always use XEP-0386 Bind 2
- Always query the archive using XEP-0313 during login, synchronizing all
  messages in order (oldest to newest).

If clients do not fit these requirements, you may get unusual results (including,
in the worst case, expiring messages which have not been delivered).

Note also that cleanup of delivered messages is scheduled daily. This means
that even with the `"one"` strategy and no minimum retention time set,
messages are not removed immediately upon delivery, but only after the next
cleanup task runs.

Configuration
=============

Just load this module on a host that also has mod_mam. For example:

```lua
modules_enabled = {
  ...
  "mam";
  "mam_smart_retention";
  ...
}
```

You can then set the following options:

`smart_retention_strategy`
: Can be `"one"` (default) or `"all"`, depending on whether you want to expire
  messages that have been delivered to at least one client, or wait until all
  known clients have received them.

`smart_retention_min`
: An optional minimum amount of time to keep messages for, even if they have
  already been delivered to clients.

Compatibility
=============

Requires Prosody trunk, commit 8fb7408ded73 or later. Not compatible with
Prosody 13.0 or earlier.
