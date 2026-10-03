local http = require "net.http"
local resolver = require "net.resolvers.basic"
local socket_url = require "socket.url"
local st = require "util.stanza"
local async = require "util.async"
local promise = require "util.promise"
local mime = require "mime"
local lfs = require "lfs"
local hashes = require "util.hashes"
local jid = require "util.jid"
local hex = require "util.hex"
local crypto = require "util.crypto"

local storage_path = module:get_option_string("muc_media_store_path", "/var/lib/prosody/muc-media")
local public_base_url = module:get_option_string("muc_media_public_base")
local max_size = module:get_option_number("muc_media_max_size", 10 * 1024 * 1024)
local decrypt_aesgcm = module:get_option_boolean("muc_media_decrypt_aesgcm", true)

lfs.mkdir(storage_path)
lfs.mkdir(storage_path.."/sha-256")
lfs.mkdir(storage_path.."/sha3-256")

local function ipv4_to_number(ip)
	local a,b,c,d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then return nil end
	return (tonumber(a) << 24) | (tonumber(b) << 16) | (tonumber(c) << 8) | tonumber(d)
end

local function ipv4_in_range(ip, base, mask) return (ip & mask) == base end

local function is_private_ipv4(ip)
	local n = ipv4_to_number(ip)
	if not n then return false end
	if ipv4_in_range(n, 0x0A000000, 0xFF000000) then return true end
	if ipv4_in_range(n, 0xAC100000, 0xFFF00000) then return true end
	if ipv4_in_range(n, 0xC0A80000, 0xFFFF0000) then return true end
	if ipv4_in_range(n, 0x7F000000, 0xFF000000) then return true end
	if ipv4_in_range(n, 0xA9FE0000, 0xFFFF0000) then return true end
	if ipv4_in_range(n, 0x00000000, 0xFF000000) then return true end
	if ipv4_in_range(n, 0xE0000000, 0xF0000000) then return true end
	return false
end

local function is_private_ipv6(ip)
	ip = ip:lower()
	if ip == "::1" then return true end
	if ip:match("^fc") or ip:match("^fd") then return true end
	if ip:match("^fe8") or ip:match("^fe9") or ip:match("^fea") or ip:match("^feb") then return true end
	if ip == "::" then return true end
	return false
end

local function sha256_file(path)
	local f = io.open(path,"rb")
	if not f then return nil end
	-- TODO: incremental hash
	local digest = hashes.sha256(f:read("*all"))
	f:close()
	return mime.b64(digest)
end

local function sha3_256_file(path)
	local f = io.open(path,"rb")
	if not f then return nil end
	-- TODO: incremental hash
	local digest = hashes.sha3_256(f:read("*all"))
	f:close()
	return mime.b64(digest)
end

local function file_size(path)
	return lfs.attributes(path,"size") or 0
end

local function filename_from_url(url)
	return url:match(".*/([^/?]+)$") or "file"
end

local function pattern_from_string(s)
	return s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

local function secure_download_to_disk(url)
	local parsed = socket_url.parse(url)
	local scheme = parsed.scheme
	if not parsed or (scheme~="http" and scheme~="https" and scheme~="aesgcm") then return promise.reject("invalid scheme") end

	local request_url = url
	if scheme == "aesgcm" then
		parsed.scheme = "https"
		request_url = socket_url.build(parsed)
	end

	local tmpname = storage_path.."/tmp_"..tostring(math.random(1e9))
	local file = io.open(tmpname,"wb")
	if not file then return promise.reject("cannot open temp file") end

	return promise.new(function(resolve, reject)
		http.request(request_url, {
			method = "GET";
			body_size_limit = max_size;
			streaming_handler = function(r) return file, function() file:close(); file = nil end end;
			target_filter = function(net, ip, port, extra)
				return (net == "tcp4" and not is_private_ipv4(ip)) or (net == "tcp6" and not is_private_ipv6(ip))
			end;
		}, function(_, code, response)
			if code ~= 200 then
				if file then file:close() end
				os.remove(tmpname)
				reject("bad status")
				return
			end
			local was_decrypted = false
			if file then
				file:write(response.body)
				file:close()
			end
			if decrypt_aesgcm and scheme == "aesgcm" and parsed.fragment then
				local iv = hex.from(parsed.fragment:sub(1, 24))
				local key = hex.from(parsed.fragment:sub(25, 88))
				if iv and key and #iv == 12 and #key == 32 then
					local f = io.open(tmpname, "rb")
					if f then
						-- TODO: size limit
						local encrypted = f:read("*a")
						f:close()
						local decrypted = crypto.aes_256_gcm_decrypt(key, iv, encrypted)
						if decrypted then
							f = io.open(tmpname, "wb")
							if f then
								f:write(decrypted)
								f:close()
								was_decrypted = true
							end
						end
					end
				end
			end
			resolve({ tmpname, response.headers["content-type"], was_decrypted })
		end)
	end)
