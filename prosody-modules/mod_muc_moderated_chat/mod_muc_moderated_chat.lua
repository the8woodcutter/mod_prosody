-- msg in differnt languages
local explain_en = "This room uses the module \"muc_moderated_chat\". As a Moderator, you can use: \n```\n" ..
"!moderate\n```\nto switch the Room to moderated, and:\n```\n!unmoderate\n```\nto disable the moderation.";
local explain_de = "Dieser Chatroom nutzt das Module \"muc_moderated_chat\". Als Moderator kannst du:" ..
"\n```\n!moderate\n```\n nutzen um den Raum auf \"moderiert\" zu stellen.\n" ..
"Sende:\n```\n!unmoderate\n```\num die Moderation zu beenden.";

local made_mod_en	= "* made you a *Moderator*\n\n" .. explain_en
local made_mod_de	= "* hat dich zum *Moderator* gemacht.\n\n" .. explain_de


local is_mod_en = "The channel is already moderated"
local is_mod_de = "Der Raum ist bereits moderiert"

local is_unmod_en = "The channel is already unmoderated"
local is_unmod_de = "Der Raum ist bereits unmoderiert"

local mod_en = "* set the channel to *moderated*";
local mod_de = "* änderte den Raum auf *moderiert*";

local unmod_en = "* set the channel to *unmoderated*";
local unmod_de = "* änderte den Raum auf *unmoderiert*";
--
local inform_admins = module:get_option_boolean("muc_moderated_chat_inform_admins", true);
local module_nick = module:get_option_string("muc_moderated_chat_module_nickname", "mod_muc_moderated_chat");

local jid = require "util.jid";
local st = require "util.stanza";
local uuid = require "util.uuid";

module:depends("muc");

local MODERATED_CHAT_FIELD = "{xmpp:prosody.im}muc#roomconfig_moderated_chat";
local MODERATED_FIELD = "muc#roomconfig_moderatedroom";


local function command_enabled(room)
	local enabled = room._data.muc_moderated_chat_enabled == true;
	return enabled;
end


-- generate a fake message from the room that looks like groupchat.
local function send_message(room, occupant, msg_en, msg_de)
	-- Use the room JID as the stable identity for this server-generated message.
	local fake_room_occupant = {
		bare_jid = room.jid;
	};
	local uid = uuid.generate()
	local stanza = st.message({
		type = "groupchat";
		from = room.jid .. "/" .. module_nick;
		to = occupant.nick;
		id = uid;
	})
	:tag("body", { ["xml:lang"] = "en" } ):text(msg_en):up()
	:tag("body", { ["xml:lang"] = "de" } ):text(msg_de):up()
	:tag("stanza-id", { xmlns = "urn:xmpp:sid:0"; id = uid; by = room.jid }):up()
	:tag("occupant-id", { xmlns = "urn:xmpp:occupant-id:0"; id = room:get_occupant_id(fake_room_occupant) }):up();

	room:route_to_occupant(occupant, stanza)
end


local function send_message_to_admins(room, msg_en, msg_de)
	for _, occupant in room:each_occupant() do
		local affiliation = room:get_affiliation(occupant.bare_jid);

		if affiliation == "admin"
		or affiliation == "owner" then
			send_message(room, occupant, msg_en, msg_de);
		end
	end
end


-- Mandatory things for ad-hoc room fields
local function handle_config_form(event)
	local room = event.room;
	table.insert(event.form, {
		name = MODERATED_CHAT_FIELD;
		type = "boolean";
		label = "Allow Admins (Moderators) to set a room to moderated.";
		desc = "They can use chat commands: !moderate / !unmoderate to change the room moderation status.";
		value = command_enabled(room);
	});
end
-- Get the state of the module setting
local function handle_config_submit(event)
	local room = event.room;
	local new_value = event.value == true;

	if command_enabled(room) == new_value then
		return;
	end

	room._data.muc_moderated_chat_enabled = new_value;
	event.changed = true

	if new_value
	and inform_admins then
		send_message_to_admins(room, explain_en, explain_de)
	end
end


