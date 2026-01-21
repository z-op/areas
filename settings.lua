-- file name: settings.lua
areas.config = {}

local function setting(name, tp, default)
	local full_name = "areas." .. name
	local value
	if tp == "bool" then
		value = minetest.settings:get_bool(full_name)
		if value == nil then
			value = minetest.is_yes(default)
		end
		areas.config[name] = value
	elseif tp == "string" then
		value = minetest.settings:get(full_name)
		areas.config[name] = value or default
	elseif tp == "v3f" then
		value = minetest.setting_get_pos(full_name)
		areas.config[name] = value or minetest.string_to_pos(default)
	elseif tp == "float" or tp == "int" then
		value = tonumber(minetest.settings:get(full_name))
		areas.config[name] = value or tonumber(default)
	else
		error("Cannot parse setting type " .. tp)
	end
end

-- Определяем настройки напрямую в коде
setting("self_protection", "bool", "true")
setting("self_protection_privilege", "string", "interact")
setting("self_protection_max_areas", "int", "4")
setting("self_protection_max_areas_high", "int", "8")
setting("self_protection_max_size", "v3f", "32,32,32")
setting("self_protection_max_size_high", "v3f", "64,64,64")
setting("tick", "float", "0.5")
setting("use_smallest_area_precedence", "bool", "false")
