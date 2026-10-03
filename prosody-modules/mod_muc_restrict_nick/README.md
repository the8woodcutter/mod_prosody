---
labels:
- 'Stage-Beta'
summary: 'Require MUC occupant nicknames to match a specific pattern'
---

Introduction
============

This checks the nickname of a joining user against a configurable
[Lua pattern](https://www.lua.org/manual/5.2/manual.html#6.4.1), and prevents
them from joining if it does not match.

Note the similar module: [mod_muc_reserve_nick_pattern]

Configuration
=============

Load it under a muc component.
There is a single configuration option, `muc_restrict_nick_pattern` and the
default is `"^%w+$"` - i.e. allow only alphanumeric characters in nicknames.

Compatibility
=============

Requires Prosody 0.11 or higher.
