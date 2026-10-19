local Bridge = require 'bridge._index'
local ServerConfig = require 'configs.server.main'
local SharedConfig = require 'configs.shared.main'
local Piles = require 'server.piles'
local Util = require 'server.util'

---@class SnowZone
---@field id          number
---@field label       string
---@field x           number
---@field y           number
---@field z           number
---@field radius      number
---@field piles       number
---@field respawn     number   minutes
---@field nextRespawn number   os.time()

---@type table<number, SnowZone>
local zones = {}

---@param zone SnowZone
---@return vector2[]
local function pickSpots(zone)
    local spots = {}
    local attempts = zone.piles * 30
    while #spots < zone.piles and attempts > 0 do
        attempts -= 1
        local angle = math.random() * math.pi * 2
        local dist = math.sqrt(math.random()) * zone.radius
        local spot = vec2(zone.x + math.cos(angle) * dist, zone.y + math.sin(angle) * dist)
        local free = true
        for i = 1, #spots do
            if #(spots[i] - spot) < ServerConfig.pileSpacing then free = false break end
        end
        if free then spots[#spots + 1] = spot end
    end
    return spots
end

---@param zone SnowZone
local function respawnZone(zone)
    Piles.removeZone(zone.id)
    local typeCount = #SharedConfig.piles.types
    for _, spot in ipairs(pickSpots(zone)) do
        Piles.add(zone.id, spot.x, spot.y, zone.z, math.random() * 360.0, math.random(1, typeCount))
    end
    zone.nextRespawn = os.time() + zone.respawn * 60
    SnowyDebug(('zone %d respawned %d piles'):format(zone.id, #Piles.inZone(zone.id)))
end

---@param row table
---@return SnowZone
local function zoneFromRow(row)
    return {
        id = row.id, label = row.label, x = row.x, y = row.y, z = row.z,
        radius = row.radius, piles = row.piles, respawn = row.respawn, nextRespawn = 0,
    }
end

CreateThread(function()
    Bridge.ensureSchema()
    local rows = MySQL.query.await('SELECT * FROM `snowy_snow_zones`') or {}
    for _, row in ipairs(rows) do
        local zone = zoneFromRow(row)
        zones[zone.id] = zone
        respawnZone(zone)
    end
    while true do
        Wait(ServerConfig.respawnCheckSeconds * 1000)
        local now = os.time()
        for _, zone in pairs(zones) do
            if now >= zone.nextRespawn then respawnZone(zone) end
        end
    end
end)

---@param source number
---@param message string
---@param kind string?
local function reply(source, message, kind)
    if source == 0 then print(message) return end
    TriggerClientEvent('ox_lib:notify', source, { title = 'Snow zones', description = message, type = kind or 'inform' })
end

lib.addCommand('snowzone_add', {
    help = 'Create a snow pile zone centred on you',
    params = {
        { name = 'radius',  type = 'number', help = 'Zone radius in metres' },
        { name = 'piles',   type = 'number', help = 'Number of piles in the zone' },
        { name = 'respawn', type = 'number', help = 'Respawn interval in minutes', optional = true },
        { name = 'label',   type = 'string', help = 'Name', optional = true },
    },
    restricted = ServerConfig.adminGroup,
}, function(source, args)
    if not Util.isPlayerLoaded(source) then return end
    local radius = math.min(math.max(args.radius, 2.0), ServerConfig.maxZoneRadius)
    local count = math.floor(math.min(math.max(args.piles, 1), ServerConfig.maxPilesPerZone))
    local respawn = math.floor(math.max(args.respawn or ServerConfig.defaultRespawnMinutes, 1))
    local label = (args.label or ''):sub(1, 64)
    local c = Util.playerCoords(source)
    local id = MySQL.insert.await(
        'INSERT INTO `snowy_snow_zones` (`label`, `x`, `y`, `z`, `radius`, `piles`, `respawn`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { label, c.x, c.y, c.z, radius, count, respawn })
    if not id then return reply(source, 'Could not save the zone', 'error') end
    local zone = zoneFromRow({ id = id, label = label, x = c.x, y = c.y, z = c.z, radius = radius, piles = count, respawn = respawn })
    zones[id] = zone
    respawnZone(zone)
    reply(source, ('Zone #%d created: %.0f m, %d piles, respawn every %d min'):format(id, radius, count, respawn), 'success')
end)

lib.addCommand('snowzone_remove', {
    help = 'Delete a snow zone and its piles',
    params = { { name = 'id', type = 'number', help = 'Zone id (see /snowzone_list)' } },
    restricted = ServerConfig.adminGroup,
}, function(source, args)
    local zone = zones[args.id]
    if not zone then return reply(source, 'No zone with that id', 'error') end
    MySQL.update.await('DELETE FROM `snowy_snow_zones` WHERE `id` = ?', { zone.id })
    Piles.removeZone(zone.id)
    zones[zone.id] = nil
    reply(source, ('Zone #%d removed'):format(zone.id), 'success')
end)

lib.addCommand('snowzone_respawn', {
    help = 'Respawn the piles of one zone, or all zones',
    params = { { name = 'id', type = 'number', help = 'Zone id', optional = true } },
    restricted = ServerConfig.adminGroup,
}, function(source, args)
    if args.id then
        local zone = zones[args.id]
        if not zone then return reply(source, 'No zone with that id', 'error') end
        respawnZone(zone)
    else
        for _, zone in pairs(zones) do respawnZone(zone) end
    end
    reply(source, 'Piles respawned', 'success')
end)

lib.addCommand('snowzone_list', {
    help = 'List snow zones',
    restricted = ServerConfig.adminGroup,
}, function(source)
    local lines = {}
    for _, zone in pairs(zones) do
        lines[#lines + 1] = ('#%d %s  %.0f m  %d/%d piles  next respawn %d min'):format(
            zone.id, zone.label, zone.radius, #Piles.inZone(zone.id), zone.piles,
            math.max(0, math.floor((zone.nextRespawn - os.time()) / 60)))
    end
    reply(source, #lines > 0 and table.concat(lines, '\n') or 'No zones')
end)

lib.addCommand('snowzone_debug', {
    help = 'Toggle drawing of snow zones',
    restricted = ServerConfig.adminGroup,
}, function(source)
    local list = {}
    for _, zone in pairs(zones) do list[#list + 1] = zone end
    TriggerClientEvent('snowy_snow:debugZones', source, list)
end)
