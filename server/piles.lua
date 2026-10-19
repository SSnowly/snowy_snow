local SharedConfig = require 'configs.shared.main'

---@class SnowPile
---@field id      number
---@field zone    number
---@field x       number
---@field y       number
---@field z       number   ground search hint (zone height)
---@field heading number
---@field type    number   index into SharedConfig.piles.types
---@field left    number   scoops remaining

local M = {}

---@type table<number, SnowPile>
local piles = {}
local nextId = 0

---@param zoneId number
---@param x number
---@param y number
---@param z number
---@param heading number
---@param pileType number
---@return SnowPile
function M.add(zoneId, x, y, z, heading, pileType)
    nextId += 1
    local pile = {
        id = nextId, zone = zoneId, x = x, y = y, z = z, heading = heading,
        type = pileType, left = SharedConfig.piles.types[pileType].parts,
    }
    piles[pile.id] = pile
    TriggerClientEvent('snowy_snow:pileAdded', -1, pile)
    return pile
end

---@param id number
function M.remove(id)
    if not piles[id] then return end
    piles[id] = nil
    TriggerClientEvent('snowy_snow:pileRemoved', -1, id)
end

---@param zoneId number
function M.removeZone(zoneId)
    for id, pile in pairs(piles) do
        if pile.zone == zoneId then M.remove(id) end
    end
end

---@param zoneId number
---@return SnowPile[]
function M.inZone(zoneId)
    local list = {}
    for _, pile in pairs(piles) do
        if pile.zone == zoneId then list[#list + 1] = pile end
    end
    return list
end

---@param id number
---@return SnowPile?
function M.get(id)
    return piles[id]
end

---@param id number
---@return number? left
function M.takePart(id)
    local pile = piles[id]
    if not pile or pile.left <= 0 then return nil end
    pile.left -= 1
    if pile.left <= 0 then
        M.remove(id)
        return 0
    end
    TriggerClientEvent('snowy_snow:pileUpdated', -1, id, pile.left)
    return pile.left
end

lib.callback.register('snowy_snow:getPiles', function()
    local list = {}
    for _, pile in pairs(piles) do list[#list + 1] = pile end
    return list
end)

return M
