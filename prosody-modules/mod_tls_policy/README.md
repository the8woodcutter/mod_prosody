---
summary: Cipher policy enforcement with application level error reporting
labels: [Stage-Obsolete]
...

# Introduction

This module arose from discussions at the XMPP Summit about enforcing
better ciphers in TLS. It may seem attractive to disallow some insecure
ciphers or require forward secrecy, but doing this at the TLS level
would the user with an unhelpful "Encryption failed" message. This
module does this enforcing at the application level, allowing better
error messages.

# Obsolete

Due to differences introduced along with TLS 1.3 this module no longer works as intended, see [issue #1363](https://issues.prosody.im/1363).

