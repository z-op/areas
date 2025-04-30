local S = minetest.get_translator("areas")

-- I could depend on WorldEdit for this, but you need to have the 'worldedit'
-- permission to use those commands and you don't have
-- /area_pos{1,2} [X Y Z|X,Y,Z].
-- Since this is mostly copied from WorldEdit it is mostly
-- licensed under the AGPL. (select_area is an exception)

areas.set_pos = {}
areas.pos1 = {}
areas.pos2 = {}
areas.marker_region = {}

local LIMIT = 30992 -- this is due to MAPBLOCK_SIZE=16!

local function posLimit(pos)
	return {
		x = math.max(math.min(pos.x, LIMIT), -LIMIT),
		y = math.max(math.min(pos.y, LIMIT), -LIMIT),
		z = math.max(math.min(pos.z, LIMIT), -LIMIT)
	}
end

local parse_relative_pos
local init_sentinel = "new" .. tostring(math.random(99999))
if minetest.parse_relative_number then
	parse_relative_pos = function(x_str, y_str, z_str, pos)

		local x = pos and minetest.parse_relative_number(x_str, pos.x)
			or tonumber(x_str)
		local y = pos and minetest.parse_relative_number(y_str, pos.y)
			or tonumber(y_str)
		local z = pos and minetest.parse_relative_number(z_str, pos.z)
			or tonumber(z_str)
		if x and y and z then
			return vector.new(x, y, z)
		end
	end
else
	parse_relative_pos = function(x_str, y_str, z_str, pos)
		local x = tonumber(x_str)
		local y = tonumber(y_str)
		local z = tonumber(z_str)
		if x and y and z then
			return vector.new(x, y, z)
		elseif string.sub(x_str, 1, 1) == "~"
			or string.sub(y_str, 1, 1) == "~"
			or string.sub(z_str, 1, 1) == "~" then
			return nil, S("Relative coordinates is not supported on this server. " ..
				"Please upgrade Minetest to 5.7.0 or newer versions.")
		end
	end
end

minetest.register_chatcommand("select_area", {
	params = S("<ID>"),
	description = S("Select an area by ID."),
	func = function(name, param)
		local id = tonumber(param)
		if not id then
			return false, S("Invalid usage, see /help @1.", "select_area")
		end
		if not areas.areas[id] then
			return false, S("The area @1 does not exist.", id)
		end

		areas:setPos1(name, areas.areas[id].pos1)
		areas:setPos2(name, areas.areas[id].pos2)
		return true, S("Area @1 selected.", id)
	end,
})

minetest.register_chatcommand("area_pos1", {
	params = "[X Y Z|X,Y,Z]",
	description = S("Set area protection region position @1 to your"
		.." location or the one specified", "1"),
	privs = {},
	func = function(name, param)
		local pos
		local player = minetest.get_player_by_name(name)
		if player then
			pos = vector.round(player:get_pos())
		end
		local found, _, x_str, y_str, z_str = param:find(
			"^(~?-?%d*)[, ](~?-?%d*)[, ](~?-?%d*)$")
		if found then
			local get_pos, reason = parse_relative_pos(x_str, y_str, z_str, pos)
			if get_pos then
				pos = get_pos
			elseif not get_pos and reason then
				return false, reason
			end
		elseif param ~= "" then
			return false, S("Invalid usage, see /help @1.", "area_pos1")
		end
		if not pos then
			return false, S("Unable to get position.")
		end
		pos = posLimit(vector.round(pos))
		areas:setPos1(name, pos)
		return true, S("Area position @1 set to @2", "1",
				minetest.pos_to_string(pos))
	end,
})

minetest.register_chatcommand("area_pos2", {
	params = "[X Y Z|X,Y,Z]",
	description = S("Set area protection region position @1 to your"
		.." location or the one specified", "2"),
	func = function(name, param)
		local pos
		local player = minetest.get_player_by_name(name)
		if player then
			pos = vector.round(player:get_pos())
		end
		local found, _, x_str, y_str, z_str = param:find(
			"^(~?-?%d*)[, ](~?-?%d*)[, ](~?-?%d*)$")
		if found then
			local get_pos, reason = parse_relative_pos(x_str, y_str, z_str, pos)
			if get_pos then
				pos = get_pos
			elseif not get_pos and reason then
				return false, reason
			end
		elseif param ~= "" then
			return false, S("Invalid usage, see /help @1.", "area_pos2")
		end
		if not pos then
			return false, S("Unable to get position.")
		end
		pos = posLimit(vector.round(pos))
		areas:setPos2(name, pos)
		return true, S("Area position @1 set to @2", "2",
			minetest.pos_to_string(pos))
	end,
})


