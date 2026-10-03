local http = require "net.http";
local async = require "util.async";
local jid = require "util.jid";
local json = require "util.json";
local sasl = require "util.sasl";

-- Details about the OAuth2 Issuer
local issuer_identity = module:get_option_string("oauth_external_issuer");
local oidc_discovery_url = module:get_option_string("oauth_external_discovery_url",
	issuer_identity and issuer_identity .. "/.well-known/oauth-authorization-server" or nil);

-- OAuth2 endpoints
-- These could be discovered dynamically if unset
local validation_endpoint = module:get_option_string("oauth_external_validation_endpoint");
local token_endpoint = module:get_option_string("oauth_external_token_endpoint");

-- Field used to decide the XMPP address localpart
local username_field = module:get_option_string("oauth_external_username_field", "preferred_username");
local username_mapping = module:get_option_string("oauth_external_username_mapping", "");
local username_unmapping = module:get_option_string("oauth_external_sasl_username_mapping", "");

-- Settings needed for Resource Owner Password Grant, where Prosody acts as an OAuth2 Client
-- Since at this time, no clients support SASL OAUTHBEARER, this is the only way this works
local allow_plain = module:get_option_boolean("oauth_external_resource_owner_password", true);
local client_id = module:get_option_string("oauth_external_client_id");
local client_secret = module:get_option_string("oauth_external_client_secret");
local scope = module:get_option_string("oauth_external_scope", "openid");

local http_settings = module:get_option("oauth_external_http_settings", { connection_pooling = true });

--[[ More or less required endpoints
digraph "oauth endpoints" {
issuer -> discovery -> { registration validation }
registration -> { client_id client_secret }
{ client_id client_secret validation } -> required
}
--]]

assert(validation_endpoint or token_endpoint,
	"One or both of 'oauth_external_validation_endpoint' and 'oauth_external_token_endpoint' must be configured");

-- Apply transforms to username field.
local function username_prep(username) --> string
	if username_mapping == "split" then
		username = jid.node(username);
	end
	return jid.escape(username);
end

-- Apply transforms to SASL username to produce the thing
local function sasl_username_prep(username, realm) --> string
	if username_unmapping == "join" then
		username = jid.join(username, realm);
	end
	return username;
end

local accounts = module:open_store("accounts");

local provider = {};

-- TODO remove, not needed after https://hg.prosody.im/trunk/rev/01f95f3de6fc
local function not_implemented()
	return nil, "method not implemented"
end

-- With proper OAuth 2, most of these should be handled at the authorization
-- server, no there.
provider.test_password = not_implemented;
provider.get_password = not_implemented;
provider.set_password = not_implemented;
provider.create_user = not_implemented;

function provider.delete_user(username)
	return accounts:set(username, nil);
end

function provider.get_account_info(username)
	local account, err = accounts:get(username);
	if not account then return nil, err or "Account not available"; end
	return {
		created = account.created;
		password_updated = account.updated;
		enabled = not account.disabled;
	};
end

function provider.user_exists(username)
	local account, err = accounts:get(username);
	if err then
		return nil, err;
	elseif account then
		return true;
	else
		return false
	end
end

function provider.is_enabled(username) -- luacheck: ignore 212
	local info, err = provider.get_account_info(username);
	if not info then return nil, err; end
	return info.enabled;
end

function provider.enable(username)
	-- TODO map store?
	local account = accounts:get(username);
	account.disabled = nil;
	account.updated = os.time();
	return accounts:set(username, account);
end

function provider.disable(username, meta)
	local account = accounts:get(username);
	account.disabled = true;
	account.disabled_meta = meta;
	account.updated = os.time();
	return accounts:set(username, account);
end

-- Tricky without a standard API for listing users, fallback to recording successful logins.
function provider.users() --> iterator
	return accounts:users();
end

