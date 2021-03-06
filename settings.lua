local settings_table = {}

local default_settings = Settings(minetest.get_modpath("umabis") .. "/default_settings.conf")
for _, setting_name in ipairs(default_settings:get_names()) do
	settings_table[setting_name] = minetest.settings:get("umabis." .. setting_name) or default_settings:get(setting_name)
end

umabis.settings = {
	settings_table = settings_table,
	default_settings = default_settings,
	get = function(self, key)
		return self.settings_table[key]
	end,
	get_int = function(self, key)
		return tonumber(self.settings_table[key]) or tonumber(self.default_settings:get(key))
	end,
	get_bool = function(self, key)
		return self.settings_table[key] == "true"
	end
}
