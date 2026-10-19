local Bridge = require 'bridge._index'
local ServerConfig = require 'configs.server.main'
local SharedConfig = require 'configs.shared.main'
local Shovel = require 'server.shovel'
local Util = require 'server.util'

---@class SnowBarrow
---@field entity number
---@field snow   number
---@field holder number?
---@field owner  number   player who placed it

---@type table<number, SnowBarrow>
local barrows = {}

Shovel.setBarrowCheck(function(source)
    for _, barrow in pairs(barrows) do
        if barrow.holder == source then return true end
    end
    return false
end)

---@param netId number
---@return SnowBarrow?, number?
local function getBarrow(netId)
    if type(netId) ~= 'number' then return nil end
    local barrow = barrows[netId]
    if not barrow then return nil end
    if not DoesEntityExist(barrow.entity) then
        barrows[netId] = nil
        return nil
    end
    return barrow, netId
end

---@param barrow SnowBarrow
local function publish(barrow)
    Entity(barrow.entity).state:set('snowyBarrow', { snow = barrow.snow, holder = barrow.holder }, true)
end

---@param source number
---@param barrow SnowBarrow
---@return boolean
local function inReach(source, barrow)
    return Util.isNear2d(source, GetEntityCoords(barrow.entity), ServerConfig.maxInteractDistance)
end

---@param source number
---@param snow number
---@return boolean
local function spawnFor(source, snow)
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local h = math.rad(GetEntityHeading(ped))
    local x, y = c.x - math.sin(h) * 1.6, c.y + math.cos(h) * 1.6
    local entity = CreateObjectNoOffset(joaat(SharedConfig.barrow.model), x, y, c.z - 0.9, true, true, false)
    local ok = lib.waitFor(function() if DoesEntityExist(entity) then return true end end, nil, 2000)
    if not ok then return false end
    SetEntityHeading(entity, GetEntityHeading(ped))
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local barrow = { entity = entity, snow = snow, holder = nil, owner = source }
    barrows[netId] = barrow
    publish(barrow)
    TriggerClientEvent('snowy_snow:placeBarrow', source, netId)
    return true
end

exports('useWheelbarrow', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local source = inventory.id
    if not Util.isPlayerLoaded(source) then return false end
    local data = Bridge.getSlot(source, slot)
    if not data or data.name ~= SharedConfig.items.wheelbarrow then return false end
    local snow = math.floor(math.min(math.max(tonumber(data.metadata and data.metadata.snow) or 0, 0), SharedConfig.barrow.capacity))
    if not Bridge.removeItem(source, SharedConfig.items.wheelbarrow, 1, nil, slot) then return false end
    if not spawnFor(source, snow) then
        Bridge.addItem(source, SharedConfig.items.wheelbarrow, 1, { snow = snow })
    end
    return false
end)

lib.callback.register('snowy_snow:grabBarrow', function(source, netId)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(netId)
    if not barrow or not inReach(source, barrow) then return false end
    if barrow.holder and barrow.holder ~= source and GetPlayerName(barrow.holder) then return false end
    if Shovel.get(source).out then return false, 'shovel_out' end
    barrow.holder = source
    publish(barrow)
    return true
end)

lib.callback.register('snowy_snow:releaseBarrow', function(source, netId)
    local barrow = getBarrow(netId)
    if not barrow or barrow.holder ~= source then return false end
    barrow.holder = nil
    publish(barrow)
    return true
end)

lib.callback.register('snowy_snow:pickupBarrow', function(source, netId)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow, id = getBarrow(netId)
    if not barrow or not inReach(source, barrow) then return false end
    if barrow.holder and barrow.holder ~= source then return false end
    local snow = barrow.snow
    barrows[id] = nil
    DeleteEntity(barrow.entity)
    if not Bridge.addItem(source, SharedConfig.items.wheelbarrow, 1, { snow = snow }) then
        spawnFor(source, snow)
        return false, 'full'
    end
    return true
end)

lib.callback.register('snowy_snow:dumpIntoBarrow', function(source, netId)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(netId)
    if not barrow or not inReach(source, barrow) then return false end
    local shovel = Shovel.get(source)
    if not shovel.loaded or shovel.scooping or shovel.dumping then return false end
    if barrow.snow >= SharedConfig.barrow.capacity then return false, 'full' end
    if not Util.consumeCooldown(source, 'dump', ServerConfig.dumpCooldownMs) then return false end
    barrow.snow += 1
    local snow = barrow.snow
    local started = Shovel.startDump(source, function()
        if barrows[netId] == barrow then publish(barrow) end
    end)
    if not started then
        barrow.snow -= 1
        return false
    end
    TriggerEvent('snowy_snow:barrowFilled', source, netId, snow)
    return true, snow
end)

lib.callback.register('snowy_snow:emptyBarrow', function(source, netId)
    if not Util.isPlayerLoaded(source) then return false end
    local barrow = getBarrow(netId)
    if not barrow or not inReach(source, barrow) or barrow.snow <= 0 then return false end
    local amount = barrow.snow
    barrow.snow = 0
    publish(barrow)
    TriggerEvent('snowy_snow:barrowEmptied', source, netId, amount)
    return true
end)

exports('getBarrowSnow', function(netId)
    local barrow = getBarrow(netId)
    return barrow and barrow.snow or nil
end)

AddEventHandler('playerDropped', function()
    for _, barrow in pairs(barrows) do
        if barrow.holder == source then
            barrow.holder = nil
            publish(barrow)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, barrow in pairs(barrows) do
        if DoesEntityExist(barrow.entity) then DeleteEntity(barrow.entity) end
        if Util.isPlayerLoaded(barrow.owner) then
            Bridge.addItem(barrow.owner, SharedConfig.items.wheelbarrow, 1, { snow = barrow.snow })
        end
    end
end)
