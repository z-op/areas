--------------
-- Settings --
--------------

areas.config = areas.config or {}

areas.config.self_protection_privilege = minetest.settings:get("areas.self_protection_privilege") or "interact"
areas.config.tick = tonumber(minetest.settings:get("areas.tick")) or 0.5
areas.config.self_protection_max_size_high = minetest.string_to_pos(minetest.settings:get("areas.self_protection_max_size_high") or "(512, 512, 512)")
areas.config.self_protection_max_areas_high = tonumber(minetest.settings:get("areas.self_protection_max_areas_high")) or 32
areas.config.self_protection_max_areas = tonumber(minetest.settings:get("areas.self_protection_max_areas") or "4")
areas.config.self_protection_max_size = minetest.string_to_pos(minetest.settings:get("areas.self_protection_max_size") or "(64, 128, 64)")
areas.config.legacy_table = minetest.settings:get_bool("areas.legacy_table") or "false"
areas.config.self_protection = minetest.settings:get_bool("areas.self_protection") or "false"
areas.config.use_smallest_area_precedence = minetest.settings:get_bool("areas.use_smallest_area_precedence") or "false"
areas.config.protector_delay = tonumber(minetest.settings:get("areas.protector_delay") or 2)
areas.config.protector_radius = tonumber(minetest.settings:get("areas.protector_radius") or 5)
areas.config.protector_show = tonumber(minetest.settings:get("protector_show_interval") or 5)


