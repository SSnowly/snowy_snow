local SharedConfig = require 'configs.shared.main'
local Attach = require 'client.attach'
local Carry = require 'client.carry'
local Prompt = require 'client.prompt'
local Status = require 'client.status'

local cfg = SharedConfig.barrow
local anims = SharedConfig.anims
local keys = SharedConfig.keys

local M = {}

---@class BarrowVisual
---@field data       SnowBarrowData
---@field obj        number?
---@field load       number?
---@field loadModel  string?
---@field attachedTo number?
---@field placed     boolean
---@field busy       boolean?
---@field again      boolean?
---@field releasing  boolean?

---@type table<number, BarrowVisual>
local visuals = {}

---@param snow number
---@return string?
local function stageModel(snow)
    local model
    for _, stage in ipairs(cfg.stages) do
        if snow >= stage.min then model = stage.model end
    end
    return model
end

---@param holder number?
---@return number?
local function holderPed(holder)
    if not holder then return nil end
    if holder == cache.serverId then return cache.ped end
    local player = GetPlayerFromServerId(holder)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

---@param visual BarrowVisual
local function despawn(visual)
    Attach.delete(visual.load)
    Attach.delete(visual.obj)
    visual.obj, visual.load, visual.loadModel, visual.attachedTo, visual.placed = nil, nil, nil, nil, false
end

