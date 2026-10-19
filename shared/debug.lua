local SharedConfig = require 'configs.shared.main'

---@param ... any
function SnowyDebug(...)
    if not SharedConfig.debug then return end
    print(('[%s]'):format(GetCurrentResourceName()), ...)
end
