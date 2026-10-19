local SharedConfig = require 'configs.shared.main'
local Attach = require 'client.attach'
local Barrow = require 'client.barrow'
local Carry = require 'client.carry'
local Piles = require 'client.piles'
local Prompt = require 'client.prompt'
local Status = require 'client.status'

local cfg = SharedConfig.shovel
local anims = SharedConfig.anims
local keys = SharedConfig.keys
local NO_SHIFT = vec3(0.0, 0.0, 0.0)

---@alias ShovelGrip 'unloaded'|'loaded'|'leftHand'

---@class ShovelVisual
---@field ped        number
---@field shovel     number
---@field load       number?
---@field state      table
---@field grip       ShovelGrip?
---@field shift      vector3
---@field shiftFrom  vector3
---@field shiftTo    vector3
---@field shiftStart number
---@field workStart  number?
---@field dirty      boolean

---@type table<number, ShovelVisual>
local visuals = {}

---@param visual ShovelVisual
local function dropVisual(visual)
    Attach.delete(visual.shovel)
    Attach.delete(visual.load)
end

---@param visual ShovelVisual
---@param grip ShovelGrip
---@param shift vector3
local function attach(visual, grip, shift)
    local off = cfg.offsets[grip]
    local placed = { pos = off.pos + shift, rot = off.rot }
    local bone = grip == 'leftHand' and cfg.leftBone or cfg.bone
    Attach.toBone(visual.shovel, visual.ped, bone, placed, cfg.rotationOrder)
    if visual.load then Attach.toBone(visual.load, visual.ped, bone, placed, cfg.rotationOrder) end
end

---@param visual ShovelVisual
---@param now number
---@return ShovelGrip
local function gripFor(visual, now)
    for _, work in ipairs(cfg.work) do
        if IsEntityPlayingAnim(visual.ped, anims.shovelDict, work.clip, 3) then
            local frame = GetEntityAnimCurrentTime(visual.ped, anims.shovelDict, work.clip) * work.frames
            if frame < work.toLeft then return work.before end
            if frame < work.toRight then return 'leftHand' end
            return work.after
        end
    end
    local state = visual.state
    local elapsed = visual.workStart and now - visual.workStart or 0
    if state.scooping then return elapsed < cfg.scoopMs * 0.5 and 'unloaded' or 'loaded' end
    if state.dumping then return elapsed < cfg.dumpMs * 0.5 and 'loaded' or 'unloaded' end
    return state.loaded and 'loaded' or 'unloaded'
end

---@param visual ShovelVisual
---@param now number
local function updateAttach(visual, now)
    local grip = gripFor(visual, now)
    local walkClip = grip == 'loaded' and 'shovel_walk_loaded' or 'shovel_walk'
    local walking = grip ~= 'leftHand' and IsEntityPlayingAnim(visual.ped, anims.shovelDict, walkClip, 3)
    local shiftTo = walking and cfg.walkShift[grip] or NO_SHIFT
    if grip ~= visual.grip then
        visual.shiftFrom, visual.shiftTo, visual.shiftStart = shiftTo, shiftTo, now
    elseif shiftTo ~= visual.shiftTo then
        visual.shiftFrom, visual.shiftTo, visual.shiftStart = visual.shift, shiftTo, now
    end
    local t = (now - visual.shiftStart) / cfg.walkBlendMs
    local shift = t >= 1.0 and visual.shiftTo or visual.shiftFrom + (visual.shiftTo - visual.shiftFrom) * t
    if visual.dirty or grip ~= visual.grip or shift ~= visual.shift then
        attach(visual, grip, shift)
        visual.grip, visual.shift, visual.dirty = grip, shift, false
    end
end

