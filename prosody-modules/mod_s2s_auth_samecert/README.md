This module implements the [Same Certificate shortcut] described in [XEP-0344].
Meaning it authenticates server-to-server connections by looking for an already established connection that uses the exact same certificate, reusing
the earlier validation results and letting Prosody skip performing slower validation methods such as [POSH][mod_s2s_auth_posh] twice.

[Same Certificate shortcut]: https://xmpp.org/extensions/xep-0344.html#samecert
