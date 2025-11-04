local Core = exports.vorp_core:GetCore()
---@type BCCWavesDebugLib
local DBG = BCCWavesDebug

-- Helper used by CheckJob callback
local function CheckPlayerJob(charJob, jobGrade, site)
    -- Validate site configuration exists
    local siteCfg = Sites[site]
    if not siteCfg or not siteCfg.shop or not siteCfg.shop.jobs then
        DBG.Error(string.format('Invalid site configuration for job check: %s', tostring(site)))
        return false
    end

    local jobs = siteCfg.shop.jobs
    for _, job in ipairs(jobs) do
        if charJob == job.name and jobGrade >= job.grade then
            return true
        end
    end
    return false
end

Core.Callback.Register('bcc-waves:CheckJob', function(source, cb, site)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error(string.format('User not found for source: %s', tostring(src)))
        return cb(false)
    end

    -- Validate site parameter
    if not site or type(site) ~= 'string' then
        DBG.Error(string.format('Invalid site parameter received from source: %d', src))
        return cb(false)
    end

    local character = user.getUsedCharacter
    local charJob = character.job
    local jobGrade = character.jobGrade

    DBG.Info(string.format('Checking job for user: charJob=%s, jobGrade=%s', charJob, jobGrade))

    if not charJob or not CheckPlayerJob(charJob, jobGrade, site) then
        DBG.Warning('User does not have the required job or grade.')
        Core.NotifyRightTip(src, _U('needJob'), 4000)
        return cb(false)
    end

    DBG.Success('User has the required job and grade.')
    return cb(true)
end)
