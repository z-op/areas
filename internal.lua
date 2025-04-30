local S = core.get_translator("areas")

-- Проверяем наличие критически важных функций через core
local function check_core_features()
    if not core.get_mod_storage then
        error("[Areas] Требуется движок с поддержкой mod_storage (функция core.get_mod_storage не найдена)")
    end
    -- Добавьте другие необходимые проверки функций здесь
end

check_core_features()

-- Инициализация mod_storage
local mod_storage = core.get_mod_storage()

-- Логирование версии для информации (без проверки)
local version_info = core.get_version() or {string = "unknown"}
core.log("action", "[Areas] Запуск на движке: "..version_info.string)

-- Остальной код остается без изменений
function areas:player_exists(name)
    return core.get_auth_handler().get_auth(name) ~= nil
end

-- ... остальные функции мода ...

-- Новая система сохранения данных
function areas:save()
    local data = {
        areas = self.areas,
        store_ids = self.store_ids,
        owners = self.owners,
        open_areas = self.open_areas,
        config = self.config
    }
    mod_storage:set_string("areas_data", minetest.serialize(data))
end

-- Новая система загрузки данных с миграцией
function areas:load()
    -- Миграция старых данных
    if not mod_storage:contains("legacy_migrated") then
        core.log("action", "[Areas] Попытка миграции данных из старого формата...")

        local legacy_path = core.get_worldpath() .. "/areas.dat"
        local file = io.open(legacy_path, "r")

