local Core = exports.vorp_core:GetCore()
---@type BCCWavesDebugLib
local DBG = BCCWavesDebug

local Cooldowns = {}

Core.Callback.Register('bcc-waves:CheckCooldown', function(source, cb, site)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return cb(false)
    end

    local id = tostring(site)
    DBG.Info('Checking cooldown for site: ' .. id)
    if Cooldowns[id] then
        local minutes = (Config.waveCooldown * 60)
        if os.difftime(os.time(), Cooldowns[id]) >= minutes then
            Cooldowns[id] = os.time()
            DBG.Info('Cooldown expired for site: ' .. id .. '. Allowing start.')
            return cb(true)
        end
        DBG.Warning('Cooldown active for site: ' .. id .. '. Denying start.')
        return cb(false)
    else
        Cooldowns[id] = os.time()
        DBG.Info('No existing cooldown for site: ' .. id .. '. Allowing start.')
        return cb(true)
    end
end)
