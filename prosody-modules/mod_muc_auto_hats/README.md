---
labels:
- 'Stage-Alpha'
summary: 'Dynamically set hats based on configurable policies'
...

Introduction
============

This module lets you dynamically assign hats to MUC occupants based on
configuration rules.

Currently the only supported rule type is based on the host that the user is
joining from. More rule types may be added in the future.

Configuration
=============

Add the module to the MUC host (not the global modules\_enabled):


``` {.lua}
        Component "conference.example.com" "muc"
            modules_enabled = { "muc_auto_hats" }
```

Then add configuration rules.

Hats are identified by URIs, which must be unique (they are not displayed to
the user). If you don't specify one, Prosody will generate a unique one for
you. Each hat also has a human-readable 'title'. Again, Prosody will generate
a default if you don't specify one.

## By user host

``` {.lua}
muc_auto_hats_by_host = {
	["anon.example.com"] = {
		title = "Web chat";
	};
	["staff.example.com"] = {
		title = "Staff";
		uri = "https://example.com/roles/staff";
	};
}
```

Compatibility
=============

Requires Prosody 13.0+
