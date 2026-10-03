local um = require "prosody.core.usermanager";

local async = require "prosody.util.async";
local filters = require "prosody.util.filters";

local archive = module:open_store("archive", "archive");
local archive_fetches = module:open_store("archive_fetches", "keyval+");

local strategy = module:get_option_enum("smart_retention_strategy", "one", "all");
local min_retention = module:get_option_period("smart_retention_min", false);

local function get_newest_fetched(username, client_id)
	archive_fetches:get_key(username, client_id or "");
end

local function set_newest_fetched(username, client_id, msg_id)
	archive_fetches:set_key(username, client_id or "", {
		newest = msg_id;
	});
end

function handle_query_result(event)
	if not event.start_time then
		module:log("debug", "Ignoring empty query results");
		return; -- empty results
	end

	local origin = event.origin;

	if not origin.outgoing_stanza_queue then
		-- No XEP-0198, so can't reliably determine successful fetches
		module:log("warn", "Ignoring query on non-smacks stream");
		return;
	end

	local newest_result = event.end_id;
	local newest_fetched = get_newest_fetched(origin.username, origin.client_id);

	if newest_result <= newest_fetched then
		-- The client hasn't actually fetched anything newer than before
		return;
	end

	origin.outgoing_stanza_queue:add_checkpoint(function ()
		origin.log("debug", "Recording successful delivery of messages  up to %s", newest_result);
		set_newest_fetched(origin.username, origin.client_id, newest_result);
	end);
end

function handle_sent(stanza, session)
	local msg_id = stanza.name == "message" and stanza:get_meta("archive-id");
	if not msg_id then return stanza; end

	local queue = session.outgoing_stanza_queue;
	if not queue then return stanza; end

	queue:add_checkpoint(function ()
		session.log("debug", "Recording successful delivery of message %s", msg_id);
		set_newest_fetched(session.username, session.client_id, msg_id);
	end);

	return stanza;
end

module:hook("resource-bind", function (event)
	event.session.log("debug", "Installing filter to track message delivery");
	filters.add_filter(event.session, "stanzas/out", handle_sent);
end);

module:hook("archive-query", handle_query_result);

module:daily("Clean up delivered messages", function ()
	local n_users, n_messages = 0, 0;
	for username in assert(um.users(module.host)) do
		local clients = archive_fetches:get(username);
		if clients then
			local newest, oldest;
			for client_id, fetch_info in pairs(clients) do --luacheck: ignore 213/client_id
				local fetched = fetch_info.newest;
				if not newest or fetched > newest then
					newest = fetched;
				end
				if not oldest or fetched < oldest then
					oldest = fetched;
				end
			end

			local expire_older_than;
			if strategy == "one" then
				expire_older_than = newest;
			elseif strategy == "all" then
				expire_older_than = oldest;
			end

			module:log("debug", "Expiring messages prior to %s for %s", expire_older_than, username);

			local item, expire_before = archive:get(username, expire_older_than);
			if not item and expire_before ~= "item-not-found" then
				module:log("warn", "Error fetching item '%s' for '%s': %s", expire_older_than, username, expire_before);
			else
				local ok, err = archive:delete(username, {
					["end"] = expire_before;
					["before"] = min_retention ~= math.huge and (now() - min_retention) or nil;
				});
				if ok then
					local n_deleted = tonumber(ok);
					if n_deleted then
						n_messages = n_messages + n_deleted;
					end
				else
					module:log("warn", "Expiry failure: deleting messages before %s for %s: %s", expire_older_than, username, err);
				end
			end
			n_users = n_users + 1;
			async.sleep(0.1);
		end
	end
	if n_users > 0 then
		module:log("info", "Expired %d delivered messages for %d users", n_messages, n_users);
	end
end);
