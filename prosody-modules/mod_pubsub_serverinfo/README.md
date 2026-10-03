---
labels:
- 'Statistics'
...

Exposes server information over Pub/Sub per [XEP-0485: PubSub Server Information](https://xmpp.org/extensions/xep-0485.html).

The module announces support (used to 'opt-in', per the XEP) and publishes the name of the local domain via a Pub/Sub node. The published data
will contain a 'remote-domain' element for inbound and outgoing s2s connections. These elements will be named only when the remote domain announces
support ('opts in') too.

**Known issues:**

- [Issue #1841](https://issues.prosody.im/1841): In Prosody 0.12, this module conflicts with mod_server_contact_info (both will run, but it may affect the ability of some implementations to read the server/contact information provided). To work around this issue, the [mod_server_contact_info](https://modules.prosody.im/mod_server_contact_info) community module can be used.

Configuration
=============

### Loading the module

Simply enable this module on the hosts/components that you want to publish information for. Note that, as with most other modules, adding it to the
global `modules_enabled` will automatically load it on all VirtualHosts on your server:

```
modules_enabled = {
    ...
    "pubsub_serverinfo";
    ...
}
```

Note that adding it to the global modules_enabled won't load it on any Component hosts on your server. If you want to publish info about those, you
also need to add it to a `modules_enabled` setting under that Component, for example:

```
Component "rooms.example.com" "muc"
    modules_enabled = {
    	"pubsub_serverinfo";
    }
```

### Specifying the publish destination

This module publishes information to any XMPP pubsub service, which could be local (i.e. served by the same Prosody instance) or remote (via
server-to-server connections).

The destination to publish to is controlled by two settings:

- `pubsub_serverinfo_service`
- `pubsub_serverinfo_node`

As usual, these options can be set in the global section (inherited by all hosts/component) or underneath each VirtualHost/Component to apply
to that VirtualHost/Component only.

If unset, `pubsub_serverinfo_service` will default to `pubsub.<domain>` - that is, it will try to publish to a pubsub service that is on the
`pubsub` subdomain of the host it is publishing about. For example, if you load the module on `example.com` it will default to publishing to
`pubsub.example.com`. If this is incorrect, you should set `pubsub_serverinfo_service` to a valid pubsub service address.

The `pubsub_serverinfo_node` option defaults to `serverinfo/<host>` where `<host>` is replaced by the name of the publishing host. Note that
if you override this default, you *must* set it to something unique for each host you publish from, otherwise they will conflict or overwrite
each other.

### Pubsub service configuration

As mentioned, you can publish to a local or remote pubsub service. The publish commands will come from the reporting domain(s) where the module
is loaded (e.g. `example.com`), so those domains must be permitted to publish to the destination pubsub service you have chosen.

If you want to run a local pubsub service in the same Prosody instance, you can use this configuration:

```
Component "pubsub.example.com" "pubsub"
    -- Grant permission for example.com to publish here, by simply making it
    -- an admin:
    admins = { "example.org" }
```

### Other settings

To prevent a surplus of event notifications, this module will only publish new data after a certain period of time has expired. The default duration
is 300 seconds (5 minutes). To change this simply put in the config:

```
    pubsub_serverinfo_publication_interval = 180 -- or any other number of seconds
```

To detect if remote domains allow their domain name to be included in the data that this module publishes, this module will perform a service
discovery request to each remote domain. To prevent a continuous flood of disco/info requests, the response to these requests is cached. By default,
a cached value will remain in cache for one hour. This duration can be modified by adding this configuration option:

```
    pubsub_serverinfo_cache_ttl = 1800 -- or any other number of seconds
```

To include the count of active (within the past 30 days) users:

```
    pubsub_serverinfo_publish_user_count = true
```

Enabling this option will automatically load mod_measure_active_users, which must be installed.

Compatibility
=============

Incompatible with 0.11 or lower.

Known Issues / TODOs
====================

The reported data does not contain the optional 'connection' child elements. These can be used to describe the direction of a connection.

Common Configuration Issues
===========================

### Incorrect permissions on pubsub service

The XMPP domain itself (for example, `example.org`) must be allowed to publish to the chosen pubsub service, e.g. by making it an admin of that service.
Sometimes people mistakenly assume a user JID (e.g., `admin@example.org`) should be an admin. See the example above for correct configuration.

### Enabling the module on the wrong host

`mod_pubsub_serverinfo` must be enabled globally or within a virtual host, **not inside the PubSub component** (unless you want to publish info about that
component). Generally you are instructing other hosts to publish data to the pubsub service, not extending the pubsub service itself.

Additionally, be aware that adding mod_pubsub_serverinfo to the global modules_enabled will not load it on any Components by default, you must still specify
that explicitly (see the earlier configuration example).

### Conditional dependency on `mod_measure_active_users`

Publishing user counts requires `mod_measure_active_users`. This module will be loaded automatically if user count publication is enabled, but it must be installed on the system for this to succeed.

### DNS records for the PubSub service

External servers must be able to connect to the PubSub service. Ensure the hostname of the PubSub service has appropriate A/AAAA and SRV records so remote servers can discover and reach the service.
You can use the 'prosodyctl check' command to help with this.
