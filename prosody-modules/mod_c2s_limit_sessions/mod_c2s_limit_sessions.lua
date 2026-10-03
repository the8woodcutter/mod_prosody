-- mod_c2s_limit_sessions

local next, count = next, require "util.iterators".count;

local max_resources = module:get_option_number("max_resources", 10);

local sessions = prosody.hosts[module.host].sessions;
module:hook("pre-resource-bind", function(event)
	local session = event.session;
	if not sessions[session.username] then
		return -- zero sessions
	end
	if count(next, sessions[session.username].sessions) >= max_resources then
		event.error = { condition = "policy-violation", text = "Too many active connections to this account" };
		session:close(event.error);
		return false;
	end
end, -1);