minetest.register_chatcommand("area_pos", {
	params = "set/set1/set2/get",
	description = S("Set area protection region, position 1, or position 2"
		.." by punching nodes, or display the region"),
	func = function(name, param)
		if param == "set" then -- Set both area positions
			areas.set_pos[name] = "pos1"
			return true, S("Select positions by punching two nodes.")
		elseif param == "set1" then -- Set area position 1
			areas.set_pos[name] = "pos1only"
			return true, S("Select position @1 by punching a node.", "1")
		elseif param == "set2" then -- Set area position 2
			areas.set_pos[name] = "pos2"
			return true, S("Select position @1 by punching a node.", "2")
		elseif param == "get" then -- Display current area positions
			local pos1str, pos2str = S("Position @1:", " 1"), S("Position @1:", " 2")
			if areas.pos1[name] then
				pos1str = pos1str..minetest.pos_to_string(areas.pos1[name])
			else
				pos1str = pos1str..S("<not set>")
			end
			if areas.pos2[name] then
				pos2str = pos2str..minetest.pos_to_string(areas.pos2[name])
			else
				pos2str = pos2str..S("<not set>")
			end
			return true, pos1str.."\n"..pos2str
		else
			return false, S("Unknown subcommand: @1", param)
		end
	end,
})

function areas:getPos(playerName)
	local pos1, pos2 = areas.pos1[playerName], areas.pos2[playerName]
	if not (pos1 and pos2) then
		return nil
	end
	-- Copy positions so that the area table doesn't contain multiple
	-- references to the same position.
	pos1, pos2 = vector.new(pos1), vector.new(pos2)
	return areas:sortPos(pos1, pos2)
end

function areas:setPos1(name, pos)
	local old_pos = areas.pos1[name]
	pos = posLimit(pos)
	areas.pos1[name] = pos

	local entity = minetest.add_entity(pos, "areas:pos1")
	areas.mark_region(name)
	if entity then
		local luaentity = entity:get_luaentity()
		if luaentity then
			luaentity.player = name
		end
	end

	if old_pos then
		for object in core.objects_inside_radius(old_pos, 0.01) do
			local luaentity = object:get_luaentity()
			if luaentity and luaentity.name == "areas:pos1" and luaentity.player == name then
				object:remove()
			end
		end
	end
end

function areas:setPos2(name, pos)
	local old_pos = areas.pos2[name]
	pos = posLimit(pos)
	areas.pos2[name] = pos

	local entity = minetest.add_entity(pos, "areas:pos2")
	areas.mark_region(name)
	if entity then
		local luaentity = entity:get_luaentity()
		if luaentity then
			luaentity.player = name
		end
	end

	if old_pos then
		for object in core.objects_inside_radius(old_pos, 0.01) do
			local luaentity = object:get_luaentity()
			if luaentity and luaentity.name == "areas:pos2" and luaentity.player == name then
				object:remove()
			end
		end
	end
end

minetest.register_on_punchnode(function(pos, node, puncher)
	local name = puncher:get_player_name()
	-- Currently setting position
	if name ~= "" and areas.set_pos[name] then
		if areas.set_pos[name] == "pos2" then
			areas:setPos2(name, pos)
			areas.set_pos[name] = nil
			minetest.chat_send_player(name,
					S("Position @1 set to @2", "2",
					minetest.pos_to_string(pos)))
		else
			areas:setPos1(name, pos)
			areas.set_pos[name] = areas.set_pos[name] == "pos1" and "pos2" or nil
			minetest.chat_send_player(name,
					S("Position @1 set to @2", "1",
					minetest.pos_to_string(pos)))
		end
	end
end)

