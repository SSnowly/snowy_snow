local Bridge = require 'bridge._index'
local ServerConfig = require 'configs.server.main'
local SharedConfig = require 'configs.shared.main'
local Piles = require 'server.piles'
local Util = require 'server.util'

---@class ShovelState
---@field out      boolean
---@field loaded   boolean
---@field scooping boolean?
---@field dumping  boolean?

local M = {}

---@type table<number, ShovelState>
local shovels = {}

---@type fun(source: number): boolean
local isHoldingBarrow = function() return false end

---@param check fun(source: number): boolean
function M.setBarrowCheck(check)
    isHoldingBarrow = check
end

---@param source number
---@return ShovelState
function M.get(source)
    return shovels[source] or { out = false, loaded = false }
end

---@param source number
---@param state ShovelState
local function publish(source, state)
    shovels[source] = state
    Player(source).state:set('snowyShovel', { out = state.out, loaded = state.loaded, scooping = state.scooping == true, dumping = state.dumping == true }, true)
end

---@param source number
---@param loaded boolean
function M.setLoaded(source, loaded)
    local state = M.get(source)
    publish(source, { out = state.out, loaded = loaded })
end

lib.callback.register('snowy_snow:setShovelOut', function(source, wantOut)
    if not Util.isPlayerLoaded(source) then return false end
    wantOut = wantOut == true
    if wantOut and not Bridge.hasItem(source, SharedConfig.items.shovel) then return false end
    if wantOut and isHoldingBarrow(source) then return false end
    if M.get(source).scooping or M.get(source).dumping then return false end
    publish(source, { out = wantOut, loaded = false })
    return true
end)

lib.callback.register('snowy_snow:scoop', function(source, pileId)
    if not Util.isPlayerLoaded(source) or type(pileId) ~= 'number' then return false end
    local state = M.get(source)
    if not state.out or state.loaded then return false end
    if not Bridge.hasItem(source, SharedConfig.items.shovel) then
        publish(source, { out = false, loaded = false })
        return false
    end
    local pile = Piles.get(pileId)
    if not pile then return false end
    if not Util.isNear2d(source, vec3(pile.x, pile.y, pile.z), ServerConfig.maxInteractDistance) then return false end
    if not Util.consumeCooldown(source, 'scoop', ServerConfig.scoopCooldownMs) then return false end
    local left = Piles.takePart(pileId)
    if not left then return false end
    publish(source, { out = true, loaded = true, scooping = true })
    SetTimeout(SharedConfig.shovel.scoopMs, function()
        local current = shovels[source]
        if current and current.scooping then
            publish(source, { out = current.out, loaded = current.loaded, scooping = false })
        end
    end)
    return true
end)

---@param source number
---@param onTip fun()?
---@return boolean
function M.startDump(source, onTip)
    local state = M.get(source)
    if not state.loaded or state.scooping or state.dumping then return false end
    publish(source, { out = state.out, loaded = true, dumping = true })
    if onTip then SetTimeout(SharedConfig.shovel.tipAtMs, onTip) end
    SetTimeout(SharedConfig.shovel.dumpMs, function()
        local current = shovels[source]
        if current and current.dumping then
            publish(source, { out = current.out, loaded = false, dumping = false })
        end
    end)
    return true
end

lib.callback.register('snowy_snow:dumpShovel', function(source)
    if not Util.isPlayerLoaded(source) then return false end
    if not Util.consumeCooldown(source, 'dump', ServerConfig.dumpCooldownMs) then return false end
    return M.startDump(source)
end)

AddEventHandler('playerDropped', function()
    shovels[source] = nil
    Util.clearPlayer(source)
end)

return M
