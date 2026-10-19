---@type SnowZone[]?
local shownZones

RegisterNetEvent('snowy_snow:debugZones', function(zones)
    if shownZones then
        shownZones = nil
        return
    end
    shownZones = zones
    CreateThread(function()
        while shownZones do
            for _, zone in ipairs(shownZones) do
                local d = zone.radius * 2.0
                DrawMarker(1, zone.x, zone.y, zone.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 2.5,
                    120, 190, 255, 60, false, false, 2, false, nil, nil, false)
                DrawMarker(28, zone.x, zone.y, zone.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4,
                    255, 255, 255, 180, false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        end
    end)
end)
