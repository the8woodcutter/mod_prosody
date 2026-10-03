---
labels:
- 'Stage-Stable'
summary: Log failed authentication attempts with their IP address
...

Introduction
============

Prosody doesn't write IP addresses to its log file by default for
privacy reasons (unless debug logging is enabled).

This module enables logging of the IP address in a failed authentication
attempt so that those trying to break into accounts for example can be
blocked.

fail2ban configuration
======================

fail2ban is a utility for monitoring log files and automatically
blocking "bad" IP addresses at the firewall level.

With this module enabled in Prosody you can use the following example
configuration for fail2ban:

    # /etc/fail2ban/filter.d/prosody-auth.conf
    # Fail2Ban configuration file for prosody authentication
    [Definition]
    failregex = Failed authentication attempt \(not-authorized\) for user .* from IP: <HOST>
    ignoreregex =

And at the appropriate place (usually the bottom) of
/etc/fail2ban/jail.conf add these lines:

    [prosody]
    enabled = true
    port    = 5222
    filter  = prosody-auth
    logpath = /var/log/prosody/prosody*.log
    maxretry = 6

Compatibility
-------------

  ------- --------------------
  trunk   Works as of 26-03-15
  13.x    Works
  0.12    Works
  ------- --------------------
