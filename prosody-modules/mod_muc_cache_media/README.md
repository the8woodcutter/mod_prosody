---
labels:
- 'Stage-Alpha'
summary: 'Cache media sent to a MUC'
---

Introduction
============

This checks for media coming in to the MUC (currently just in the form of OOB
or SIMS) and then downloads it to a local cache to be served from instead.

This saves privacy leaks for senders (leaking their domains) and to some extent
for receivers (who probably trust the MUC more than arbitraty participants in
it).

When a message is moderated, any associated media is deleted from the cache.

This does not use Prosody's internal HTTP server and assumes you will serve the
folder of static files somehow.

Files which cannot be cached (due to HTTP errors or limits below) will be passed
through still with the original URL unchanged by default.

Configuration
=============

`muc_media_store_path` : the path on disk where to store media files
`muc_media_public_base` : the base URI where you will serve the media
`muc_media_max_size` : the maximum size of file to cache

Compatibility
=============

Requires Prosody 13.0 or higher.
