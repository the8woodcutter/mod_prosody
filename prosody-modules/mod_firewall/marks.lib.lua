local jid = require "prosody.util.jid";

local mark_storage = module:open_store("firewall_marks", "keyval+");

local user_sessions = prosody.hosts[module.host].sessions;

module:hook("resource-bind", function (event)
	local session = event.session;
	local username = session.username;
	local user = user_sessions[username];
	local marks = user.firewall_marks;
	if not marks then
		marks = mark_storage:get(username) or {};
		user.firewall_marks = marks; -- luacheck: ignore 122
	end
	session.firewall_marks = marks;
end);


module:hook("firewall/marked/user", function (event)
	local user = user_sessions[event.username];
	local marks = user and user.firewall_marks;
	if user and not marks then
		-- Load marks from storage to cache on the user object
		marks = mark_storage:get(event.username) or {};
		user.firewall_marks = marks; --luacheck: ignore 122
	end
	if marks then
		marks[event.mark] = event.timestamp;
	end
	local ok, err = mark_storage:set_key(event.username, event.mark, event.timestamp);
	if not ok then
		module:log("error", "Failed to mark user %q with %q: %s", event.username, event.mark, err);
	end
	return true;
end, -1);

module:hook("firewall/unmarked/user", function (event)
	local user = user_sessions[event.username];
	local marks = user and user.firewall_marks;
	if marks then
		marks[event.mark] = nil;
	end
	local ok, err = mark_storage:set_key(event.username, event.mark, nil);
	if not ok then
		module:log("error", "Failed to unmark user %q with %q: %s", event.username, event.mark, err);
	end
	return true;
end, -1);

module:add_item("shell-command", {
	section = "firewall";
	section_desc = "mod_firewall commands";
	name = "mark";
	desc = "Add a firewall mark to a user account";
	args = {
		{ name = "user_jid", type = "string" };
		{ name = "mark_name", type = "string" };
	};
	host_selector = "user_jid";
	handler = function(self, user_jid, mark_name) --luacheck: ignore 212/self 212/host
		local username, host = jid.split(user_jid);
		if not username or not prosody.hosts[host] then
			return nil, "Invalid JID supplied";
		elseif not idsafe(mark_name) then
			return nil, "Invalid characters in mark name";
		end
		if not module:fire_event("firewall/marked/user", {
			username = session.username;
			mark = mark_name;
			timestamp = os.time();
		}) then
			return nil, "Failed to set mark";
		end
		return true, "Marked";
	end;
});

module:add_item("shell-command", {
	section = "firewall";
	section_desc = "mod_firewall commands";
	name = "unmark";
	desc = "Remove a firewall mark from a user account";
	args = {
		{ name = "user_jid", type = "string" };
		{ name = "mark_name", type = "string" };
	};
	host_selector = "user_jid";
	handler = function(self, user_jid, mark_name) --luacheck: ignore 212/self 212/host
		local username, host = jid.split(user_jid);
		if not username or not hosts[host] then
			return nil, "Invalid JID supplied";
		elseif not idsafe(mark_name) then
			return nil, "Invalid characters in mark name";
		end
		if not module:fire_event("firewall/unmarked/user", {
			username = session.username;
			mark = mark_name;
			timestamp = os.time();
		}) then
			return nil, "Failed to remove mark";
		end
		return true, "Unmarked";
	end;
});

module:add_item("shell-command", {
	section = "firewall";
	section_desc = "mod_firewall commands";
	name = "marked";
	desc = "List all user accounts with a specific firewall mark";
	args = {
		{ name = "host", type = "string" };
		{ name = "mark_name", type = "string" };
	};
	host_selector = "host";
	handler = function(self, host, mark_name) --luacheck: ignore 212/self 212/host
		if not idsafe(mark_name) then
			return nil, "Invalid characters in mark name";
		end
		local users = mark_storage:get_key_from_all(mark_name);
		local usernames = {};
		for username in it.keys(users) do
			table.insert(usernames, username);
		end
		table.sort(usernames, function (a, b)
			return users[a] < users[b];
		end);
		for _, username in ipairs(usernames) do
			self.session.print(username, os.date("%Y-%m-%d %R:%s", users[username]));
		end
		return true, ("Showing %d users"):format(#usernames);
	end;
});

