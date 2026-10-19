local M = {}

---@param x number
---@param y number
---@param zHint number
---@return vector3? hit, vector3 normal
local function probe(x, y, zHint)
    local handle = StartShapeTestLosProbe(x, y, zHint + 25.0, x, y, zHint - 40.0, 1, cache.ped, 7)
    local status, hit, coords, normal = 1, false, nil, nil
    local deadline = GetGameTimer() + 500
    while status == 1 and GetGameTimer() < deadline do
        status, hit, coords, normal = GetShapeTestResult(handle)
        if status == 1 then Wait(0) end
    end
    if hit == 1 or hit == true then return coords, normal end
    local found, groundZ = GetGroundZFor_3dCoord(x, y, zHint + 25.0, false)
    if found then return vec3(x, y, groundZ), vec3(0.0, 0.0, 1.0) end
    return nil, vec3(0.0, 0.0, 1.0)
end

---@param n vector3
---@param maxTiltDeg number
---@return vector3
local function clampTilt(n, maxTiltDeg)
    local len = #n
    if len < 1e-4 then return vec3(0.0, 0.0, 1.0) end
    n = n / len
    if n.z < 0 then n = -n end
    local maxTilt = math.rad(maxTiltDeg)
    if math.acos(math.min(1.0, n.z)) <= maxTilt then return n end
    local h = vec2(n.x, n.y)
    local hl = #h
    if hl < 1e-4 then return vec3(0.0, 0.0, 1.0) end
    h = h / hl * math.sin(maxTilt)
    return vec3(h.x, h.y, math.cos(maxTilt))
end

---@param a vector3
---@param b vector3
---@return vector3
local function cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

---@param right vector3
---@param forward vector3
---@param up vector3
---@return number, number, number, number
local function basisToQuat(right, forward, up)
    local m00, m01, m02 = right.x, forward.x, up.x
    local m10, m11, m12 = right.y, forward.y, up.y
    local m20, m21, m22 = right.z, forward.z, up.z
    local trace = m00 + m11 + m22
    if trace > 0 then
        local s = math.sqrt(trace + 1.0) * 2
        return (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25 * s
    elseif m00 > m11 and m00 > m22 then
        local s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        return 0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s
    elseif m11 > m22 then
        local s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        return (m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s
    end
    local s = math.sqrt(1.0 + m22 - m00 - m11) * 2
    return (m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s
end

---@class GroundPose
---@field coords vector3
---@field quat   number[]  x, y, z, w

---@param x number
---@param y number
---@param zHint number
---@param heading number
---@param maxTiltDeg number
---@param sink number
---@return GroundPose?
function M.pose(x, y, zHint, heading, maxTiltDeg, sink)
    local hit, normal = probe(x, y, zHint)
    if not hit then return nil end
    local up = clampTilt(normal, maxTiltDeg)
    local h = math.rad(heading)
    local fwd = vec3(-math.sin(h), math.cos(h), 0.0)
    fwd = fwd - up * (fwd.x * up.x + fwd.y * up.y + fwd.z * up.z)
    fwd = fwd / #fwd
    local right = cross(fwd, up)
    local qx, qy, qz, qw = basisToQuat(right, fwd, up)
    return { coords = hit - up * sink, quat = { qx, qy, qz, qw } }
end

---@param entity number
---@param pose GroundPose
function M.apply(entity, pose)
    SetEntityCoordsNoOffset(entity, pose.coords.x, pose.coords.y, pose.coords.z, false, false, false)
    SetEntityQuaternion(entity, pose.quat[1], pose.quat[2], pose.quat[3], pose.quat[4])
end

return M
