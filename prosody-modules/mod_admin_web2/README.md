---
labels:
- 'Stage-Alpha'
summary: Web administration interface
rockspec:
  build:
    platforms:
      unix:
        type: command
        build_command: cd admin_web2; sh get_deps.sh
        install_command: |
          cd admin_web2;
          cp mod_admin_web2.lua $(LUADIR);
          cp -r www_files $(PREFIX);
...

Introduction
============

This module is a fork of [mod_admin_web], because that on is incompatible with prosody 13.0.
It was made with only small changes but also without much understanding of lua and the internal workigs of prosody. Use with care. Restrict access from the web.
Patches welcome.

This module provides a basic web-administration interface. It currently
gives you access to Ad-Hoc commands on any virtual host or component. It
also provides a live list of S2S and C2S connections. (buggy, not showing all of them)

**New:** You need to be the global instance operator to access this module. Smiplifying access rights.
**Known Issue:** If you define it on more then one host or globally, it might be nessesary to reload the module to have access to all hosts from within one interface.

Installation
============

1.  Install the module like any other.
2.  **Execute the contained `get_deps.sh` script from within the admin\_web2
    directory.** (Requires wget, tar, and a basic shell)

Configuration Details
=====================

"admin\_web2" needs to be added to the modules\_enabled table of the host
you want to load this module on.

By default the interface will then be reachable under
`http://example.com:5280/admin`, or `https://example.com:5281/admin`.

The module will automatically enable two other modules if they aren't
already: mod\_bosh (used to connect to the server from the web), and
mod\_admin\_adhoc (which provides admin commands over XMPP).

    VirtualHost "example.com"
       modules_enabled = {
           .....
           "admin_web2";
           .....
       }

Compatibility
=============

  --------- ----------------------------------
  13.0      Works
  0.12      not supported, use [mod_admin_web]
  \<= 0.11  not supported
  --------- ----------------------------------
