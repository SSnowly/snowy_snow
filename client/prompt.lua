local M = {}

---@type table<string, string>
local entries = {}
local order = { 'barrow', 'shovel' }
local shown

local function refresh()
    local text
    for _, key in ipairs(order) do
        if entries[key] then text = entries[key] break end
    end
    if text == shown then return end
    shown = text
    if text then lib.showTextUI(text, { position = 'right-center' }) else lib.hideTextUI() end
end

---@param owner string
---@param text string?
function M.set(owner, text)
    entries[owner] = text
    refresh()
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if shown then lib.hideTextUI() end
end)

return M
