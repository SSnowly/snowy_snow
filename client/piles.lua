local SharedConfig = require 'configs.shared.main'
local Ground = require 'client.ground'

---@class PileVisual
---@field data   SnowPile
---@field point  table
---@field pose   GroundPose?
---@field full   number?
---@field chunks table<number, number>
---@field inside boolean?

local M = {}

---@type table<number, PileVisual>
local piles = {}

---@param name string
---@param pose GroundPose
---@return number
local function spawnLocal(name, pose)
    local obj = lib.prop.create(name, pose.coords.x, pose.coords.y, pose.coords.z).handle
    Ground.apply(obj, pose)
    FreezeEntityPosition(obj, true)
    return obj
end

---@param visual PileVisual
local function clearObjects(visual)
    if visual.full and DoesEntityExist(visual.full) then DeleteEntity(visual.full) end
    visual.full = nil
    for i, obj in pairs(visual.chunks) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        visual.chunks[i] = nil
    end
end

---@param visual PileVisual
local function build(visual)
    local data = visual.data
    local def = SharedConfig.piles.types[data.type]
    if not def then return end
    if not visual.pose then
        visual.pose = Ground.pose(data.x, data.y, data.z, data.heading, SharedConfig.piles.maxTiltDeg, SharedConfig.piles.sinkDepth)
        if not visual.pose then return end
    end
    if data.left >= def.parts then
        if not visual.full then
            clearObjects(visual)
            visual.full = spawnLocal(def.full, visual.pose)
        end
        return
    end
    if visual.full then
        DeleteEntity(visual.full)
        visual.full = nil
    end
    local removed = def.parts - data.left
    for i = 1, def.parts do
        if i <= removed then
            if visual.chunks[i] then
                DeleteEntity(visual.chunks[i])
                visual.chunks[i] = nil
            end
        elseif not visual.chunks[i] then
            visual.chunks[i] = spawnLocal(def.chunk:format(i), visual.pose)
        end
    end
end

---@param data SnowPile
local function addPile(data)
    if piles[data.id] then return end
    local visual = { data = data, chunks = {} }
    visual.point = lib.points.new({
        coords = vec3(data.x, data.y, data.z),
        distance = SharedConfig.piles.renderDistance,
        onEnter = function()
            visual.inside = true
            CreateThread(function()
                build(visual)
                if not visual.inside then clearObjects(visual) end
            end)
        end,
        onExit = function()
            visual.inside = false
            clearObjects(visual)
        end,
    })
    piles[data.id] = visual
end

---@param id number
local function removePile(id)
    local visual = piles[id]
    if not visual then return end
    visual.inside = false
    visual.point:remove()
    clearObjects(visual)
    piles[id] = nil
end

RegisterNetEvent('snowy_snow:pileAdded', addPile)
RegisterNetEvent('snowy_snow:pileRemoved', removePile)
RegisterNetEvent('snowy_snow:pileUpdated', function(id, left)
    local visual = piles[id]
    if not visual then return end
    visual.data.left = left
    if not visual.inside then return end
    CreateThread(function()
        build(visual)
        if not visual.inside then clearObjects(visual) end
    end)
end)

CreateThread(function()
    local list = lib.callback.await('snowy_snow:getPiles', false) or {}
    for _, data in ipairs(list) do addPile(data) end
end)

---@param coords vector3
---@param maxDistance number
---@return SnowPile?, vector3?
function M.nearest(coords, maxDistance)
    local best, bestDist, bestPos
    for _, visual in pairs(piles) do
        local pos = visual.pose and visual.pose.coords or vec3(visual.data.x, visual.data.y, visual.data.z)
        local d = #(vec2(coords.x, coords.y) - vec2(pos.x, pos.y))
        if d <= maxDistance and (not bestDist or d < bestDist) then
            best, bestDist, bestPos = visual.data, d, pos
        end
    end
    return best, bestPos
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(piles) do removePile(id) end
end)

return M
