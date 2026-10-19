local M = {}

---@class AttachOffset
---@field pos vector3
---@field rot vector3

---@param model string
---@param coords vector3
---@return number
function M.createLocal(model, coords)
    local hash = joaat(model)
    lib.requestModel(hash)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

---@param obj number
---@param ped number
---@param boneId number
---@param off AttachOffset
---@param rotationOrder number
function M.toBone(obj, ped, boneId, off, rotationOrder)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, boneId),
        off.pos.x, off.pos.y, off.pos.z, off.rot.x, off.rot.y, off.rot.z,
        false, false, false, true, rotationOrder, true)
end

---@param obj number?
function M.delete(obj)
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
end

return M