-- Modifies positions `pos1` and `pos2` so that each component of `pos1`
-- is less than or equal to its corresponding component of `pos2`,
-- returning the two positions.
function areas:sortPos(pos1, pos2)
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	return pos1, pos2
end

areas.mark_region = function(name)
	local pos1, pos2 = areas.pos1[name], areas.pos2[name]

	if areas.marker_region[name] ~= nil then --marker already exists
		for _, entity in ipairs(areas.marker_region[name]) do
			entity:remove()
		end
		areas.marker_region[name] = nil
	end

	if pos1 ~= nil and pos2 ~= nil then
		--local pos1, pos2 = areas.sort_pos(pos1, pos2) Надо починить

		local vec = vector.subtract(pos2, pos1)
		local maxside = math.max(vec.x, math.max(vec.y, vec.z))
		local limit = tonumber(minetest.settings:get("active_object_send_range_blocks")) * 16
		if maxside > limit * 1.5 then
			-- The client likely won't be able to see the plane markers as intended anyway,
			-- thus don't place them and also don't load the area into memory
			return
		end

		local thickness = 0.2
		local sizex, sizey, sizez = (1 + pos2.x - pos1.x) / 2, (1 + pos2.y - pos1.y) / 2, (1 + pos2.z - pos1.z) / 2

		-- TODO maybe we could skip this actually?
		--areas.keep_loaded(pos1, pos2)

		local markers = {}

		--XY plane markers
		for _, z in ipairs({pos1.z - 0.5, pos2.z + 0.5}) do
			local entpos = vector.new(pos1.x + sizex - 0.5, pos1.y + sizey - 0.5, z)
			local marker = minetest.add_entity(entpos, "areas:region_cube", init_sentinel)
			if marker ~= nil then
				marker:set_properties({
					visual_size={x=sizex * 2, y=sizey * 2},
					collisionbox = {-sizex, -sizey, -thickness, sizex, sizey, thickness},
				})
				marker:get_luaentity().player_name = name
				table.insert(markers, marker)
			end
		end

		--YZ plane markers
		for _, x in ipairs({pos1.x - 0.5, pos2.x + 0.5}) do
			local entpos = vector.new(x, pos1.y + sizey - 0.5, pos1.z + sizez - 0.5)
			local marker = minetest.add_entity(entpos, "areas:region_cube", init_sentinel)
			if marker ~= nil then
				marker:set_properties({
					visual_size={x=sizez * 2, y=sizey * 2},
					collisionbox = {-thickness, -sizey, -sizez, thickness, sizey, sizez},
				})
				marker:set_yaw(math.pi / 2)
				marker:get_luaentity().player_name = name
				table.insert(markers, marker)
			end
		end

		areas.marker_region[name] = markers
	end
end

--convenience function that calls everything
areas.marker_update = function(name)
	areas.mark_pos1(name, false)
	areas.mark_pos2(name, false)
	areas.mark_region(name)
end

minetest.register_entity("areas:pos1", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"areas_pos1.png", "areas_pos1.png",
		            "areas_pos1.png", "areas_pos1.png",
		            "areas_pos1.png", "areas_pos1.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		hp_max = 1,
		armor_groups = {fleshy=100},
		static_save = false,
	},
})

minetest.register_entity("areas:pos2", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"areas_pos2.png", "areas_pos2.png",
		            "areas_pos2.png", "areas_pos2.png",
		            "areas_pos2.png", "areas_pos2.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		hp_max = 1,
		armor_groups = {fleshy=100},
		static_save = false,
	},
})

minetest.register_entity("areas:region_cube", {
	initial_properties = {
		visual = "upright_sprite",
		textures = {"worldedit_cube.png"},
		visual_size = {x=10, y=10},
		physical = false,
		static_save = false,
	},
	on_activate = function(self, staticdata, dtime_s)
		if staticdata ~= init_sentinel then
			-- we were loaded from before static_save = false was added
			self.object:remove()
		end
	end,
	on_punch = function(self, hitter)
		local markers = areas.marker_region[self.player_name]
		if not markers then
			return
		end
		for _, entity in ipairs(markers) do
			entity:remove()
		end
		areas.marker_region[self.player_name] = nil
	end,
	on_blast = function(self, damage)
		return false, false, {} -- don't damage or knockback
	end,
})
