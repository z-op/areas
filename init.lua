-- file name: init.lua
-- areas mod by ShadowNinja
-- License: LGPLv2+

areas = {}

areas.awards_available = minetest.get_modpath("awards") and true
areas.factions_available = minetest.get_modpath("playerfactions") and true

areas.adminPrivs = {areas=true}

areas.modpath = minetest.get_modpath("areas")
areas.modstorage = minetest.get_mod_storage()

dofile(areas.modpath.."/settings.lua")
dofile(areas.modpath.."/api.lua")
dofile(areas.modpath.."/internal.lua")
dofile(areas.modpath.."/chatcommands.lua")
dofile(areas.modpath.."/pos.lua")
dofile(areas.modpath.."/interact.lua")
dofile(areas.modpath.."/hud.lua")

areas:load()

local S = minetest.get_translator("areas")

minetest.register_privilege("areas", {
	description = S("Can administer areas."),
	give_to_singleplayer = false
})
minetest.register_privilege("areas_high_limit", {
	description = S("Can protect more, bigger areas."),
	give_to_singleplayer = false
})

if not minetest.registered_privileges[areas.config.self_protection_privilege] then
	minetest.register_privilege(areas.config.self_protection_privilege, {
		description = S("Can protect areas."),
	})
end
