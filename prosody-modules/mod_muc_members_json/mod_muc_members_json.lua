local async = require "util.async";
local http = require "net.http";
local json = require "util.json";
local promise = require "util.promise";
local set = require "util.set";

local json_url = assert(module:get_option_string("muc_members_json_url"), "muc_members_json_url required");
local managed_mucs = module:get_option("muc_members_json_mucs");

local dry_run_mode = module:get_option_boolean("muc_members_json_dry_run", false);

local mod_muc = module:depends("muc");

--[[
{
	xsf = {
		team_hats = {
			board = {
				id = "xmpp:xmpp.org/hats/board";
				title = "Board";
			};
		};
		member_hat = {
			id = "xmpp:xmpp.org/hats/member";
			title = "XSF member";
		};
	};
	iteam = {
		team_hats = {
			iteam = {
				id = "xmpp:xmpp.org/hats/iteam";
				title = "Infra team";
			};
		};
	};
}
--]]

local function get_hats(member_info, muc_config)
	local hats = {};
	if muc_config.member_hat then
		hats[muc_config.member_hat.id] = {
			title = muc_config.member_hat.title;
			active = true;
		};
	end
	if muc_config.team_hats and member_info.roles then
		for _, role in ipairs(member_info.roles) do
			local hat = muc_config.team_hats[role];
			if hat then
				hats[hat.id] = {
					title = hat.title;
					active = true;
				};
			end
		end
	end
	return hats;
end

local function async_as_promise(f, p)
	return promise.new(function (resolve, reject)
		local r = async.runner(f);
		r:onready(function ()
			resolve(true);
		end);
		r:onerror(function (err)
			reject(err);
		end);
		if p == nil then
			p = true;
		end
		local ok, state = r:run(p);
		if ok and state == "ready" then
			resolve(true);
		end
	end);
end

function update_members(dry_run)
	module:log("debug", "Updating... (dry run: %s)", dry_run and "no" or "yes");
	return http.request(json_url)
		:next(function (result)
			return json.decode(result.body);
		end)
		:next(function (data)
			module:log("debug", "DATA: %q", data);
			return async_as_promise(function ()
				for name, muc_config in pairs(managed_mucs) do
					local muc_jid = name.."@"..module.host;
					local muc = mod_muc.get_room_from_jid(muc_jid);
					if muc then
						local owner_roles = set.new(muc_config.owner_roles);
						local admin_roles = set.new(muc_config.admin_roles);
						local member_roles = set.new(muc_config.member_roles);
						local affiliated_roles = owner_roles + admin_roles + member_roles;
						local is_private = muc_config.private;
						local include_all_members = muc_config.member_roles == nil;

						if is_private and not muc:get_members_only() then
							if not dry_run then
								module:log("info", "Setting %s to members-only...", muc_jid);
								muc:set_members_only(true);
							else
								module:log("info", "DRY RUN: Would set %s to members-only...", muc_jid);
							end
						end

						local jids = {};
						for _, member_info in ipairs(data.members) do
							local roles = set.new(member_info.roles);
							for _, member_jid in ipairs(member_info.jids) do
								if include_all_members or not set.intersection(affiliated_roles, roles):empty() then
									jids[member_jid] = true;
									local is_owner = not set.intersection(owner_roles, roles):empty();
									local is_admin = not set.intersection(admin_roles, roles):empty();
									local expected_affiliation = (is_owner and "owner") or (is_admin and "admin") or "member";
									local affiliation = muc:get_affiliation(member_jid);
									if affiliation ~= expected_affiliation then
										if affiliation == "outcast" then
											module:log("debug", "Not updating affiliation of %s in %s, because they are currently outcast", member_jid, muc_jid);
										else
											if not dry_run then
												muc:set_affiliation(true, member_jid, expected_affiliation, "imported membership");
												muc:set_affiliation_data(member_jid, "source", module.name);
												module:log("info", "Set affiliation of %s in %s, %s -> %s", member_jid, muc_jid, affiliation, expected_affiliation);
											else
												module:log("info", "DRY RUN: Would set affiliation of %s in %s, %s -> %s", member_jid, muc_jid, affiliation, expected_affiliation);
											end
										end
									end
									if not dry_run then
										muc:set_affiliation_data(member_jid, "hats", get_hats(member_info, muc_config));
									end
								end
							end
						end
						-- Remove affiliation from folk who weren't in the source data but previously were
						for jid, aff, data in muc:each_affiliation() do
							if not jids[jid] and data and data.source == module.name then
								if not dry_run then
									module:log("info", "Removing affiliation of %s in %s", jid, muc_jid);
									muc:set_affiliation(true, jid, "none", "imported membership lost");
								else
									module:log("info", "DRY RUN: Would remove affiliation of %s in %s", jid, muc_jid);
								end
							end
						end
					end
				end
			end);
		end):catch(function (err)
			module:log("error", "FAILED: %s", err);
		end);
end

function module.load()
	update_members(dry_run_mode);
end

module:hourly(function ()
	update_members(dry_run_mode);
end);

module:add_item("shell-command", {
	section = "members_json";
	section_desc = "Commands related to mod_muc_members_json";
	name = "update";
	desc = "Force an update of the members data";
	args = {
		{ name = "host", type = "string" };
	};
	host_selector = "host";
	flags = {
		bool_params = { dry_run = true };
	};
	handler = function (shell, host, opts)
		return update_members(opts.dry_run)
			:next(function ()
				return opts.dry_run and "Updated (dry-run only, check logs)" or "Updated";
			end);
	end;
});