function provider.get_sasl_handler()
	local profile = {};
	profile.http_client = http.default:new(http_settings);
	if token_endpoint and allow_plain then
		function profile:plain_test(username, password, realm)
			username = jid.unescape(username); -- COMPAT Mastodon
			local tok, err = async.wait_for(self.profile.http_client:request(token_endpoint, {
				headers = { ["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"; ["Accept"] = "application/json" };
				body = http.formencode({
					grant_type = "password";
					client_id = client_id;
					client_secret = client_secret;
					username = sasl_username_prep(username, realm);
					password = password;
					scope = scope;
				});
			}))
			if err or not (tok.code >= 200 and tok.code < 300) then
				return false, nil;
			end
			local token_resp = json.decode(tok.body);
			if not token_resp or string.lower(token_resp.token_type or "") ~= "bearer" then
				return false, nil;
			end
			if not validation_endpoint then
				-- We're not going to get more info, only the username
				self.username = username_prep(username);
				self.token_info = token_resp;
				local account, err = accounts:get(self.username);
				if err then
					return
				elseif not account then
					account = { exists = true }
					accounts:set(self.username, account);
				end
				return true, not account.disabled;
			end
			local ret, err = async.wait_for(self.profile.http_client:request(validation_endpoint,
				{ headers = { ["Authorization"] = "Bearer " .. token_resp.access_token; ["Accept"] = "application/json" } }));
			if err then
				return false, nil;
			end
			if not (ret.code >= 200 and ret.code < 300) then
				return false, nil;
			end
			local response = json.decode(ret.body);
			if type(response) ~= "table" or type(response[username_field]) ~= "string" then
				return false, nil, nil;
			end
			self.token_info = response;
			self.username = username_prep(response[username_field]);

			local account, err = accounts:get(self.username);
			if err then
				module:log("error", "Could not read account data: %q", err);
				return false, false;
			elseif not account then
				account = { exists = true }
				local ok, err = accounts:set(self.username, account);
				if not ok then
					module:log("error", "Could not write account data: %q", err);
				end
			end

			return true, not account.disabled;
		end
	end
	if validation_endpoint then
		function profile:oauthbearer(token)
			if token == "" then
				return false, nil, { status = "invalid_token"; scope = scope; oidc_discovery_url = oidc_discovery_url };
			end

			local ret, err = async.wait_for(self.profile.http_client:request(validation_endpoint, {
				headers = { ["Authorization"] = "Bearer " .. token; ["Accept"] = "application/json" };
			}));
			if err then
				-- Connection error rather than HTTP error, e.g. connection refused or certificate validation error.
				module:log("debug", "Error in OAuth2 validation request: %s", err);
				return false, nil, { status = "server_error"; scope = scope; oidc_discovery_url = oidc_discovery_url };
			end
			-- response decoded earlier since it can include an error struct that should be returned to client
			local response = json.decode(ret.body);
			if not (ret.code >= 200 and ret.code < 300) then
				module:log("debug", "Error in OAuth2 validation request: %s", err);
				return false, nil, response or { status = "server_error"; scope = scope; oidc_discovery_url = oidc_discovery_url };
			end
			if type(response) ~= "table" or type(response[username_field]) ~= "string" then
				module:log("error", "OAuth2 Response missing username field %q", username_field);
				module:log("debug", "OAuth2 Response: %q", response);
				return false, nil, { status = "server_error"; scope = scope; oidc_discovery_url = oidc_discovery_url };
			end
			self.token_info = response;

			local username = username_prep(response[username_field]);

			local account, err = accounts:get(username);
			if err then
				module:log("error", "Could not read account data: %q", err);
				return false, false;
			elseif not account then
				account = { exists = true }
				local ok, err = accounts:set(self.username, account);
				if not ok then
					module:log("error", "Could not write account data: %q", err);
				end
			end

			return username, not account.disabled, response;
		end
	end
	return sasl.new(module.host, profile);
end

module:provides("auth", provider);
