local jid = require "prosody.util.jid";
local sha256 = require "prosody.util.hashes".sha256;
local st = require "prosody.util.stanza";

local host_hats = module:get_option("muc_auto_hats_by_host");

for hat_host, hat_config in pairs(host_hats) do
	if not hat_config.uri then
		hat_config.uri = ("xmpp:%s/hats/%s"):format(module.host, sha256(hat_host..","..module.host, true));
	end
	if not hat_config.title then
		hat_config.title = hat_host;
	end
end

module:hook("muc-build-occupant-presence", function (event)
	local pres = event.stanza;

	local bare_jid = event.occupant and event.occupant.bare_jid or event.bare_jid;
	local occ_host = jid.host(bare_jid);

	local host_hat = host_hats[occ_host];

	if not host_hat then
		return;
	end

	local hats_el = pres:get_child("hats", "urn:xmpp:hats:0");
	if not hats_el then
		hats_el = st.stanza("hats", { xmlns = "urn:xmpp:hats:0" });
		pres:add_direct_child(hats_el);
	end

	hats_el:text_tag("hat", nil, { uri = host_hat.uri, title = host_hat.title });
end);
