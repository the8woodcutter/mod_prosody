---
labels:
- 'Stage-Alpha'
summary: 'Basic support for XEP-0463: MUC Affiliations Versioning'
...

Introduction
============

This module implements [XEP-0463](https://xmpp.org/extensions/xep-0463.html),
specifically version 0.2 of it. It does so without any additional storage
requirements and everything needed is handled in-memory only.

Details
=======

This module does not preserve a version history, it only knows about the state
before and after a change and the current set of affiliations. This means that
if affiliations are changed while a user device is offline, they will receive
a full response when reconnecting with the room. This is in line with the
behavior the XEP describes for the case of the client sending a version unknown
to the server.

Compatibility
=============

Tested only on Prosody 13.
