---
labels:
- 'Stage-Beta'
summary: 'Infer threads for clients that do not send them'
...

Introduction
============

Some clients have no UI for determining what <thread/> a message should have,
but do support XEP-0461 replies. This module will infer the right thread from
the parent if there is none but this is a reply.

Compatibility
=============

  ----- --------------------------------------------------
  trunk Works
  0.13  Works
  0.12  Works
  ----- --------------------------------------------------
