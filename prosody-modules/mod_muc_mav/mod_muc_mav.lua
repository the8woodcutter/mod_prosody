local st = require "util.stanza";
local hashes = require "util.hashes";
local base64 = require "util.encodings".base64;
local util_jid = require "util.jid";

local mod_muc = module:depends"muc";

local xmlns_mav = "urn:xmpp:muc:affiliations:1";
local xmlns_muc = "http://jabber.org/protocol/muc";
local xmlns_muc_user = "http://jabber.org/protocol/muc#user";
local xmlns_occupant_id = "urn:xmpp:occupant-id:0";

local mav_versions = {}

local function get_affiliations(from, room, hash_only)
	local mav_since = nil
	local jid_affiliations = {}
	local xs = {}
	local x = st.stanza("x", {xmlns = xmlns_muc_user;});
	local count = 0
	for jid, affiliation, affiliation_data in room:each_affiliation() do
		table.insert(jid_affiliations, jid.."\0"..affiliation);
		if not hash_only then
			local occupant_id = room:get_occupant_id_from_jid(jid);
			local nick = affiliation_data and affiliation_data.reserved_nickname or nil;
			local show_jid = (not room:is_anonymous_for(from) or util_jid.bare(from) == jid) and jid or nil
			x:tag("item", {affiliation = affiliation or "none"; jid = show_jid; nick = nick;})
				:tag("occupant-id", { xmlns = xmlns_occupant_id, id = occupant_id }):up():up();
			count = count + 1
			if count > 400 then
				table.sort(jid_affiliations)
				local hash_input = table.concat(jid_affiliations, "\0")
				local hash = base64.encode(hashes.sha256(hash_input))
				x:tag("mav", {xmlns = xmlns_mav; since = mav_since; ["until"] = hash;}):up()
				table.insert(xs, x)
				x = st.stanza("x", {xmlns = xmlns_muc_user;})
				count = 0
				mav_since = hash
			end
		end
	end
	table.sort(jid_affiliations);
	local hash_input = table.concat(jid_affiliations, "\0");
	local hash = base64.encode(hashes.sha256(hash_input))
	if not hash_only and (count > 0 or #xs < 1) then
		x:tag("mav", {xmlns = xmlns_mav; since = mav_since; ["until"] = hash;}):up();
		table.insert(xs, x);
	end
	return hash, xs;
end

local function handle_stanza_with_x(room, stanza, mav_current)
	local muc_x = stanza:get_child("x", xmlns_muc_user);
	local is_initial = false;
	for child in muc_x:childtags("status") do
		if child.attr.code == "110" then is_initial = true; end;
	end
	if is_initial then
		muc_x:tag("mav", {xmlns = xmlns_mav; ["until"] = mav_current;}):up();
	else
		-- TODO: stop recomputing the hash on every stanza in the presence flood
		local mav_new = get_affiliations(stanza.attr.from, room, true);
		if mav_current ~= mav_new then
			module:log("info", "Update version of %s from %s to %s in affiliation update", stanza.attr.to, mav_current, mav_new);
			muc_x:tag("mav", {xmlns = xmlns_mav; ["since"] = mav_current; ["until"] = mav_new; }):up();
			mav_versions[room.jid.."\0"..stanza.attr.to] = mav_new;
		end
	end
end

local function room_route_stanza(room, stanza)
	local muc_x = stanza:get_child("x", xmlns_muc_user);
	if muc_x then
		local mav_current = mav_versions[room.jid.."\0"..stanza.attr.to];
		if mav_current then
			if stanza.name == "presence" or stanza.name == "message" then
				handle_stanza_with_x(room, stanza, mav_current);
			end
		end
	end
	module:send(stanza);
end

-- TODO: Stop this hack
local original_room_route_stanza = mod_muc.room_mt.route_stanza;
mod_muc.room_mt.route_stanza = room_route_stanza;
function module.unload()
	mod_muc.room_mt.route_stanza = original_room_route_stanza;
end


module:hook("muc-disco#info", function(event)
	event.reply:tag("feature", {var = xmlns_mav}):up();
end);

module:hook("muc-occupant-pre-join", function(event)
	local room, stanza = event.room, event.stanza;
	local muc_x = stanza:get_child("x", xmlns_muc);
	if not muc_x then return; end
	local mav_child = muc_x:get_child("mav", xmlns_mav);
	if not mav_child then return; end
	local mav_since = mav_child.attr["since"];
	mav_versions[room.jid.."\0"..stanza.attr.from] = mav_since;
	local mav_current, xs = get_affiliations(stanza.attr.from, room);
	if mav_current ~= mav_since then
		-- TODO: Support for diffs
		-- Send full response
		module:log("info", "Old version of %s is %s, sending full response for %s", stanza.attr.from, mav_since, mav_current);
		for _, x in ipairs(xs) do
			local announce_msg = st.message({ from = room.jid, to = stanza.attr.from }):add_child(x);
			room:route_stanza(announce_msg);
		end
		mav_versions[room.jid.."\0"..stanza.attr.from] = mav_current;
	else
		module:log("info", "Old version of %s is %s, still current", stanza.attr.from, mav_since);
	end
end, -100);

module:hook("muc-occupant-left", function(event)
	local room, occupant = event.room, event.occupant;
	for jid in occupant:each_session() do
		mav_versions[room.jid.."\0"..jid] = nil;
	end
end);

module:hook("muc-occupant-pre-leave", function(event)
	local room, stanza = event.room, event.stanza;
	mav_versions[room.jid.."\0"..stanza.attr.from] = nil;
end);
