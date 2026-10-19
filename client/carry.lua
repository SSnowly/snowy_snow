local SharedConfig = require 'configs.shared.main'

local anims = SharedConfig.anims

---@class CarryLoop
---@field dict     string
---@field clip     string?
---@field playedAt number
---@field moving   boolean
---@field movedAt  number

local M = {}

---@param dict string
---@return CarryLoop
function M.new(dict)
    return { dict = dict, playedAt = 0, moving = false, movedAt = 0 }
end

---@param loop CarryLoop
---@param ped number
---@return boolean
function M.isMoving(loop, ped)
    local now = GetGameTimer()
    local moving = GetPedDesiredMoveBlendRatio(ped) > anims.moveRatio
    if moving ~= loop.moving and now - loop.movedAt >= anims.minSwitchMs then
        loop.moving, loop.movedAt = moving, now
    end
    return loop.moving
end

---@param loop CarryLoop
---@param ped number
---@param clip string
---@param blendIn number?
function M.play(loop, ped, clip, blendIn)
    local now = GetGameTimer()
    if clip == loop.clip and (now - loop.playedAt < anims.restartGraceMs or IsEntityPlayingAnim(ped, loop.dict, clip, 3)) then
        return
    end
    lib.requestAnimDict(loop.dict)
    TaskPlayAnim(ped, loop.dict, clip, blendIn or anims.loopBlend, anims.loopBlend, -1, anims.upperBodyLoopFlag, 0.0, false, false, false)
    loop.clip, loop.playedAt = clip, now
end

---@param loop CarryLoop
---@param ped number
---@param blendOut number
function M.stop(loop, ped, blendOut)
    if loop.clip and IsEntityPlayingAnim(ped, loop.dict, loop.clip, 3) then
        StopAnimTask(ped, loop.dict, loop.clip, blendOut)
    end
    loop.clip = nil
end

return M
