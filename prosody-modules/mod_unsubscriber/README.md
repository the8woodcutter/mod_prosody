Over the years, some servers stop working for various reasons, and leave behind broken roster subscriptions and dysfunctional group chat bookmarks
that trigger failing s2s connections. Sometimes users make mistakes when adding a contact or group chat, causing your server to make repeated attempts
to connect to a domain with a typo in it.

This module allows cleaning up such cases by unsubscribing local users
from their contacts on those servers.
Use with care.

To use, simply add as a `Component` for each domain you want to stop seeing failed connection logs about.

``` lua
Component "gmail.com" "unsubscriber"
modules_disabled = { "s2s" }
```
