-- Areas mod by ShadowNinja
-- Based on node_ownership
-- License: LGPLv2+

areas = {}

areas.awards_available = minetest.get_modpath("awards") and true
areas.factions_available = minetest.get_modpath("playerfactions") and true

areas.adminPrivs = {areas=true}
local startTime = os.clock()

areas.modpath = minetest.get_modpath("areas")
dofile(areas.modpath.."/settings.lua")
dofile(areas.modpath.."/api.lua")

local async_dofile = core.register_async_dofile or dofile
async_dofile(areas.modpath.."/async.lua")

dofile(areas.modpath.."/internal.lua")
dofile(areas.modpath.."/chatcommands.lua")
dofile(areas.modpath.."/pos.lua")
dofile(areas.modpath.."/interact.lua")
dofile(areas.modpath.."/legacy.lua")
dofile(areas.modpath.."/hud.lua")


--Reset migration flag
--local mod_storage = core.get_mod_storage()
--mod_storage:set_string("legacy_migrated", "")
areas:load()
core.log("action", "[Areas] protector_radius = " .. tostring(areas.config.protector_radius))

dofile(areas.modpath.."/protector.lua")
dofile(areas.modpath.."/wand.lua")
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

if minetest.settings:get_bool("log_mods") then
	local diffTime = os.clock() - startTime
	minetest.log("action", "areas loaded in "..diffTime.."s.")
end
