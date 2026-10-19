local M = {}

---@param source number
---@param item string
---@return boolean
function M.hasItem(source, item)
    local count = exports.ox_inventory:GetItem(source, item, nil, true)
    return (count or 0) > 0
end

---@param source number
---@param item string
---@param count number
---@param metadata table?
---@param slot number?
---@return boolean
function M.removeItem(source, item, count, metadata, slot)
    return exports.ox_inventory:RemoveItem(source, item, count, metadata, slot) == true
end

---@param source number
---@param item string
---@param count number
---@param metadata table?
---@return boolean
function M.addItem(source, item, count, metadata)
    if not exports.ox_inventory:CanCarryItem(source, item, count, metadata) then return false end
    local ok = exports.ox_inventory:AddItem(source, item, count, metadata)
    return ok == true
end

---@param source number
---@param slot number
---@return table?
function M.getSlot(source, slot)
    return exports.ox_inventory:GetSlot(source, slot)
end

return M
