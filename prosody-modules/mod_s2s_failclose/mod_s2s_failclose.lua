module:set_global();
local errors = require "prosody.util.error";
local incoming_s2s = prosody.incoming_s2s;

-- When an outgoing connection fails, close a corresponding incoming connection with a stream error to indicate the problem to the remote
module:hook("s2s-destroyed", function(event)
	local s2sout = event.session;
	if s2sout.type ~= "s2sout_unauthed" then return end
	for s2sin in pairs(incoming_s2s) do
		if s2sin.from_host == s2sout.to_host and s2sin.to_host == s2sout.from_host then
			s2sin:close(errors.new({ condition = "reset", text = "Could not deliver return stanzas, please check your DNS and firewall" }));
		end
	end
end);