--main function for the command
local function handle_moderation_command(event)
	local room = event.room;
	local occupant = event.occupant;
	local stanza = event.stanza;
	local body = stanza:get_child_text("body");

	local new_value;
	if body == "!moderate" or body == "!moderate " then
		new_value = true;
	else
		new_value = false;
	end
	--get current value and handle nil case
	local current_value = room:get_moderated() == true;
	if current_value == new_value then
		if current_value then
			send_message(room, occupant, is_mod_en, is_mod_de);
		else
			send_message(room, occupant, is_unmod_en, is_unmod_de);
		end
		return true;
	end

	room:set_moderated(new_value) --change room moderation status

	local nickname = jid.resource(occupant.nick);
	local set_mod_en = "*" .. nickname .. mod_en;
	local set_mod_de = "*" .. nickname .. mod_de;
	local set_unmod_en = "*" .. nickname .. unmod_en;
	local set_unmod_de = "*" .. nickname .. unmod_de;

	if new_value then
		if inform_admins then
			send_message_to_admins(room, set_mod_en, set_mod_de);
		else
			send_message(room, occupant, set_mod_en, set_mod_de);
		end
	else
		if inform_admins then
			send_message_to_admins(room, set_unmod_en, set_unmod_de);
		else
			send_message(room, occupant, set_unmod_en, set_unmod_de);
		end
	end
	-- Prevent the command from being delivered as a normal message.
	return true;
end


--inform new admins of the command
local function handle_new_admin_info(event)
	local room = event.room;

	if not command_enabled(room)
	or event.affiliation ~= "admin"
	or not inform_admins then
		return;
	end

	-- is there no better way to get the occupant object? :
	local bare_jid = event.jid;
	local occupant;
	for _, usr in room:each_occupant() do
		if usr.bare_jid == bare_jid then
			occupant = usr;
			break;
		end
	end
	if not occupant then
		return
	end
	local actor = room:get_occupant_by_real_jid(event.actor);
	local nickname = jid.resource(actor.nick);
	if actor then
		local explain_nick_en = "*" .. nickname .. made_mod_en
		local explain_nick_de = "*" .. nickname .. made_mod_de
		send_message(room, occupant, explain_nick_en, explain_nick_de);
	else
		send_message(room, occupant, explain_en, explain_de);
	end
end


-- Inform admins when the MUC moderation setting is changed
local function handle_moderation_status_change_info(event)
	local room = event.room;
	if not inform_admins
	or not command_enabled(room) then
		return;
	end

	--make sure nil vs false is handled
	local new_value = event.value == true;
	local current_value = room:get_moderated() == true;

	if current_value == new_value then
	return;
	end
	local occupant = room:get_occupant_by_real_jid(event.actor);
	local nickname = jid.resource(occupant.nick);
	local set_mod_en = "*" .. nickname .. mod_en;
	local set_mod_de = "*" .. nickname .. mod_de;
	local set_unmod_en = "*" .. nickname .. unmod_en;
	local set_unmod_de = "*" .. nickname .. unmod_de;

	if new_value then
		send_message_to_admins(room, set_mod_en, set_mod_de);
	else
		send_message_to_admins(room, set_unmod_en, set_unmod_de);
	end
end


local function reserve_module_nick(event)
	local occupant = event.dest_occupant or event.occupant;
	if jid.resource(occupant.nick) ~= module_nick then
		return;
	end
	event.origin.send(st.error_reply(
		event.stanza,
		"cancel",
		"conflict",
		"That nickname is reserved",
		event.room.jid
	));
	module:log("debug", "Denied reserved nickname %s for %s", occupant.nick, occupant.bare_jid);
	return true;
end


module:hook("muc-config-form", handle_config_form, 80 - 3.4); --just after default moderation form
module:hook("muc-config-submitted/" .. MODERATED_CHAT_FIELD, handle_config_submit);
module:hook("muc-config-submitted/" .. MODERATED_FIELD, handle_moderation_status_change_info, 10); -- prio >0 nessesary to notice the change
module:hook("muc-set-affiliation",		handle_new_admin_info);
module:hook("muc-occupant-pre-join",		reserve_module_nick);
module:hook("muc-occupant-pre-change",	reserve_module_nick);

module:hook("muc-occupant-groupchat", function(event)
	local room = event.room
	if not command_enabled(room) then
		return;
	end

	local stanza = event.stanza;
	if stanza.attr.type ~= "groupchat" then
		return;
	end

	local affiliation = room:get_affiliation(event.occupant.bare_jid);
	if affiliation ~= "admin"
	and affiliation ~= "owner" then
		return;
	end

	local body = stanza:get_child_text("body");
	if body == "!moderate"
	or body == "!unmoderate"
	or body == "!moderate "
	or body == "!unmoderate " then
		return handle_moderation_command(event);
	end
	return;
end, 10);