---@param serverId number
---@param ped number
local function syncVisual(serverId, ped)
    local state = Player(serverId).state.snowyShovel
    local visual = visuals[serverId]
    if not state or not state.out or not DoesEntityExist(ped) then
        if visual then dropVisual(visual) end
        visuals[serverId] = nil
        return
    end
    if not visual or visual.ped ~= ped or not DoesEntityExist(visual.shovel) then
        if visual then dropVisual(visual) end
        visual = {
            ped = ped,
            shovel = Attach.createLocal(cfg.model, GetEntityCoords(ped)),
            state = state,
            shift = NO_SHIFT, shiftFrom = NO_SHIFT, shiftTo = NO_SHIFT, shiftStart = 0,
            dirty = true,
        }
        visuals[serverId] = visual
    end
    visual.state = state
    local now = GetGameTimer()
    if state.scooping or state.dumping then
        visual.workStart = visual.workStart or now
    else
        visual.workStart = nil
    end
    local tipped = state.dumping and visual.workStart ~= nil and now - visual.workStart >= cfg.tipAtMs
    local wantLoad = state.loaded and not state.scooping and not tipped
    if wantLoad and not visual.load then
        visual.load = Attach.createLocal(cfg.loadModel, GetEntityCoords(ped))
        visual.dirty = true
    elseif not wantLoad and visual.load then
        Attach.delete(visual.load)
        visual.load = nil
    end
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local present = {}
        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            if #(GetEntityCoords(ped) - me) < 100.0 then
                local serverId = GetPlayerServerId(player)
                present[serverId] = true
                syncVisual(serverId, ped)
            end
        end
        for serverId, visual in pairs(visuals) do
            if not present[serverId] then
                dropVisual(visual)
                visuals[serverId] = nil
            end
        end
        Wait(250)
    end
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        for _, visual in pairs(visuals) do
            if DoesEntityExist(visual.shovel) and DoesEntityExist(visual.ped) then updateAttach(visual, now) end
        end
        Wait(next(visuals) and 0 or 250)
    end
end)

---@return table?
local function myState()
    return LocalPlayer.state.snowyShovel
end

local carry = Carry.new(anims.shovelDict)

---@param clip string
---@param blendIn number?
local function playCarry(clip, blendIn)
    Carry.play(carry, cache.ped, clip, blendIn)
end

---@param blendOut number
local function stopCarryAnims(blendOut)
    for _, clip in ipairs({ 'shovel_hold', 'shovel_walk', 'shovel_hold_loaded', 'shovel_walk_loaded' }) do
        if IsEntityPlayingAnim(cache.ped, anims.shovelDict, clip, 3) then StopAnimTask(cache.ped, anims.shovelDict, clip, blendOut) end
    end
    carry.clip = nil
end

CreateThread(function()
    while true do
        local sleep = 250
        local state = myState()
        if state and state.out and not Status.scooping and not Status.dumping and not Status.holdingBarrow then
            sleep = 0
            local moving = Carry.isMoving(carry, cache.ped)
            local clip = state.loaded and (moving and 'shovel_walk_loaded' or 'shovel_hold_loaded')
                or (moving and 'shovel_walk' or 'shovel_hold')
            playCarry(clip)
        elseif carry.clip and not Status.scooping and not Status.dumping then
            stopCarryAnims(2.0)
        end
        Wait(sleep)
    end
end)

---@param ms number
---@param lockMovement boolean
local function lockControls(ms, lockMovement)
    local done = GetGameTimer() + ms
    while GetGameTimer() < done do
        if lockMovement then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
        end
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 24, true)
        Wait(0)
    end
end

---@param ped number
---@param heading number
local function turnTo(ped, heading)
    TaskAchieveHeading(ped, heading, cfg.turnMs)
    local deadline = GetGameTimer() + cfg.turnMs
    while GetGameTimer() < deadline and math.abs((GetEntityHeading(ped) - heading + 180.0) % 360.0 - 180.0) > 4.0 do
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        Wait(0)
    end
end

---@param ped number
---@param target vector3
---@param sideDeg number
local function faceWork(ped, target, sideDeg)
    local me = GetEntityCoords(ped)
    turnTo(ped, (GetHeadingFromVector_2d(target.x - me.x, target.y - me.y) - sideDeg) % 360.0)
