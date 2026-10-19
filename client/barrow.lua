local SharedConfig = require 'configs.shared.main'
local Attach = require 'client.attach'
local Carry = require 'client.carry'
local Prompt = require 'client.prompt'
local Status = require 'client.status'

local cfg = SharedConfig.barrow
local anims = SharedConfig.anims
local keys = SharedConfig.keys
local barrowHash = joaat(cfg.model)

local M = {}

---@class BarrowLoadVisual
---@field model string?
---@field obj   number?

---@type table<number, BarrowLoadVisual>
local loads = {}
---@type number[]
local nearbyBarrows = {}

---@param entity number
---@return table?
local function barrowState(entity)
    return Entity(entity).state.snowyBarrow
end

---@param snow number
---@return string?
local function stageModel(snow)
    local model
    for _, stage in ipairs(cfg.stages) do
        if snow >= stage.min then model = stage.model end
    end
    return model
end

---@param entity number
---@param snow number
local function syncLoad(entity, snow)
    local visual = loads[entity] or {}
    loads[entity] = visual
    local want = stageModel(snow)
    if visual.model == want and (not want or DoesEntityExist(visual.obj)) then return end
    Attach.delete(visual.obj)
    visual.obj, visual.model = nil, want
    if not want then return end
    visual.obj = Attach.createLocal(want, GetEntityCoords(entity))
    AttachEntityToEntity(visual.obj, entity, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local seen, list = {}, {}
        for _, entity in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(entity) == barrowHash and #(GetEntityCoords(entity) - me) < 80.0 then
                local state = barrowState(entity)
                if state then
                    seen[entity] = true
                    list[#list + 1] = entity
                    syncLoad(entity, state.snow or 0)
                end
            end
        end
        for entity, visual in pairs(loads) do
            if not seen[entity] then
                Attach.delete(visual.obj)
                loads[entity] = nil
            end
        end
        nearbyBarrows = list
        Wait(500)
    end
end)

---@param coords vector3
---@param range number
---@return number?
function M.nearest(coords, range)
    local best, bestDist
    for _, entity in ipairs(nearbyBarrows) do
        if DoesEntityExist(entity) then
            local d = #(GetEntityCoords(entity) - coords)
            if d <= range and (not bestDist or d < bestDist) then best, bestDist = entity, d end
        end
    end
    return best
end

---@param entity number
local function settle(entity)
    if not Attach.requestControl(entity, 1000) then return end
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
end

RegisterNetEvent('snowy_snow:placeBarrow', function(netId)
    local entity = lib.waitFor(function()
        if NetworkDoesNetworkIdExist(netId) then
            local e = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(e) then return e end
        end
    end, nil, 3000)
    if entity then settle(entity) end
end)

local function release()
    local entity = Status.holdingBarrow
    Status.holdingBarrow = nil
    Prompt.set('barrow', nil)
    StopAnimTask(cache.ped, anims.barrowDict, 'barrow_push', 2.0)
    StopAnimTask(cache.ped, anims.barrowDict, 'barrow_hold', 2.0)
    if not entity or not DoesEntityExist(entity) then return end
    DetachEntity(entity, true, false)
    settle(entity)
    lib.callback.await('snowy_snow:releaseBarrow', false, NetworkGetNetworkIdFromEntity(entity))
end

---@param entity number
local function grab(entity)
    local ok, reason = lib.callback.await('snowy_snow:grabBarrow', false, NetworkGetNetworkIdFromEntity(entity))
    if not ok then
        lib.notify({ title = 'Wheelbarrow', description = reason == 'shovel_out' and 'Put the shovel away first' or 'You can\'t take that one', type = 'error' })
        return
    end
    if not Attach.requestControl(entity, 1500) then
        lib.callback.await('snowy_snow:releaseBarrow', false, NetworkGetNetworkIdFromEntity(entity))
        return
    end
    lib.requestAnimDict(anims.barrowDict)
    FreezeEntityPosition(entity, false)
    Attach.toBone(entity, cache.ped, cfg.bone, cfg.offset, 2)
    Status.holdingBarrow = entity
    CreateThread(function()
        local loop = Carry.new(anims.barrowDict)
        while Status.holdingBarrow == entity do
            local ped = cache.ped
            if IsPedDeadOrDying(ped, true) or cache.vehicle or not DoesEntityExist(entity) then
                release()
                break
            end
            Carry.play(loop, ped, Carry.isMoving(loop, ped) and 'barrow_push' or 'barrow_hold')
            Wait(0)
        end
    end)
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = cache.ped
        if Status.holdingBarrow then
            sleep = 0
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Prompt.set('barrow', '[E] Let go')
            if IsControlJustReleased(0, keys.interact) then release() end
        else
            local shovel = LocalPlayer.state.snowyShovel
            local entity = (not shovel or not shovel.out) and M.nearest(GetEntityCoords(ped), cfg.interactRange) or nil
            local state = entity and barrowState(entity)
            if entity and state and (not state.holder or state.holder == cache.serverId) then
                sleep = 0
                local text = '[E] Push  [H] Pick up'
                if (state.snow or 0) > 0 then text = text .. ('  [G] Empty (%d/%d)'):format(state.snow, cfg.capacity) end
                Prompt.set('barrow', text)
                local netId = NetworkGetNetworkIdFromEntity(entity)
                if IsControlJustReleased(0, keys.interact) then
                    grab(entity)
                elseif IsControlJustReleased(0, keys.pickup) then
                    local ok, reason = lib.callback.await('snowy_snow:pickupBarrow', false, netId)
                    if not ok and reason == 'full' then
                        lib.notify({ title = 'Wheelbarrow', description = 'No room in your inventory', type = 'error' })
                    end
                elseif IsControlJustReleased(0, keys.dump) and (state.snow or 0) > 0 then
                    lib.callback.await('snowy_snow:emptyBarrow', false, netId)
                end
            else
                Prompt.set('barrow', nil)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Status.holdingBarrow and DoesEntityExist(Status.holdingBarrow) then DetachEntity(Status.holdingBarrow, true, false) end
    for _, visual in pairs(loads) do Attach.delete(visual.obj) end
end)

return M