---@param visual BarrowVisual
local function place(visual)
    local data, obj = visual.data, visual.obj
    if visual.attachedTo then DetachEntity(obj, true, false) end
    FreezeEntityPosition(obj, false)
    SetEntityCoordsNoOffset(obj, data.x, data.y, data.z, false, false, false)
    SetEntityHeading(obj, data.heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    visual.attachedTo, visual.placed = nil, true
end

---@param visual BarrowVisual
local function syncLoad(visual)
    local want = stageModel(visual.data.snow or 0)
    if visual.loadModel == want and (not want or DoesEntityExist(visual.load)) then return end
    Attach.delete(visual.load)
    visual.load, visual.loadModel = nil, want
    if not want then return end
    visual.load = Attach.createLocal(want, GetEntityCoords(visual.obj))
    AttachEntityToEntity(visual.load, visual.obj, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
end

---@param visual BarrowVisual
local function build(visual)
    local data = visual.data
    local anchor
    if data.holder then
        local ped = holderPed(data.holder)
        anchor = ped and GetEntityCoords(ped)
    else
        anchor = vec3(data.x, data.y, data.z)
    end
    if not anchor or #(anchor - GetEntityCoords(cache.ped)) > cfg.renderDistance then
        despawn(visual)
        return
    end
    if not visual.obj or not DoesEntityExist(visual.obj) then
        despawn(visual)
        visual.obj = lib.prop.create(cfg.model, anchor.x, anchor.y, anchor.z).handle
    end
    local ped = holderPed(data.holder)
    if ped then
        if visual.attachedTo ~= ped then
            FreezeEntityPosition(visual.obj, false)
            Attach.toBone(visual.obj, ped, cfg.bone, cfg.offset, 2)
            visual.attachedTo, visual.placed = ped, false
        end
    elseif not data.holder and not visual.placed then
        place(visual)
    end
    syncLoad(visual)
end

---@param visual BarrowVisual
local function refresh(visual)
    if visual.busy then
        visual.again = true
        return
    end
    visual.busy = true
    repeat
        visual.again = false
        build(visual)
    until not visual.again
    visual.busy = false
    if visuals[visual.data.id] ~= visual then despawn(visual) end
end

---@param data SnowBarrowData
local function addBarrow(data)
    if visuals[data.id] then return end
    local visual = { data = data, placed = false }
    visuals[data.id] = visual
    CreateThread(function() refresh(visual) end)
end

RegisterNetEvent('snowy_snow:barrowAdded', addBarrow)

RegisterNetEvent('snowy_snow:barrowRemoved', function(id)
    local visual = visuals[id]
    if not visual then return end
    visuals[id] = nil
    if not visual.busy then despawn(visual) end
end)

RegisterNetEvent('snowy_snow:barrowUpdated', function(data)
    local visual = visuals[data.id]
    if not visual then return addBarrow(data) end
    local old = visual.data
    if visual.releasing then
        old.snow = data.snow
    else
        if old.x ~= data.x or old.y ~= data.y or old.z ~= data.z or old.heading ~= data.heading then
            visual.placed = false
        end
        visual.data = data
    end
    CreateThread(function() refresh(visual) end)
end)

CreateThread(function()
    local list = lib.callback.await('snowy_snow:getBarrows', false) or {}
    for _, data in ipairs(list) do addBarrow(data) end
    while true do
        for _, visual in pairs(visuals) do refresh(visual) end
        Wait(500)
    end
end)

---@param coords vector3
---@param range number
---@return number? id, vector3? coords
function M.nearest(coords, range)
    local best, bestDist, bestPos
    for id, visual in pairs(visuals) do
        if visual.obj and DoesEntityExist(visual.obj) then
            local pos = GetEntityCoords(visual.obj)
            local d = #(pos - coords)
            if d <= range and (not bestDist or d < bestDist) then best, bestDist, bestPos = id, d, pos end
        end
    end
    return best, bestPos
end

local function release()
    local id = Status.holdingBarrow
    Status.holdingBarrow = nil
    Prompt.set('barrow', nil)
    StopAnimTask(cache.ped, anims.barrowDict, 'barrow_push', 2.0)
    StopAnimTask(cache.ped, anims.barrowDict, 'barrow_hold', 2.0)
    local visual = id and visuals[id]
    if not visual then return end
    local data = visual.data
    data.holder = nil
    if visual.obj and DoesEntityExist(visual.obj) then
        DetachEntity(visual.obj, true, false)
        PlaceObjectOnGroundProperly(visual.obj)
        FreezeEntityPosition(visual.obj, true)
        visual.attachedTo, visual.placed = nil, true
        local c = GetEntityCoords(visual.obj)
        data.x, data.y, data.z, data.heading = c.x, c.y, c.z, GetEntityHeading(visual.obj)
    end
    visual.releasing = true
    lib.callback.await('snowy_snow:releaseBarrow', false, id, data.x, data.y, data.z, data.heading)
    visual.releasing = nil
end

---@param id number
local function grab(id)
    local ok, reason = lib.callback.await('snowy_snow:grabBarrow', false, id)
    local visual = visuals[id]
    if not ok or not visual then
        if ok then lib.callback.await('snowy_snow:releaseBarrow', false, id) end
        lib.notify({ title = 'Wheelbarrow', description = reason == 'shovel_out' and 'Put the shovel away first' or 'You can\'t take that one', type = 'error' })
        return
    end
    lib.requestAnimDict(anims.barrowDict)
    visual.data.holder = cache.serverId
    Status.holdingBarrow = id
    refresh(visual)
    CreateThread(function()
        local loop = Carry.new(anims.barrowDict)
        while Status.holdingBarrow == id do
            local ped = cache.ped
            if IsPedDeadOrDying(ped, true) or cache.vehicle or not visuals[id] then
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
            local id = (not shovel or not shovel.out) and M.nearest(GetEntityCoords(ped), cfg.interactRange) or nil
            local data = id and visuals[id].data
            if data and (not data.holder or data.holder == cache.serverId) then
                sleep = 0
                local snow = data.snow or 0
                local text = '[E] Push  [H] Pick up'
                if snow > 0 then text = text .. ('  [G] Empty (%d/%d)'):format(snow, cfg.capacity) end
                Prompt.set('barrow', text)
                if IsControlJustReleased(0, keys.interact) then
                    grab(id)
                elseif IsControlJustReleased(0, keys.pickup) then
                    local ok, reason = lib.callback.await('snowy_snow:pickupBarrow', false, id)
                    if not ok and reason == 'full' then
                        lib.notify({ title = 'Wheelbarrow', description = 'No room in your inventory', type = 'error' })
                    end
                elseif IsControlJustReleased(0, keys.dump) and snow > 0 then
                    lib.callback.await('snowy_snow:emptyBarrow', false, id)
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
    for _, visual in pairs(visuals) do despawn(visual) end
end)

return M
