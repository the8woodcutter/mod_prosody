local jid = require "prosody.util.jid";
local datetime = require "prosody.util.datetime";

local xmlns_aff = "urn:xmpp:raa:0";

local raa_servers = module:get_option_set("muc_auto_role_trusted_servers", {});
local trust_threshold = module:get_option_integer("muc_auto_role_trust_threshold", 51, 0, 100);
local age_threshold = module:get_option_period("muc_auto_role_age_threshold", "1d");

local untrusted_servers = module:get_option_set("muc_auto_role_untrusted_servers", {});

local default_role = module:get_option_enum("muc_default_role", "visitor", "participant");

-- TODO: This should be a config option in mod_muc
module:hook("muc-get-default-role", function (event)
	if (event.affiliation or "none") == "none" then
		return default_role;
	end
end, 5);

module:hook("muc-occupant-pre-join", function (event)
	local stanza = event.stanza;

	if event.room:get_affiliation(event.occupant.bare_jid) then
		-- Skip for already-affiliated users
		return;
	end

	local from_host = jid.host(stanza.attr.from);

	if untrusted_servers:contains(from_host) then
		event.occupant.role = "visitor";
	end

	if not raa_servers:contains(from_host) then
		return;
	end

	local raa = stanza:get_child("info", xmlns_aff);
	if not raa then
		return;
	end

	local aff = raa.attr.affiliation;
	local trust = tonumber(raa.attr.trust) or 50;
	local since = raa.attr.since and datetime.parse(raa.attr.since);
	local age = since and (os.time() - since);

	if (aff == "member" or aff == "admin") or (trust >= trust_threshold and (not age or age >= age_threshold)) then
		event.occupant.role = "participant";
	else
		event.occupant.role = "visitor";
	end

	module:log("debug", "Assigning <%s> role '%s' due to affiliation %s, trust score %d, age %d of <%s>",
		event.occupant.nick, event.occupant.role, aff, trust, age or -1, stanza.attr.from
	);

end);
