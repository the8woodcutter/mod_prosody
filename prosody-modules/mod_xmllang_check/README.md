---
rockspec:
  build:
    modules:
      mod_xmllang_check.xmpplang: xmpplang.lib.lua
---

# mod_xmllang_check

This module strips invalid `xml:lang` values from S2S outgoing stanzas. This is to avoid issues with ejabberd validating these values.

See notes on ejabberd in `xml-lang-enforcement-findings.md`.

## Configuration

```lua
modules_enabled = {
	"xmllang_check";
}
```
