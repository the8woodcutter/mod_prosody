--% requires: s2sout-pre-connect-event

module:set_global();

local basic_resolver = require "net.resolvers.basic";
local base32 = module:require("base32");
local net = require "prosody.util.net";

local ip = require "prosody.util.ip";
local parse_cidr = require "prosody.util.ip".parse_cidr;

local mesh_ranges = module:get_option("s2s_v6mesh_ranges", {});
local trust_all_certs = module:get_option_boolean("s2s_v6mesh_trust_all_certs", true);

local function is_secure_range(remote_ip)
	for range, range_config in pairs(mesh_ranges) do
		if ip.match(remote_ip, parse_cidr(range)) then
			return range, range_config;
		end
	end
	return nil;
end

function lookup(dom)
	local lendiff = 26 - #dom;

	if lendiff < 0 then
		return nil; -- domain invalid; too long
	elseif lendiff > 0 then
		dom = dom:gsub("%-", ("a"):rep(lendiff+1));
		if #dom ~= 26 then
			return nil; -- domain invalid
		end
	end

	local raw = base32.decode(dom);
	if not raw then return nil; end

	return net.ntop(raw), raw;
end

local function apply_range_config(host_module, host, session, target_ip)
	local range, range_config = is_secure_range(target_ip);

	if range then
		if range_config.use_tls == false then
			host_module:log("debug", "Treating non-TLS connection to %s as secure because of range configuration", host);
			session.secure = true;
		end
		if range_config.trust_all_certs ~= false then
			module:log("debug", "Auto-trusting certificate for %s because of range configuration", host);
			session.authenticated_remote = true;
			session.cert_chain_status = "valid";
			session.cert_identity_status = "valid";
		else
			module:log("debug", "Not auto-trusting certificate for $s (IP in unconfigured range): %s", host);
		end
	elseif trust_all_certs then
		module:log("debug", "Auto-trusting certificate for %s because of default policy", host);
		session.authenticated_remote = true;
		session.cert_chain_status = "valid";
		session.cert_identity_status = "valid";
	end
end

function module.add_host(host_module)
	host_module:hook("s2sout-pre-connect", function(event)
		local session = event.session;
		local host = session.to_host;
		local dom = host:match("([%w-]+)%.v6%.alt$");
		if not dom then return; end

		local target_ip = lookup(dom);
		if not target_ip then
			return;
		end

		host_module:log("debug", "Resolved %s to [%s]:%d", host, target_ip, 5269);

		event.resolver = basic_resolver.new(target_ip, 5269, "tcp", {});

		local range_ip = ip.new_ip(target_ip, "IPv6");
		apply_range_config(host_module, host, session, range_ip);
	end);

	host_module:hook("s2s-stream-features", function (event)
		local session = event.origin;
		local host = session.from_host;

		local dom = host:match("([%w-]+)%.v6%.alt$");
		if not dom then
			return;
		end

		local remote_ip = ip.new_ip(session.ip);

		if select(2, lookup(dom)) ~= remote_ip.packed then
			host_module:log("warn", "Rejecting incoming connection from %s: unexpected IP %s", host, remote_ip);
			session:close({ condition = "not-authorized", text = "Hostname does not match IP address" });
			return;
		end

		apply_range_config(host_module, host, session, remote_ip);
	end, 200);
end

module:hook("s2s-check-certificate", function(event)
	local session, host = event.session, event.host;

	local dom = host:match("([%w-]+)%.v6%.alt$");
	if not dom then
		return;
	end

	local remote_ip = ip.new_ip(session.ip);

	if select(2, lookup(dom)) ~= remote_ip.packed then
		module:log("warn", "Unable to authenticate incoming connection from %s: unexpected IP %s", host, remote_ip);
		return;
	end

	local range, range_config = is_secure_range(remote_ip);
	if range then
		if range_config.trust_all_certs ~= false then
			module:log("debug", "Auto-trusting certificate for %s because of IP match", host);
			session.cert_chain_status = "valid";
			session.cert_identity_status = "valid";
		else
			module:log("debug", "Not auto-trusting certificate for $s (IP in unconfigured range): %s", host);
		end
	elseif trust_all_certs then
		module:log("debug", "Auto-trusting certificate for %s because of default policy", host);
		session.authenticated_remote = true;
		session.cert_chain_status = "valid";
		session.cert_identity_status = "valid";
		return true;
	end

	if not session.conn.extra then
		session.conn.extra = {};
	end
	-- This can be used by mod_s2s_auth_certs to validate IP certificates,
	-- if supported.
	session.conn.extra.secure_hostname = tostring(remote_ip);
end, 600);

module:add_item("shell-command", {
	section = "v6alt";
	section_desc = module.name.." utility commands";
	name = "get_domain";
	desc = "Convert an IPv6 address to a .v6.alt domain";
	args = {
		{ name = "ip", type = "string" };
	};
	handler = function(self, ip_str) --luacheck: ignore 212/self 212/host
		local user_ip = ip.new_ip(ip_str, "IPv6");
		if not user_ip then
			return nil, "Invalid IP address: "..tostring(ip_str);
		end

		local encoded = base32.encode(user_ip.packed):gsub("=+$", "");
		local longest_a_start, longest_a_len;
		for pos, seq in encoded:gmatch("()(aa+).", 2) do
			if not longest_a_len or #seq >= longest_a_len then
				longest_a_start, longest_a_len = pos, #seq;
			end
		end
		if longest_a_len then
			encoded = encoded:sub(1, longest_a_start - 1) .. "-" .. encoded:sub(longest_a_start + longest_a_len, -1);
		end
		return true, ("Encoded hostname: %s.v6.alt"):format(encoded);
	end;
});

module:add_item("shell-command", {
	section = "v6alt";
	section_desc = module.name.." utility commands";
	name = "get_ip";
	desc = "Convert a .v6.alt domain to an IP address";
	args = {
		{ name = "domain", type = "string" };
	};
	handler = function(self, domain) --luacheck: ignore 212/self 212/host
		local encoded = domain:match("([%w-]+)%.v6%.alt$");
		if not encoded then
			return nil, "Invalid domain: "..domain;
		end
		local user_ip = lookup(encoded);
		return true, ("IP address: %s"):format(user_ip);
	end;
});

module:add_item("shell-command", {
	section = "v6alt";
	section_desc = module.name.." utility commands";
	name = "range";
	desc = "Check whether a host/IP address is within a configured range";
	args = {
		{ name = "ip", type = "string" };
	};
	handler = function(self, str) --luacheck: ignore 212/self 212/host
		local encoded = str:match("([%w-]+)%.v6%.alt$");

		local ip_str = encoded and lookup(encoded) or str;
		local user_ip = ip.new_ip(ip_str, "IPv6");
		if not user_ip then
			return nil, "Invalid domain or IP: "..tostring(str);
		end

		local range, range_config = is_secure_range(user_ip);

		if not range then
			return true, "Not configured";
		end

		self.session.print(("In range: %s"):format(range));
		self.session.print(("Use TLS: %s"):format(range_config.use_tls == false and "no" or "yes"));
		self.session.print(("Trust certs: %s"):format(range_config.trust_all_certs == false and "no" or "yes"));

		return true, "IP is in configured range";
	end;
});
