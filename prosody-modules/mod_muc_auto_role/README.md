---
labels:
- 'Stage-Alpha'
summary: 'Set default role for MUC occupants based on policies'
...

Introduction
============

This module allows you to apply policies to occupants joining a MUC room, and
choose an appropriate initial role for them.

Details
=======

Depending on configuration, someone who joins a MUC will usually be assigned
one of two roles: "visitor", or "participant".

The "visitor" role does not have permission to speak in moderated rooms. The
"participant" role may speak in moderated rooms.

By default, Prosody assigns "participant" when a MUC is not moderated, and
"visitor" when it is moderated. This allows existing occupants to continue
speaking when a MUC is switched from unmoderated to moderated (e.g. in
response to abuse).

This module overrides the default behaviour, using other signals such as
[XEP-0489: Reporting Account Affiliations](https://xmpp.org/extensions/xep-0489.html),
(which is implemented in Prosody in [mod_report_affiliations](https://modules.prosody.im/mod_report_affiliations))
to decide which role to assign by default.

This allows a smarter approach than simply assigning everyone "visitor" or
"participant".

Configuration
=============

Add the module to the MUC host (not the global modules\_enabled):

        Component "conference.example.com" "muc"
            modules_enabled = { "muc_auto_role" }

You can define (globally or per-MUC component) the following options:

  Name                             Default      Description
  -------------------------------  -----------  ----------------------------------------------------
  muc_auto_role_trusted_servers    `{}`         A list of trusted servers to use RAA info from
  muc_auto_role_trust_threshold    `51`         The minimum RAA trust score which will be considered trusted (for `"participant"` role)
  muc_auto_role_untrusted_servers  `{}`         A list of servers which will always use the `"visitor"` role.
  muc_default_role                 `"visitor"`  The default role to assign when no other policy fits

Compatibility
=============

Requires Prosody 13.0+