if file then
    core.log("action", "[Areas] Найден файл старого формата: " .. legacy_path)

    local content = file:read("*a")
    file:close()

    if content and content ~= "" then
        core.log("action", "[Areas] Переносим данные ("..#content.." байт)")

        -- Замена core.deserialize на JSON-парсинг
        local ok, legacy_data = pcall(core.parse_json, content)

        if ok and type(legacy_data) == "table" then
            -- Конвертация структуры (старый формат был массивом зон)
            local new_data = {
                areas = {},  -- Здесь будут преобразованные зоны
                store_ids = {},
                owners = {},
                open_areas = {},
                config = {}
            }

            -- Переносим каждую зону с преобразованием полей
            for _, old_area in ipairs(legacy_data) do
                local new_area = {
                    name = old_area.name,
                    owner = old_area.owner,
                    pos1 = old_area.pos1,
                    pos2 = old_area.pos2,
                    open = old_area.open or false
                }
                table.insert(new_data.areas, new_area)
            end

            -- Сохранение
            mod_storage:set_string("areas_data", core.serialize(new_data))
            os.rename(legacy_path, legacy_path .. ".backup")
            core.log("action", "[Areas] Успешно перенесено зон: "..#legacy_data)
                else
                    core.log("error", "[Areas] Ошибка десериализации legacy-данных")
                end
            else
                core.log("action", "[Areas] Файл миграции пуст")
            end

            -- Помечаем миграцию как завершённую
            mod_storage:set_string("legacy_migrated", "true")
        else
            core.log("action", "[Areas] Файл для миграции не найден")
            mod_storage:set_string("legacy_migrated", "true")
        end
    end

    -- Загрузка из mod_storage
    core.log("action", "[Areas] Загрузка данных из mod_storage...")
    local serialized = mod_storage:get_string("areas_data")

    if serialized and serialized ~= "" then
        local ok, data = pcall(core.deserialize, serialized)
        if ok and type(data) == "table" then
            self.areas = data.areas or {}
            self.store_ids = data.store_ids or {}
            self.owners = data.owners or {}
            self.open_areas = data.open_areas or {}
            -- Объединяем загруженный конфиг с текущим (приоритет у сохраненных данных)
            self.config = self.config or {}
            if data.config then
				for k, v in pairs(data.config) do
					self.config[k] = v
				end
			end
            core.log("action", "[Areas] Успешно загружено: "..#self.areas.." зон")
        else
            core.log("error", "[Areas] Ошибка десериализации данных из mod_storage")
        end
    else
        core.log("action", "[Areas] Данные в mod_storage отсутствуют")
    end

    -- Инициализация по умолчанию
    self.areas = self.areas or {}
    self:populateStore()
end

--- [Оригинальные функции без изменений] ---
function areas:checkAreaStoreId(sid)
    if not sid then
        minetest.log("error", "AreaStore failed to find an ID for an area! Falling back to iterative area checking.")
        self.store = nil
        self.store_ids = nil
    end
    return sid and true or false
end

function areas:populateStore()
    if not rawget(_G, "AreaStore") then return end

    local store = AreaStore()
    local store_ids = {}
    for id, area in pairs(areas.areas) do
        local sid = store:insert_area(area.pos1, area.pos2, tostring(id))
        if self:checkAreaStoreId(sid) then
            store_ids[id] = sid
        end
    end
    self.store = store
    self.store_ids = store_ids
end

local index_cache = 0
local function findFirstUnusedIndex()
    local t = areas.areas
    repeat index_cache = index_cache + 1 until t[index_cache] == nil
    return index_cache
end

function areas:add(owner, name, pos1, pos2, parent)
    local id = findFirstUnusedIndex()
    self.areas[id] = {
        name = name,
        pos1 = pos1,
        pos2 = pos2,
        owner = owner,
        parent = parent
    }

    for i=1, #areas.registered_on_adds do
        areas.registered_on_adds[i](id, self.areas[id])
    end

    if self.store then
        local sid = self.store:insert_area(pos1, pos2, tostring(id))
        if self:checkAreaStoreId(sid) then
            self.store_ids[id] = sid
        end
    end

    self:save() -- Автосохранение
    return id
end

function areas:remove(id, recurse)
    if recurse then
        local cids = self:getChildren(id)
        for _, cid in pairs(cids) do
            self:remove(cid, true)
        end
    else
        local parent = self.areas[id].parent
        local children = self:getChildren(id)
        for _, cid in pairs(children) do
            self.areas[cid].parent = parent
        end
    end

    for i=1, #areas.registered_on_removes do
        areas.registered_on_removes[i](id)
    end

    self.areas[id] = nil

    if self.store then
        self.store:remove_area(self.store_ids[id])
        self.store_ids[id] = nil
    end

    self:save() -- Автосохранение
end

function areas:move(id, area, pos1, pos2)
    area.pos1 = pos1
    area.pos2 = pos2

    for i=1, #areas.registered_on_moves do
        areas.registered_on_moves[i](id, area, pos1, pos2)
    end

    if self.store then
        self.store:remove_area(areas.store_ids[id])
        local sid = self.store:insert_area(pos1, pos2, tostring(id))
        if self:checkAreaStoreId(sid) then
            self.store_ids[id] = sid
        end
    end

    self:save() -- Автосохранение
end

function areas:isSubarea(pos1, pos2, id)
    local area = self.areas[id]
    if not area then return false end
    local ap1, ap2 = area.pos1, area.pos2
    return
        pos1.x >= ap1.x and pos2.x <= ap2.x and
        pos1.y >= ap1.y and pos2.y <= ap2.y and
        pos1.z >= ap1.z and pos2.z <= ap2.z
end

function areas:getChildren(id)
    local children = {}
    for cid, area in pairs(self.areas) do
        if area.parent and area.parent == id then
            table.insert(children, cid)
        end
    end
    return children
end

function areas:canPlayerAddArea(pos1, pos2, name)
    local allowed = true
    local errMsg
    for i=1, #areas.registered_protection_conditions do
        local res, msg = areas.registered_protection_conditions[i](pos1, pos2, name)
        if res == true then
            return true
        elseif res == false then
            allowed = false
            errMsg = errMsg or msg
        elseif res ~= nil then
            local origin = areas.callback_origins[areas.registered_protection_conditions[i]]
            error("\n[Mod] areas: Invalid api usage from mod '"..
                origin.mod.."' in callback registerProtectionCondition() at "..
                origin.source..":"..origin.line)
        end
    end
    return allowed, errMsg
end

-- [Оригинальные регистрации условий защиты]
areas:registerProtectionCondition(function(pos1, pos2, name)
    local privs = minetest.get_player_privs(name)
    if privs.areas then return true end

    if not areas.config.self_protection or not privs[areas.config.self_protection_privilege] then
        return false, S("Self protection is disabled or you do not have the necessary privilege.")
    end
end)

areas:registerProtectionCondition(function(pos1, pos2, name)
    local privs = minetest.get_player_privs(name)
    local max_size = privs.areas_high_limit and
        areas.config.self_protection_max_size_high or
        areas.config.self_protection_max_size
    if (pos2.x - pos1.x + 1) > max_size.x or
       (pos2.y - pos1.y + 1) > max_size.y or
       (pos2.z - pos1.z + 1) > max_size.z then
        return false, S("Area is too big.")
    end
end)

areas:registerProtectionCondition(function(pos1, pos2, name)
    local privs = minetest.get_player_privs(name)
    local count = 0
    for _, area in pairs(areas.areas) do
        if area.owner == name then count = count + 1 end
    end
    local max_areas = privs.areas_high_limit and
        areas.config.self_protection_max_areas_high or
        areas.config.self_protection_max_areas
    if count >= max_areas then
        return false, S("You have reached the maximum amount of areas that you are allowed to protect.")
    end
end)

areas:registerProtectionCondition(function(pos1, pos2, name)
    local can, id = areas:canInteractInArea(pos1, pos2, name)
    if not can then
        local area = areas.areas[id]
        return false, S("The area intersects with @1 [@2] (@3).", area.name, id, area.owner)
    end
end)

function areas:toString(id)
    local area = self.areas[id]
    local message = ("%s [%d]: %s %s %s"):format(
        area.name, id, area.owner,
        minetest.pos_to_string(area.pos1),
        minetest.pos_to_string(area.pos2))

    local children = areas:getChildren(id)
    if #children > 0 then
        message = message.." -> "..table.concat(children, ", ")
    end
    return message
end

function areas:sort()
    local sa = {}
    for k, area in pairs(self.areas) do
        if not area.parent then
            table.insert(sa, area)
            local newid = #sa
            for _, subarea in pairs(self.areas) do
                if subarea.parent == k then
                    subarea.parent = newid
                    table.insert(sa, subarea)
                end
            end
        end
    end
    self.areas = sa
end

function areas:isAreaOwner(id, name)
    local cur = self.areas[id]
    if cur and minetest.check_player_privs(name, self.adminPrivs) then
        return true
    end
    while cur do
        if cur.owner == name then return true
        elseif cur.parent then cur = self.areas[cur.parent]
        else break end
    end
    return false
end
