---
summary: Authenticate against an external OAuth 2 / OIDC IdP
labels:
- Stage-Alpha
---

This module provides external authentication via an external [OAuth
2](https://datatracker.ietf.org/doc/html/rfc7628) authorization server
and supports the [SASL OAUTHBEARER authentication][rfc7628]
mechanism as well as PLAIN for legacy clients (this is all of them).

# How it works

Using OAuth 2.0 in XMPP is explained in [XEP-0493: OAuth Client Login].
Clients pass tokens from the Authorization Server to Prosody, which
attempts to validate the tokens using the configured validation
endpoint.

Legacy clients have to use SASL PLAIN, where Prosody acts as an OAuth 2
Client and receives the users username and password and attempts to
validate this using the OAuth 2 resource owner password grant.

# Configuration

## Examples

### KeyCloak example

```lua
VirtualHost "example.net"
authentication = "oauth_external"

-- KeyCloak URLs
oauth_external_discovery_url = "https://auth.example.com/auth/realms/ExampleRealm/.well-known/openid-configuration"
oauth_external_token_endpoint = "https://auth.example.com/auth/realms/ExampleRealm/protocol/openid-connect/token"
oauth_external_validation_endpoint = "https://auth.example.com/auth/realms/ExampleRealm/protocol/openid-connect/userinfo"
oauth_external_username_field = "xmpp_username"
```

### Mastodon Example

```lua
VirtualHost "example.net"
authentication = "oauth_external"

oauth_external_token_endpoint = "https://mastodon.example/oauth/token"
oauth_external_validation_endpoint = "https://mastodon.example/api/v1/accounts/verify_credentials"
oauth_external_username_field = "username"
oauth_external_scope = "read:accounts"
oauth_external_resource_owner_password = true
```

## Settings

`oauth_external_issuer`
:   Optional URL string representing the Authorization server identity.

`oauth_external_discovery_url`
:   Optional URL string pointing to [OAuth 2.0 Authorization Server
    Metadata](https://oauth.net/2/authorization-server-metadata/). Lets
    clients discover where they should retrieve access tokens from if
    they don't have one yet. Defaults to
    `issuer_identity + "/.well-known/oauth-authorization-server"` when
    `oauth_external_issuer` is set, otherwise unset.

`oauth_external_validation_endpoint`
:   URL string. The token validation endpoint, should validate the token
    and return a JSON structure containing the username of the user
    logging in the field specified by `oauth_external_username_field`.
    Required for SASL OAUTHBEARER. For SASL PLAIN, enables username
    lookup. Commonly the [OpenID `UserInfo`
    endpoint](https://openid.net/specs/openid-connect-core-1_0.html#UserInfo)
    If left unset, only `SASL PLAIN` is supported and the username
    provided there is assumed correct.

`oauth_external_username_field`
:   String. Default is `"preferred_username"`. Field in the JSON
    structure returned by the validation endpoint that to be used as the
    XMPP localpart. The field must be unique and always be the same for
    the same user, to avoid unintentional impersonation.

`oauth_external_username_mapping`
:   String. Default is `""`. Specifies the mapping(s) to apply to the
    username field. Currently only one is defined; `"split"` which
    splits out the username part from e.g. an email address. Escaping
    per [XEP-0106: JID Escaping] is always applied.

`oauth_external_sasl_username_mapping`
:   String. Default is `""`. Specifies the mapping(s) to apply to the
    username given in SASL PLAIN to produce the username sent to the
    Authorization server.
    Currently only one is defined; `"join"` which adds `@` and the domain name.

`oauth_external_resource_owner_password`
:   Boolean. Defaults to `true`. Enables SASL PLAIN for legacy XMPP
    clients via the [resource owner password
    grant](https://oauth.net/2/grant-types/password/) *(considered
    insecure)*.

`oauth_external_token_endpoint`
:   URL string. OAuth 2 [Token
    Endpoint](https://www.rfc-editor.org/rfc/rfc6749#section-3.2) used
    to validate credentials passed via SASL PLAIN.

`oauth_external_client_id`
:   String. Client ID used to identify Prosody in the resource owner
    password grant.

`oauth_external_client_secret`
:   String. Client secret used to identify Prosody in the resource owner
    password grant.

`oauth_external_scope`
:   String. Defaults to `"openid"`. Communicated to clients via
    OAUTHBEARER as scope "valid to access the service". Included in
    request for resource owner password grant.

`oauth_external_http_settings`
:   Table. Defaults to `{ connection_pooling = true }`.
    Settings applied to the HTTP requests sent to the Authorization server.

# Compatibility

## Prosody

  Version   Status
  --------- -----------------------------------------------
  trunk     works
  13.0.x    works
  0.12.x    OAUTHBEARER will not work, otherwise untested
  0.11.x    OAUTHBEARER will not work, otherwise untested

## Identity Provider

Tested with

-   [KeyCloak](https://www.keycloak.org/)
-   [Mastodon](https://joinmastodon.org/)

# Future work

-   Automatically discover endpoints from Discovery URL
-   [SCRAM over HTTP?!][rfc7804]
-   ID Tokens
