local Bridge = require 'bridge._index'
local ServerConfig = require 'configs.server.main'
local SharedConfig = require 'configs.shared.main'
local Shovel = require 'server.shovel'
local Util = require 'server.util'

---@class SnowBarrowData
---@field id      number
---@field x       number
---@field y       number
---@field z       number
---@field heading number
---@field snow    number
---@field holder  number?

---@class SnowBarrow : SnowBarrowData
---@field owner number   player who placed it

---@type table<number, SnowBarrow>
local barrows = {}
local nextId = 0

Shovel.setBarrowCheck(function(source)
    for _, barrow in pairs(barrows) do
        if barrow.holder == source then return true end
    end
    return false
end)

---@param id number
---@return SnowBarrow?
local function getBarrow(id)
    if type(id) ~= 'number' then return nil end
    return barrows[id]
end

---@param barrow SnowBarrow
---@return SnowBarrowData
local function payload(barrow)
    return {
        id = barrow.id, x = barrow.x, y = barrow.y, z = barrow.z,
        heading = barrow.heading, snow = barrow.snow, holder = barrow.holder,
    }
end

---@param barrow SnowBarrow
local function publish(barrow)
    TriggerClientEvent('snowy_snow:barrowUpdated', -1, payload(barrow))
end

---@param barrow SnowBarrow
---@return vector3
local function positionOf(barrow)
    if barrow.holder then
        local ped = GetPlayerPed(barrow.holder)
        if ped ~= 0 and DoesEntityExist(ped) then return GetEntityCoords(ped) end
    end
    return vec3(barrow.x, barrow.y, barrow.z)
end

---@param source number
---@param barrow SnowBarrow
---@return boolean
local function inReach(source, barrow)
    return Util.isNear2d(source, positionOf(barrow), ServerConfig.maxInteractDistance)
end

---@param barrow SnowBarrow
---@param coords vector3
---@param heading number
local function setDown(barrow, coords, heading)
    barrow.x, barrow.y, barrow.z, barrow.heading = coords.x, coords.y, coords.z, heading
    barrow.holder = nil
    publish(barrow)
end

---@param source number
---@param snow number
local function spawnFor(source, snow)
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local h = math.rad(heading)
    nextId += 1
    local barrow = {
        id = nextId, owner = source, snow = snow, holder = nil,
        x = c.x - math.sin(h) * 1.6, y = c.y + math.cos(h) * 1.6, z = c.z - 0.9, heading = heading,
    }
    barrows[barrow.id] = barrow
    TriggerClientEvent('snowy_snow:barrowAdded', -1, payload(barrow))
end

---@param id number
local function remove(id)
    if not barrows[id] then return end
    barrows[id] = nil
    TriggerClientEvent('snowy_snow:barrowRemoved', -1, id)
end

exports('useWheelbarrow', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local source = inventory.id
    if not Util.isPlayerLoaded(source) then return false end
    local data = Bridge.getSlot(source, slot)
    if not data or data.name ~= SharedConfig.items.wheelbarrow then return false end
    local snow = math.floor(math.min(math.max(tonumber(data.metadata and data.metadata.snow) or 0, 0), SharedConfig.barrow.capacity))
    if not Bridge.removeItem(source, SharedConfig.items.wheelbarrow, 1, nil, slot) then return false end
    spawnFor(source, snow)
    return false
end)

lib.callback.register('snowy_snow:getBarrows', function()
    local list = {}
    for _, barrow in pairs(barrows) do list[#list + 1] = payload(barrow) end
    return list
end)

lib.callback.register('snowy_snow:grabBarrow', function(source, id)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(id)
    if not barrow or not inReach(source, barrow) then return false end
    if barrow.holder and barrow.holder ~= source and GetPlayerName(barrow.holder) then return false end
    if Shovel.get(source).out then return false, 'shovel_out' end
    barrow.holder = source
    publish(barrow)
    return true
end)

lib.callback.register('snowy_snow:releaseBarrow', function(source, id, x, y, z, heading)
    local barrow = getBarrow(id)
    if not barrow or barrow.holder ~= source then return false end
    local ped = GetPlayerPed(source)
    local coords = type(x) == 'number' and type(y) == 'number' and type(z) == 'number' and vec3(x, y, z)
    if not coords or not Util.isNear2d(source, coords, ServerConfig.maxInteractDistance) then
        coords = GetEntityCoords(ped) - vec3(0.0, 0.0, 0.9)
    end
    setDown(barrow, coords, type(heading) == 'number' and heading % 360.0 or GetEntityHeading(ped))
    return true
end)

lib.callback.register('snowy_snow:pickupBarrow', function(source, id)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(id)
    if not barrow or not inReach(source, barrow) then return false end
    if barrow.holder and barrow.holder ~= source then return false end
    if not Bridge.addItem(source, SharedConfig.items.wheelbarrow, 1, { snow = barrow.snow }) then
        return false, 'full'
    end
    remove(id)
    return true
end)

lib.callback.register('snowy_snow:dumpIntoBarrow', function(source, id)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(id)
    if not barrow or not inReach(source, barrow) then return false end
    local shovel = Shovel.get(source)
    if not shovel.loaded or shovel.scooping or shovel.dumping then return false end
    if barrow.snow >= SharedConfig.barrow.capacity then return false, 'full' end
    if not Util.consumeCooldown(source, 'dump', ServerConfig.dumpCooldownMs) then return false end
    barrow.snow += 1
    local snow = barrow.snow
    local started = Shovel.startDump(source, function()
        if barrows[id] == barrow then publish(barrow) end
    end)
    if not started then
        barrow.snow -= 1
        return false
    end
    TriggerEvent('snowy_snow:barrowFilled', source, id, snow)
    return true, snow
end)

lib.callback.register('snowy_snow:emptyBarrow', function(source, id)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(id)
    if not barrow or not inReach(source, barrow) or barrow.snow <= 0 then return false end
    local amount = barrow.snow
    barrow.snow = 0
    publish(barrow)
    TriggerEvent('snowy_snow:barrowEmptied', source, id, amount)
    return true
end)

exports('getBarrowSnow', function(id)
    local barrow = getBarrow(id)
    return barrow and barrow.snow or nil
end)

AddEventHandler('playerDropped', function()
    for _, barrow in pairs(barrows) do
        if barrow.holder == source then
            local ped = GetPlayerPed(source)
            local coords = vec3(barrow.x, barrow.y, barrow.z)
            if ped ~= 0 and DoesEntityExist(ped) then coords = GetEntityCoords(ped) - vec3(0.0, 0.0, 0.9) end
            setDown(barrow, coords, barrow.heading)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, barrow in pairs(barrows) do
        if Util.isPlayerLoaded(barrow.owner) then
            Bridge.addItem(barrow.owner, SharedConfig.items.wheelbarrow, 1, { snow = barrow.snow })
        end
    end
end)
