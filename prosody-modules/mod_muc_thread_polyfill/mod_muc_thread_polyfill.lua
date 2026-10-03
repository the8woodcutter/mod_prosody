local st = require "util.stanza";
local jid = require "util.jid";

local archive = module:open_store("muc_log", "archive");

module:hook("muc-occupant-groupchat", function (event)
	local stanza = event.stanza;
	local room   = event.room;

	if stanza:get_child("thread") then
		return;
	end

	local reply = stanza:get_child("reply", "urn:xmpp:reply:0");
	if not reply then
		return;
	end

	local reply_id = reply.attr.id;
	if not reply_id then
		return;
	end

	local archived = archive:get(jid.node(room.jid), reply_id);
	if not archived then
		return;
	end

	local parent_thread = archived:get_child("thread");
	if parent_thread then
		stanza:add_child(st.clone(parent_thread));
	end
end);
