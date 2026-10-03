---
labels:
- Stage-Alpha
summary: "Federate using stable IPv6 addresses encoded as hostnames, e.g. in mesh networks"
rockspec:
  build:
    modules:
      mod_s2s_v6mesh.base32: base32.lib.lua
---

## Overview

There are various virtual network overlay projects which provide peers with
stable IPv6 addresses, including [Yggdrasil](https://yggdrasil-network.github.io/),
[CJDNS](https://github.com/cjdelisle/cjdns/), and others.

One problem is that these systems are generally peer-to-peer, and there is
typically no standard DNS root for the private networks. Public DNS can be
used, but that adds a dependency on the public internet which can cause
problems, e.g. if the public internet becomes inaccessible.

The "obvious" solution is to skip domain names, and just federate between IP
addresses directly. Unfortunately this brings a lot of problems, such as
the inability for IP addresses to have subdomains, which are used extensively
in XMPP to allow hosting multiple services on a single IP address.

This module provides an alternative solution. For every possible IPv6 address,
it can generate an encoded hostname, which supports subdomains, and can be
resolved to an IPv6 address without any external DNS server infrastructure.

The domain names end with `.v6.alt`. The `.alt` TLD was defined by [RFC 9476](https://www.rfc-editor.org/rfc/rfc9476.html)
specifically for non-DNS use cases such as this. `.v6.alt` is our own scheme.

## Usage

For this module to be useful for federation:

- Both servers must have this module loaded
- Both servers must have stable IPv6 addresses (if the IP address changes, the
  hostname changes, and your XMPP identity changes - a new hostname is like
  starting fresh).

Although this module was designed with virtual/mesh networks in mind, it is
possible to use it between any two servers with IPv6 addresses (check the
section on connection security below if you are using it over unencrypted
networks such as the public internet).

Discover your hostname with the prosodyctl command (our example will use the
IP address `2a00:1098:3a0::1` but you should replace it with your own):

```
$ prosodyctl shell v6alt get_domain 2a00:1098:3a0::1
OK: Encoded hostname: fiabbgadu-e.v6.alt
```

You can then use this domain name in your config file, for example:

```lua
VirtualHost "fiabbgadu-e.v6.alt" -- Main host, for user accounts

Component "groups.fiabbgadu-e.v6.alt" "muc" -- MUC on a subdomain
```

### Connection security

Prosody typically requires TLS for server-to-server connections. However, it
is not possible to obtain CA-issued certificates for `.v6.alt` domains. This
raises challenges around authentication of peers.

By default, this module treats all certificates as trusted for all `v6.alt`
domains where the IP address matches the domain name that the remote server is
claiming to be (the actual certificate contents are irrelevant and never
checked, so self-signed certificates are fine). This provides a decent balance
between convenience and security.

Connections using v6.alt are automatically safe from whole categories of
attacks such as DNS spoofing/poisoning (because such domains do not use DNS
resolvers). However, any attack which enables an attacker to route an IP
address to their own machine, for example, may be susceptible to a
machine-in-the-middle attack, which cannot be ruled out on the internet.

For ultimate security across untrusted networks, use self-signed certificates
and pin fingerprints in the configuration on both sides using
[mod_s2s_auth_fingerprint](https://modules.prosody.im/mod_s2s_auth_fingerprint).

If you do this, or if you only want v6.alt certificates to be trusted within
explicitly configured network ranges, you can disable the default certificate
trusting behaviour using `s2s_v6mesh_trust_all_certs = false`.

You can configure connection security and trust settings per range, using the
`s2s_v6mesh_ranges` configuration option (more details below).

Regardless of any other options, we always recommend keeping Prosody's default
settings of `s2s_require_encryption = true` and `s2s_secure_auth = true` so
that connections not covered by this module are always encrypted and
authenticated properly.

### Connecting from clients

Note that although Prosody supports `.v6.alt` domains for federation when this
module is loaded, this domain scheme is not (currently?) supported by clients,
and you'll need to specify the connection IP manually in order to connect.

Your JID should always be entered as `<username>@<domain.v6.alt>`, and you
should specify the server's IPv6 address in your client's advanced connection
configuration screen.

### HTTP

Services that use HTTP such as file sharing, web clients, etc. will need to
use the IP address in the URL, as clients and browsers won't be able to
resolve the `.v6.alt` domain names. You will need to [configure Prosody's HTTP
server](https://prosody.im/doc/http) appropriately for your deployment, e.g.

```lua
http_external_url = "https://[2a00:1098:3a0::1]:5281"
```

## Configuration

  | Name                         | Default | Description
  |------------------------------|-------- |-------------------------------------------------------------------------
  | s2s_v6mesh_ranges            | `{}`    | A list of IP ranges and associated configuration (see below)
  | s2s_v6mesh_trust_all_certs   | `true`  | Whether to trust all certs from verified v6.alt addresses (even in unconfigured ranges)

### Range configuration

By default, this module will use TLS, and trust any certificate from a v6.alt
domain if the IP address matches. You can override this behaviour on a
per-range basis:

```lua
s2s_v6mesh_ranges = {
    ["200::/7"] = {
        -- disable TLS requirement for this IP range (overrides s2s_require_encryption)
        use_tls = false;
        -- trust all certificates (even self-signed) within this range (overrides s2s_secure_auth)
        trust_all_certs = true;
    };
}
```

## Compatibility

  |Prosody-Version|Status
  |---------------|----------------------
  |trunk          | Works
  |13.0           | Works
  |0.12           | Does not work


## Developers

This section is for developers who want to encode/decode v6.alt addresses
in their own code.

### Encoding scheme

1. Take an IPv6 address as raw packed bytes
2. Encode it using base32 (RFC 4648), remove `====` padding from the end.
3. Lowercase the output
4. Find the first longest sequence of 'a' characters that is:
     1. Not at the start of the string (start scanning from second position)
     2. Two or more characters in length
     3. Not including the end character

     If found, replace this sequence with a hyphen (`-`).

5. Append `.v6.alt`

### Decoding scheme

1. Take a hostname ending with `.v6.alt`
2. Remove `.v6.alt`
3. Remove any '.' characters and all content before them (`foo.bar` -> `bar`)
4. If the string contains a hyphen, replace that hyphen with sufficient 'a' characters to make the string 26 characters in length. Strings with multiple hyphen characters are invalid and must be rejected.
5. Uppercase the string
6. Decode using base32

### Test vectors

| IP                                        | Domain                             |
|-------------------------------------------|------------------------------------|
| `2001:db8::1`                             | `eaaq3o-e.v6.alt`                  |
| `0200::1`                                 | `ai-e.v6.alt`                      |
| `200:cab8:deb4:ce60:4362:4492:e539:4b5`   | `aiamvog6wthgaq3cisjokoiewu.v6.alt`|
| `::1`                                     | `a-e.v6.alt`                       |
| `::`                                      | `a-a.v6.alt`                       | 
| `fe80::1`                                 | `72-e.v6.alt`                      |
| `ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff` | `77777777777777777777777774.v6.alt`|
| `1111:0000:0000:1111::1111`               | `ceiqaaaaaairc-rce.v6.alt`         |
| `1111:0000:0000:0000:1111::1111`          | `ceiq-eiraaaaaaarce.v6.alt`        |