end

---@param pile SnowPile
local function scoop(pile)
    local ped = cache.ped
    Status.scooping = true
    Prompt.set('shovel', nil)
    turnTo(ped, (GetEntityHeading(ped) + cfg.scoopTurnDeg) % 360.0)
    local heading = GetEntityHeading(ped)
    if not lib.callback.await('snowy_snow:scoop', false, pile.id) then
        Status.scooping = false
        return
    end
    SetEntityHeading(ped, (heading + cfg.scoopAnimTurnDeg) % 360.0)
    stopCarryAnims(4.0)
    lib.requestAnimDict(anims.shovelDict)
    TaskPlayAnim(ped, anims.shovelDict, 'shovel_scoop', 4.0, 4.0, -1, anims.holdLastFrameFlag, 0.0, false, false, false)
    lockControls(cfg.scoopMs, true)
    playCarry('shovel_hold_loaded', 8.0)
    StopAnimTask(ped, anims.shovelDict, 'shovel_scoop', 2.0)
    SetEntityHeading(ped, heading)
    Status.scooping = false
end

---@param barrow number?
local function dump(barrow)
    local ped = cache.ped
    Status.dumping = true
    Prompt.set('shovel', nil)
    if barrow then
        faceWork(ped, GetEntityCoords(barrow), cfg.dumpSideDeg)
    end
    local ok, reason
    if barrow then
        ok, reason = lib.callback.await('snowy_snow:dumpIntoBarrow', false, NetworkGetNetworkIdFromEntity(barrow))
    else
        ok = lib.callback.await('snowy_snow:dumpShovel', false)
    end
    if not ok then
        Status.dumping = false
        if reason == 'full' then
            lib.notify({ title = 'Wheelbarrow', description = 'The wheelbarrow is full', type = 'error' })
        end
        return
    end
    stopCarryAnims(4.0)
    lib.requestAnimDict(anims.shovelDict)
    TaskPlayAnim(ped, anims.shovelDict, 'shovel_dump', 4.0, 4.0, -1, anims.upperBodyOnceFlag + anims.holdLastFrameFlag, 0.0, false, false, false)
    lockControls(cfg.dumpMs, false)
    playCarry('shovel_hold', 8.0)
    StopAnimTask(ped, anims.shovelDict, 'shovel_dump', 2.0)
    Status.dumping = false
end

CreateThread(function()
    while true do
        local sleep = 500
        local state = myState()
        if state and state.out and not Status.scooping and not Status.dumping and not Status.holdingBarrow then
            sleep = 0
            local me = GetEntityCoords(cache.ped)
            if not state.loaded then
                local pile = Piles.nearest(me, SharedConfig.piles.scoopDistance)
                if pile then
                    Prompt.set('shovel', '[E] Scoop snow')
                    if IsControlJustReleased(0, keys.interact) then scoop(pile) end
                else
                    Prompt.set('shovel', nil)
                end
            else
                local barrow = Barrow.nearest(me, SharedConfig.barrow.interactRange)
                Prompt.set('shovel', barrow and '[E] Into wheelbarrow  [G] Dump snow' or '[G] Dump snow')
                if barrow and IsControlJustReleased(0, keys.interact) then
                    dump(barrow)
                elseif IsControlJustReleased(0, keys.dump) then
                    dump(nil)
                end
            end
        else
            Prompt.set('shovel', nil)
        end
        Wait(sleep)
    end
end)

exports('toggleShovel', function()
    local state = myState()
    if Status.holdingBarrow then
        lib.notify({ title = 'Shovel', description = 'Let go of the wheelbarrow first', type = 'error' })
        return
    end
    if Status.scooping or Status.dumping then return end
    local wantOut = not (state and state.out)
    lib.callback.await('snowy_snow:setShovelOut', false, wantOut)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, visual in pairs(visuals) do dropVisual(visual) end
    stopCarryAnims(2.0)
end)
