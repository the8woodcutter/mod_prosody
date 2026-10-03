local st          = require "util.stanza"
local jid         = require "util.jid"

local module_host = module:get_host()

local mod_muc     = module:depends("muc") --[[@as muc_module]]

local reason      = module:get_option_string(
	"muc_invite_affiliated_reason",
	"You are a member of this room, please join it."
)

local function is_remote(bare_jid)
	local _user, jid_host = jid.split(bare_jid)
	return not prosody.hosts[jid_host]
end

local function build_invite(room_jid, to_jid, room_name, from_jid)
	local invite = st.message({ to = to_jid, from = module_host })
		:tag("x", {
			xmlns  = "jabber:x:conference",
			jid    = room_jid,
			reason = reason
		})

	return invite
end

local function invite_remote_members()
	local invite_count = 0
	local room_count   = 0

	for room in mod_muc.all_rooms() do
		if room:get_members_only() then
			room_count      = room_count + 1
			local room_jid  = room.jid
			local room_name = room:get_name()

			for member_jid, aff in room:each_affiliation() do
				if aff == "owner" or aff == "admin" or aff == "member" then
					local bare = jid.bare(member_jid)
					if is_remote(bare) then
						local invite_stanza = build_invite(room_jid, bare, room_name)
						module:send(invite_stanza)
						module:log("debug", "Sent invite for %s to %s", room_jid, bare)
						invite_count = invite_count + 1
					end
				end
			end
		end
	end

	module:log("info", "Sent %d invite(s) across %d members-only room(s)",
		invite_count, room_count)
	return invite_count, room_count
end

module:add_item("shell-command", {
	section = "muc",
	section_desc = "Invite affiliated JIDs",
	name = "invite",
	desc = "Send invites to all affiliated JIDs of all rooms now",
	args = {
		{ name = "host", type = "string" },
	},
	host_selector = "host",
	handler = function(shell) --luacheck: ignore 212/shell
		local invite_count, room_count = invite_remote_members();
		return true, ("Sent %d invite(s) across %d members-only room(s)"):format(invite_count, room_count);
	end,
});


module:hook_global("server-started", invite_remote_members)
