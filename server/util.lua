local M = {}

---@param source number
---@return boolean
function M.isPlayerLoaded(source)
    return type(source) == 'number' and source > 0 and GetPlayerName(source) ~= nil
end

---@param source number
---@return vector3
function M.playerCoords(source)
    return GetEntityCoords(GetPlayerPed(source))
end

---@param source number
---@param coords vector3
---@param maxDistance number
---@return boolean
function M.isNear2d(source, coords, maxDistance)
    local p = M.playerCoords(source)
    return #(vec2(p.x, p.y) - vec2(coords.x, coords.y)) <= maxDistance
end

---@type table<number, table<string, number>>
local lastAction = {}

---@param source number
---@param key string
---@param cooldownMs number
---@return boolean
function M.consumeCooldown(source, key, cooldownMs)
    local now = GetGameTimer()
    local bucket = lastAction[source]
    if not bucket then
        bucket = {}
        lastAction[source] = bucket
    end
    if (bucket[key] or 0) + cooldownMs > now then return false end
    bucket[key] = now
    return true
end

---@param source number
function M.clearPlayer(source)
    lastAction[source] = nil
end

return M