end

module:hook("muc-broadcast-message", function(event)
	local stanza = event.stanza
	if stanza.attr.type ~= "groupchat" then return end

	local url_map = {}

	-- Collect OOB URLs
	for oob in stanza:childtags("x","jabber:x:oob") do
		local url_tag = oob:get_child("url")
		if url_tag then
			url_map[url_tag:get_text()] = {}
		end
	end

	-- Collect SIMS URLs
	for ref in stanza:childtags("reference","urn:xmpp:reference:0") do
		for ms in ref:childtags("media-sharing","urn:xmpp:sims:1") do
			local sources = ms:get_child("sources")
			if sources then
				for sref in sources:childtags("reference","urn:xmpp:reference:0") do
					local uri = sref.attr.uri
					if uri then url_map[uri] = {} end
				end
			end
		end
	end

	-- Cache each URL
	for original_url,_ in pairs(url_map) do
		local result, err = async.wait_for(secure_download_to_disk(original_url))
		local tmp_path, content_type, was_decrypted = result and result[1], result and result[2], result and result[3]
		if not err and tmp_path then
			local sha2 = sha256_file(tmp_path)
			local sha3 = sha3_256_file(tmp_path)
			local size = file_size(tmp_path)
			local name = filename_from_url(original_url)
			if sha2 and sha3 then
				local final_name = "sha3-256/"..sha3:gsub("+","-"):gsub("/","_"):gsub("=","")
				local final_path = storage_path.."/"..final_name
				if not lfs.attributes(final_path) then
					os.rename(tmp_path, final_path)
				else
					lfs.touch(final_path)
					os.remove(tmp_path)
				end
				local sha2_path = storage_path.."/sha-256/"..sha2:gsub("+","-"):gsub("/","_"):gsub("=","")
				if not lfs.attributes(sha2_path) then
					lfs.link("../"..final_name, sha2_path, true)
				end
				local local_url = public_base_url..final_name.."?ct="..content_type
				local parsed_orig = socket_url.parse(original_url)
				if parsed_orig and parsed_orig.scheme == "aesgcm" and not was_decrypted then
					local parsed_local = socket_url.parse(local_url)
					if parsed_local then
						parsed_local.scheme = "aesgcm"
						parsed_local.fragment = parsed_orig.fragment
						local_url = socket_url.build(parsed_local)
					end
				end
				url_map[original_url] = { local_url = local_url, path=final_path, sha2=sha2, sha3=sha3, size=size, name=name, content_type=content_type }
			else
				os.remove(tmp_path)
			end
		end
	end

	-- Rewrite URLs and enrich/create SIMS
	local original_body = stanza:get_child_text("body")
	for original_url,data in pairs(url_map) do
		if data.local_url then

			for oob in stanza:childtags("x","jabber:x:oob") do
				local url_tag = oob:get_child("url")
				if url_tag and url_tag:get_text() == original_url then
					oob:maptags(function(el)
						if el.name == "url" then
							return st.stanza("url"):text(data.local_url)
						else
							return el
						end
					end)
				end
			end

			stanza:maptags(function(el)
				if el.name == "body" then
					return st.stanza("body"):text(el:get_text():gsub(pattern_from_string(original_url), data.local_url))
				elseif el.name == "fallback" and el.attr.xmlns == "urn:xmpp:fallback:0" and (el.attr["for"] == "jabber:x:oob" or el.attr["for"] == "urn:xmpp:sims:1") then
					return el:maptags(function(subel)
						local s, e = string.find(original_body, original_url, 1, true)
						if s and subel.name == "body" and subel.attr.start and math.abs(s - tonumber(subel.attr.start)) < 5 then
							subel.attr["end"] = tostring((tonumber(subel.attr["end"]) - #original_url) + #data.local_url)
						end
						return subel
					end)
				else
					return el
				end
			end)

			local found = false
			-- Enrich existing SIMS references
			for ref in stanza:childtags("reference","urn:xmpp:reference:0") do
				for ms in ref:childtags("media-sharing","urn:xmpp:sims:1") do
					local sources = ms:get_child("sources")
					if sources then
						for sref in sources:childtags("reference","urn:xmpp:reference:0") do
							if sref.attr.uri == original_url then
								found = true
								sref.attr.uri = data.local_url
								local file_tag = ms:get_child("file","urn:xmpp:jingle:apps:file-transfer:5")
								if not file_tag then
									file_tag = st.stanza("file",{ xmlns="urn:xmpp:jingle:apps:file-transfer:5" })
									ms:add_child(file_tag)
								end
								file_tag:maptags(function(el)
									if el.name == "size" or el.name == "hash" then
										return nil
									else
										return el
									end
								end)
								-- Fill name
								if not file_tag:get_child("name") then
									file_tag:add_child(st.stanza("name"):text(data.name))
								end
								-- Fill size
								if not file_tag:get_child("size") then
									file_tag:add_child(st.stanza("size"):text(tostring(data.size)))
								end
								-- Fill SHA256 hash
								local sha2_tag = nil
								for htag in file_tag:childtags("hash","urn:xmpp:hashes:2") do
									if htag.attr.algo=="sha-256" then sha2_tag = htag end
								end
								if not sha2_tag then
									file_tag:add_child(st.stanza("hash",{ xmlns="urn:xmpp:hashes:2", algo="sha-256" }):text(data.sha2))
								end
								-- Fill SHA3-256 hash
								local sha3_tag = nil
								for htag in file_tag:childtags("hash","urn:xmpp:hashes:2") do
									if htag.attr.algo=="sha3-256" then sha3_tag = htag end
								end
								if not sha3_tag then
									file_tag:add_child(st.stanza("hash",{ xmlns="urn:xmpp:hashes:2", algo="sha3-256" }):text(data.sha3))
								end
							end
						end
					end
				end
			end
			-- Create new SIMS if none existed
			if not found then
				local ref = st.stanza("reference",{ xmlns="urn:xmpp:reference:0", type="data" })
				local ms = st.stanza("media-sharing",{ xmlns="urn:xmpp:sims:1" })
				local file_tag = st.stanza("file",{ xmlns="urn:xmpp:jingle:apps:file-transfer:5" })
				file_tag:add_child(st.stanza("media-type"):text(data.content_type or "application/octet-stream"))
				file_tag:add_child(st.stanza("name"):text(data.name))
				file_tag:add_child(st.stanza("size"):text(tostring(data.size)))
				file_tag:add_child(st.stanza("hash",{ xmlns="urn:xmpp:hashes:2", algo="sha-256" }):text(data.sha2))
				file_tag:add_child(st.stanza("hash",{ xmlns="urn:xmpp:hashes:2", algo="sha3-256" }):text(data.sha3))
				ms:add_child(file_tag)
				local sources = st.stanza("sources")
				sources:add_child(st.stanza("reference",{ xmlns="urn:xmpp:reference:0", type="data", uri=data.local_url }))
				ms:add_child(sources)
				ref:add_child(ms)
				stanza:add_child(ref)
			end
		end
	end
end, 100)

local archive = module:open_store("muc_log", "archive");

module:hook("muc-moderate-message", function(event)
	local room = event.room
	local stanza_id = event.stanza_id
	if not room or not stanza_id then return end

	local room_node = jid.split(room.jid);

	-- Find message by stanza_id
	local query = {
		with = "message<groupchat";
		ids = { stanza_id };
	}

	local items, err = archive:find(room_node, query)
	if not items or err then return end

	for id, stanza, when in items do
		-- Extract SIMS hashes
		for ref in stanza:childtags("reference", "urn:xmpp:reference:0") do
			for ms in ref:childtags("media-sharing", "urn:xmpp:sims:1") do
				for file_tag in ms:childtags("file", "urn:xmpp:jingle:apps:file-transfer:5") do
					for hash_tag in file_tag:childtags("hash", "urn:xmpp:hashes:2") do
						if hash_tag.attr.algo == "sha3-256" then
							local sha3 = hash_tag:get_text()
							if sha3 then
								local file = sha3:gsub("+","-"):gsub("/","_"):gsub("=","")
								local path = storage_path .. "/sha3-256/" .. file
								if lfs.attributes(path) then
									os.remove(path)
									module:log("debug",
										"Deleted cached media %s for moderated message %s",
										file, stanza_id
									)
								end
							end
						end
					end
				end
			end
		end
	end
end)
