module:depends"muc"

local from_affiliation
local from_jid
local room_jid
local restrict_members_by_default = true
local restrict_participants_by_default = true
local loglevel = module:get_option_enum("muc_restrict_attention_loglevel", "debug", "info", "warn", "error")
local restrict_by_default = module:get_option_enum("muc_restrict_attention_by_default", "members", "participants", false, "false")

-- ugly hack, improve it when you do for the room config option too
if restrict_by_default == "members" then
	restrict_members_by_default = true
	restrict_participants_by_default = true
elseif restrict_by_default == false
or restrict_by_default == "false" then
	restrict_members_by_default = false
	restrict_participants_by_default = false
elseif restrict_by_default == "participants" then
	restrict_members_by_default = false
	restrict_participants_by_default = true
end

local function should_restrict_members(room)
	local restrict_members = room._data.restrict_members
	if restrict_members == nil then
		restrict_members = restrict_members_by_default
	end
	return restrict_members
end

module:hook("muc-config-form", function(event)
	local room, form = event.room, event.form
	table.insert(form, {
		name = "{xmpp:prosody.im}muc#roomconfig_allow_members_attention",
		type = "boolean",
		label = 'Allow "XEP-0224: Attention" from members',
		value = not should_restrict_members(room),
	})
end, 80-7)

module:hook("muc-config-submitted", function(event)
	local room, fields, changed = event.room, event.fields, event.changed
	local new_restrict_members = not fields["{xmpp:prosody.im}muc#roomconfig_allow_members_attention"]
	if new_restrict_members ~= should_restrict_members(room) then
		if new_restrict_members == restrict_members_by_default then
			room._data.restrict_members = nil
		else
			room._data.restrict_members = new_restrict_members
		end
		if type(changed) == "table" then
			changed["{xmpp:prosody.im}muc#roomconfig_allow_members_attention"] = true
		else
			event.changed = true
		end
	end
end)

module:hook("muc-disco#info", function (event)
	local room, form, formdata = event.room, event.form, event.formdata
	local allow_members_attention = not should_restrict_members(room)
	table.insert(form, {
		name = "{xmpp:prosody.im}muc#roomconfig_allow_members_attention",
		type = "boolean",
	})
	formdata["{xmpp:prosody.im}muc#roomconfig_allow_members_attention"] = allow_members_attention
end)

local function filter_attention_tags(tag)
	local xmlns = tag.attr.xmlns
	if xmlns == "urn:xmpp:attention:0" then
		module:log(loglevel, "Stripped \"Attention\" from %q, affiliation: %q in %q", from_jid, from_affiliation, room_jid)
		return nil
	end
	return tag
end

module:hook("muc-occupant-groupchat", function (event)
	local stanza = event.stanza
	from_affiliation = event.room:get_affiliation(stanza.attr.from)
	if stanza.attr.type ~= "groupchat"
	or from_affiliation == "admin"
	or from_affiliation == "owner" then
		return
	end
	if should_restrict_members(event.room)
	or restrict_participants_by_default
	and not from_affiliation then
		room_jid = event.room.jid
		from_jid = event.stanza.attr.from
		stanza:maptags(filter_attention_tags)
	end
end, 9) --unsure what priority is sensible
