--                                                        _____
--  +-+    +-+  +-\    /-+      /--\      +------\  +-+  /  ___|
--  | |    | |  |  \  /  |     / /\ \     | +--+ |  | |  | |___
--  | |    | |  |   \/   |    / /__\ \    | |__| /  | |  \___  \
--  | |    | |  | |\__/| |   / +----+ \   |  __  \  | |       \ \
--  | |____| |  | |    | |  / /      \ \  | |__| |  | |  _____/ |
--  |________|  |_|    |_| /_/        \_\ |______/  |_|  |_____/
--
-- The Ultimate Minetest Authentication, Banning and Identity theft prevention System

local version = {
	major = 0,
	minor = 0,
	patch = 1
}

local registered_on_reload = {}

umabis = {
	-- This function is available only during the initial load.
	register_on_reload = function(action)
		table.insert(registered_on_reload, action)
	end
}

dofile(minetest.get_modpath("umabis") .. "/auth_handler.lua")
dofile(minetest.get_modpath("umabis") .. "/formspecs.lua")
dofile(minetest.get_modpath("umabis") .. "/session.lua")
dofile(minetest.get_modpath("umabis") .. "/ping.lua")

local function load()
	umabis = {
		version_major = version.major,
		version_minor = version.minor,
		version_patch = version.patch,
		version_string = version.major.."."..version.minor.."."..version.patch
	}

	-- It is important to load the settings first, since they are used next.
	dofile(minetest.get_modpath("umabis") .. "/settings.lua")

	dofile(minetest.get_modpath("umabis") .. "/serverapi.lua")
	if not umabis.serverapi.hello() then
		return false
	end

	if dofile(minetest.get_modpath("umabis") .. "/ban.lua") == false then
		return false
	end

	for _, action in ipairs(registered_on_reload) do
		if action() == false then
			return false
		end
	end

	dofile(minetest.get_modpath("umabis") .. "/chatcmds.lua")

	minetest.log("action", "[umabis] Umabis version "..umabis.version_string.." loaded!")
	return true
end

umabis.register_on_reload(function()
	umabis.reload = load
end)

if not load() then
	minetest.log("error", "[umabis] Failed to load Umabis version "..umabis.version_string..".")
	error("Failed to load Umabis version "..umabis.version_string..". See debug.txt for more info.")
end

minetest.register_on_prejoinplayer(function(name, ip)
	if umabis.settings:get_bool("enable_local_ban") then
		local ret = umabis.ban.on_prejoinplayer(name, ip)
		if ret then
			return ret
		end
	end

	local function format_entry(entry)
		local str = "\nDate: " .. entry.date
		         .. "\nCategory: " .. entry.category
		         .. "\nReason: " .. entry.reason
		         .. "\nUntil: " .. (entry.exp_time_UNIX and os.date("%c", entry.exp_time_UNIX) or "the end of times")
		if umabis.settings:get_bool("blacklist_show_source_moderator") then
			str = str .. "\nBy moderator: " .. entry.source_moderator
		end
		return str
	end

	local ok, blacklisted, entry = umabis.serverapi.is_blacklisted(name, ip)
	if not ok then
		return "A bug occured while checking if you were blacklisted on the Umabis server. Please contact the server administrator."
	end

	if blacklisted == "nick" then
		return "Your nick ("..name..") is blacklisted on the Umabis server.\n" .. format_entry(entry)
	elseif blacklisted == "ip" then
		return "You IP address ("..ip..") is blacklisted on the Umabis server.\n" .. format_entry(entry)
	end

	local ok, e = umabis.session.prepare_session(name, ip)
	if not ok then
		return e
	end
end)

minetest.register_on_joinplayer(function(player)
	umabis.session.new_session(player:get_player_name())
end)

minetest.register_on_leaveplayer(function(player)
	umabis.session.clear_session(player:get_player_name())
end)

minetest.register_on_shutdown(function()
	-- Close all sessions
	umabis.session.clear_all()
	-- Say goodbye to server
	umabis.serverapi.goodbye()
end)
