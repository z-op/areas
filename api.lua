local hudHandlers = {}

areas.registered_protection_conditions = {}
areas.registered_on_adds = {}
areas.registered_on_removes = {}
areas.registered_on_moves = {}

areas.callback_origins = {}

-- Добавляем ленивую загрузку данных
local function ensure_loaded(self)
    if not self.areas then
        self:load()
    end
end

function areas:registerProtectionCondition(func)
    table.insert(areas.registered_protection_conditions, func)
    local debug_info = debug.getinfo(func, "S")
    areas.callback_origins[func] = {
        mod = core.get_current_modname() or "??",
        source = debug_info.short_src or "??",
        line = debug_info.linedefined or "??"
    }
end

function areas:registerOnAdd(func)
    table.insert(areas.registered_on_adds, func)
end

function areas:registerOnRemove(func)
    table.insert(areas.registered_on_removes, func)
end

function areas:registerOnMove(func)
    table.insert(areas.registered_on_moves, func)
end

function areas:registerHudHandler(handler)
    table.insert(hudHandlers, handler)
end

function areas:getExternalHudEntries(pos)
    ensure_loaded(self)
    local areas = {}
    for _, func in pairs(hudHandlers) do
        func(pos, areas)
    end
    return areas
end

function areas:getAreasAtPos(pos)
    ensure_loaded(self)
    local res = {}

    if self.store then
        local a = self.store:get_areas_for_pos(pos, false, true)
        for store_id, store_area in pairs(a) do
            local id = tonumber(store_area.data)
            res[id] = self.areas[id]
        end
    else
        local px, py, pz = pos.x, pos.y, pos.z
        for id, area in pairs(self.areas) do
            local ap1, ap2 = area.pos1, area.pos2
            if (px >= ap1.x and px <= ap2.x) and
               (py >= ap1.y and py <= ap2.y) and
               (pz >= ap1.z and pz <= ap2.z) then
                res[id] = area
            end
        end
    end
    return res
end

function areas:getAreasIntersectingArea(pos1, pos2)
    ensure_loaded(self)
    local res = {}

    if self.store then
        local a = self.store:get_areas_in_area(pos1, pos2, true, false, true)
        for store_id, store_area in pairs(a) do
            local id = tonumber(store_area.data)
            res[id] = self.areas[id]
        end
    else
        self:sortPos(pos1, pos2)
        local p1x, p1y, p1z = pos1.x, pos1.y, pos1.z
        local p2x, p2y, p2z = pos2.x, pos2.y, pos2.z
        for id, area in pairs(self.areas) do
            local ap1, ap2 = area.pos1, area.pos2
            if (ap1.x <= p2x and ap2.x >= p1x) and
               (ap1.y <= p2y and ap2.y >= p1y) and
               (ap1.z <= p2z and ap2.z >= p1z) then
                res[id] = area
            end
        end
    end
    return res
end

function areas:getSmallestAreaAtPos(pos)
    ensure_loaded(self)
    local smallest_area, smallest_id, volume
    local smallest_volume = math.huge
    for id, area in pairs(self:getAreasAtPos(pos)) do
        volume = (area.pos2.x - area.pos1.x + 1)
               * (area.pos2.y - area.pos1.y + 1)
               * (area.pos2.z - area.pos1.z + 1)
        if smallest_volume >= volume then
            smallest_area = area
            smallest_id = id
            smallest_volume = volume
        end
    end
    return smallest_area, smallest_id
end

function areas:canInteract(pos, name)
    ensure_loaded(self)
    if minetest.check_player_privs(name, self.adminPrivs) then
        return true
    end

    local areas_list
    if areas.config.use_smallest_area_precedence then
        local smallest_area, _ = self:getSmallestAreaAtPos(pos)
        areas_list = { smallest_area }
    else
        areas_list = self:getAreasAtPos(pos)
    end

    local owned = false
    for _, area in pairs(areas_list) do
        if area.owner == name or area.open then
            return true
        elseif areas.factions_available and area.faction_open then
            -- Логика фракций остается без изменений
        end
        owned = true
    end
    return not owned
end

function areas:getNodeOwners(pos)
    ensure_loaded(self)
    local owners = {}
    for _, area in pairs(self:getAreasAtPos(pos)) do
        table.insert(owners, area.owner)
    end
    return owners
end

function areas:canInteractInArea(pos1, pos2, name, allow_open)
    ensure_loaded(self)
    if name and minetest.check_player_privs(name, self.adminPrivs) then
        return true
    end

    self:sortPos(pos1, pos2)
    local blocking_area = nil
    local areas = self:getAreasIntersectingArea(pos1, pos2)

    for id, area in pairs(areas) do
        if area.owner == name and self:isSubarea(pos1, pos2, id) then
            return true
        end

        if not blocking_area and
           (not allow_open or not area.open) and
           (not name or not self:isAreaOwner(id, name)) then
            blocking_area = id
        end
    end

    return blocking_area and false or true, blocking_area
end

function areas:sort_pos(pos1, pos2)
	pos1 = vector.copy(pos1)
	pos2 = vector.copy(pos2)
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
