module:depends("muc");
local time = require "util.time";
local st = require "util.stanza";
local jid = require "util.jid";
local uuid = require "util.uuid";
local cache = require "util.cache";
local room_caches = {};
local tos_store = module:open_store("muc_tos_store", "keyval+");

local TOS_MESSAGE_FIELD = "{xmpp:prosody.im}muc#roomconfig_tos_message";

local max_users = module:get_option_integer("muc_tos_max_users", 200, 1, 10000);

-- Return the configured TOS message for a room.
local function get_tos_message(room)
	return room._data.muc_tos_message or "";
end

local function load_room_cache(room)
	-- Return the existing in-memory cache if it has already been loaded.
	local room_cache = room_caches[room.jid];
	if room_cache then
		return room_cache;
	end

	-- Create a fresh in-memory cache.
	room_cache = cache.new(max_users);
	room_caches[room.jid] = room_cache;
	module:log("debug", "Created TOS user cache for room %s with max size %d", room.jid, max_users);

	-- Load the complete persistent cache for this room.
	local stored_cache, err = tos_store:get(room.jid);
	if err then
		module:log("error", "Failed to load TOS user storage for room %s: %s", room.jid, err);
		return room_cache;
	end

	if type(stored_cache) ~= "table" then
		module:log("debug", "No persistent TOS user storage found for room %s; starting empty", room.jid);
		return room_cache;
	end

	-- Convert the stored entries into array to sort
	local entries = {};

	for bare_jid, timestamp in pairs(stored_cache) do
			table.insert(entries, {
				jid = bare_jid;
				timestamp = timestamp;
			});
	end

	-- Sort oldest -> newest.
	table.sort(entries, function(a, b)
		return a.timestamp < b.timestamp;
	end);

	-- Add entries to cache
	for _, entry in ipairs(entries) do
		room_cache:set(entry.jid, entry.timestamp);
	end

	module:log("debug", "Loaded TOS store for room %s: %d stored users, %d users in memory", room.jid, #entries, room_cache:count());

	return room_cache;
end

local function handle_config_form(event)
	local room = event.room;

	table.insert(event.form, {
		name = TOS_MESSAGE_FIELD;
		type = "text-multi";
		label = "TOS message";
		desc = "Send a PM to unaffiliated users when they first join.";
		value = get_tos_message(room);
	});
end


local function handle_config_submit(event)
	local room = event.room;
	local message = event.value or "";

	if message == get_tos_message(room) then
		return;
	end

	room._data.muc_tos_message = message;
	event.changed = true;

	-- Changing the TOS message resets the caches
	room_caches[room.jid] = cache.new(max_users);
	local ok, err = tos_store:set(room.jid, {});
	if ok then
		module:log("debug", "Cleared TOS user store for room %s after configuration change", room.jid);
	else
		module:log("error", "Failed to clear persistent TOS cache for room %s: %s", room.jid, err);
	end
	module:log("debug", "TOS message %s for room %s", message == "" and "disabled" or "enabled/updated", room.jid);
end


local function handle_new_occupant(event)
	local room = event.room;
	local message = get_tos_message(room);

	if message == "" then
		return;
	end

	-- Give the client a better chance to receive the message.
	-- The server cannot reliably know when the client is actually ready.
	module:add_timer(1.5, function()

		local occupant = event.occupant;
		local bare_jid = occupant.bare_jid;

		-- Members and higher do not receive the TOS message.
		if room:get_affiliation(bare_jid) then
			return;
		end

		--load / create / assign cache(s)
		local tos_cache = load_room_cache(room);

		-- If this JID is already in the cache, the user has already
		-- received the TOS message.
		if tos_cache:get(bare_jid) ~= nil then
			return;
		end

-- Use the room JID as the stable identity for this server-generated message.
		local fake_room_occupant = { bare_jid = room.jid };
		local uid = uuid.generate();
		local stanza = st.message({
			["xml:lang"] = "en";
			type = "groupchat";
			from = room.jid .. "/mod_muc_tos";
			to = occupant.nick;
			id = uid;
		})
		:tag("body"):text(message):up()
		:tag("stanza-id", { xmlns = "urn:xmpp:sid:0"; id = uid; by = room.jid }):up()
		:tag("occupant-id", { xmlns = "urn:xmpp:occupant-id:0"; id = room:get_occupant_id(fake_room_occupant) }):up();

		room:route_to_occupant(occupant, stanza)
--[[

		-- Build the PM. Is this right?
		local stanza = st.message({
			type = "chat";
			from = room.jid;
			to = occupant.jid;
		})
		:tag("body"):text(message):up()
		--:tag("x", { xmlns = "http://jabber.org/protocol/muc#user" });
--conversations denies the message with x
		--origin.send preserves "to":
		event.origin.send(stanza);
]]
		-- Store in-memory cache.
		local timestamp = time.now();
		tos_cache:set(bare_jid, timestamp);
		module:log("debug","User %s in room %s got TOS message. Cache contains %d/%d users",bare_jid,room.jid,tos_cache:count(),max_users);

		-- Store on disk
		local ok, err = tos_store:set_key(room.jid, bare_jid, timestamp);

		if ok then
			module:log("debug","Persisted TOS cache entry for user %s in room %s",bare_jid,room.jid);
		else
			module:log("error","Failed to persist TOS cache entry for user %s in room %s: %s",bare_jid,room.jid,err);
		end
	end);
	return;
end


local function save_room_cache(room_jid, room_cache)
	if not room_cache then
		return;
	end
	-- Build a Lua table from the in-memory cache.
	local stored_cache = {};

	for bare_jid, timestamp in room_cache:items() do
		stored_cache[bare_jid] = timestamp;
	end

	-- Store the cache.
	local ok, err = tos_store:set(room_jid, stored_cache);
	if not ok then
		module:log("error", "Failed to save TOS cache for room %s: %s", room_jid, err);
		return;
	end
	module:log( "debug", "Saved TOS cache for room %s with %d/%d users", room_jid, room_cache:count(), max_users);
end

-- Flush all in-memory caches when the module is unloaded.
function module.unload()
	module:log("info", "Saving TOS caches before module shutdown");

	for room_jid, room_cache in pairs(room_caches) do
		save_room_cache(room_jid, room_cache);
	end

	module:log("info", "Finished saving TOS caches");
end


local function deny_module_nick(event)
    local occupant = event.dest_occupant or event.occupant;

    if jid.resource(occupant.nick) ~= "mod_muc_tos" then
        return;
    end
    event.origin.send(st.error_reply(
        event.stanza,
        "cancel",
        "conflict",
        nil,
        event.room.jid
    ));
module:log("info", "Denied reserved nickname %s for %s", occupant.nick, occupant.bare_jid);
    return true;
end

module:hook("muc-config-form", handle_config_form, 70 - 5);
module:hook("muc-config-submitted/" .. TOS_MESSAGE_FIELD, handle_config_submit);
module:hook("muc-occupant-pre-join", deny_module_nick);
module:hook("muc-occupant-pre-change", deny_module_nick);
module:hook("muc-occupant-session-new", handle_new_occupant);
