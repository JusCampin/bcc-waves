local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local Discord = BccUtils.Discord.setup(Config.Webhook.URL, Config.Webhook.Title, Config.Webhook.Avatar)
---@type BCCWavesDebugLib
local DBG = BCCWavesDebug

local Cooldowns = {}
local ActivePeds = {}
local Missions = {}

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

-- Check if a player can start a mission at the given site (based on cooldown)
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

Core.Callback.Register('bcc-waves:RewardPayout', function(source, cb, site)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return cb(false)
    end

    local character = user.getUsedCharacter

    -- Validate site parameter
    if not site or type(site) ~= 'string' then
        DBG.Warning('RewardPayout received invalid site from source: ' .. tostring(src))
        return cb(false)
    end

    -- Validate site configuration exists
    local siteCfg = Sites[site]
    if not siteCfg or not siteCfg.rewards then
        DBG.Warning('RewardPayout: no rewards configured for site: ' .. tostring(site))
        return cb(false)
    end

    -- helper: resolve numeric value from either a number or a {min,max} table
    local function resolveRange(val)
        if type(val) == 'table' then
            local min = tonumber(val.min) or tonumber(val[1]) or 0
            local max = tonumber(val.max) or tonumber(val[2]) or min
            if max < min then max = min end
            if min == max then return min end
            return math.random(min, max)
        elseif type(val) == 'number' then
            return val
        else
            return 0
        end
    end

    local cash = resolveRange(siteCfg.rewards.cash)
    local gold = resolveRange(siteCfg.rewards.gold)
    local rol = resolveRange(siteCfg.rewards.rol)

    -- Give currencies to the character
    if cash > 0 then character.addCurrency(0, cash) end
    if gold > 0 then character.addCurrency(1, gold) end
    if rol > 0 then character.addCurrency(2, rol) end

    Core.NotifyRightTip(source,
        _U('youTook') ..
        '$~o~' .. cash .. '~q~, ~o~' .. gold .. '~q~ ' .. 'gold' .. ', ~o~' .. rol .. '~q~ ' .. 'rol', 5000)

    Discord:sendMessage('Name: ' ..
        character.firstname .. ' ' .. character.lastname .. '\nIdentifier: ' .. character.identifier ..
        '\nReward: ' .. '$' .. tostring(cash) ..
        '\nReward: ' .. tostring(gold) .. ' gold' ..
        '\nReward: ' .. tostring(rol) .. ' rol')

    -- Give items to the character
    local items = siteCfg.rewards.items or {}
    for _, item in ipairs(items) do
        local name = item.itemName
        local quantity = item.quantity or 1
        local count = resolveRange(quantity)
        local label = item.label or name or 'item'
        if name then
            local canCarry = exports.vorp_inventory:canCarryItem(src, name, count)
            if canCarry then
                exports.vorp_inventory:addItem(src, name, count)
                Core.NotifyRightTip(src, _U('youTook') .. count .. ' ' .. label, 4000)

                Discord:sendMessage('Name: ' ..
                    character.firstname ..
                    ' ' ..
                    character.lastname ..
                    '\nIdentifier: ' .. character.identifier .. '\nReward: ' .. count .. ' ' .. name)
            else
                Core.NotifyRightTip(src, _U('noSpace'), 4000)
            end
        end
    end

    return cb(true)
end)

-- Handle ped deletion requests from clients
RegisterNetEvent('bcc-waves:DeletePed', function(netIds)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return
    end

    -- Validate netIds parameter
    if type(netIds) ~= 'table' then
        DBG.Warning("bcc-waves:DeletePed expected table of netIds, got: " .. tostring(netIds))
        return
    end

    for _, netId in ipairs(netIds) do
        if type(netId) ~= 'number' then
            DBG.Warning("bcc-waves:DeletePed received invalid netId: " .. tostring(netId))
        else
            local site = ActivePeds[netId]
            if not site then
                DBG.Warning("bcc-waves:DeletePed: netId not registered/active: " .. tostring(netId))
            else
                local entity = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                -- remove from active map after deletion
                ActivePeds[netId] = nil
            end
        end
    end
end)

-- Register npc peds for a mission site
RegisterNetEvent('bcc-waves:RegisterPeds', function(site, netIds)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return
    end

    -- Validate site parameter
    if type(site) ~= 'string' and type(site) ~= 'number' then
        DBG.Warning("bcc-waves:RegisterPeds expected site id and table of netIds, got site: " .. tostring(site))
        return
    end

    -- Validate netIds parameter
    if type(netIds) ~= 'table' then
        DBG.Warning("bcc-waves:RegisterPeds expected table of netIds, got: " .. tostring(netIds))
        return
    end

    -- Only the mission owner may register peds for this site
    local owner = Missions[tostring(site)]
    if owner ~= src then
        DBG.Warning(string.format("bcc-waves:RegisterPeds rejected: source %s is not owner of site %s (owner=%s)", tostring(src), tostring(site), tostring(owner)))
        return
    end

    for _, netId in ipairs(netIds) do
        if type(netId) == 'number' then
            ActivePeds[netId] = tostring(site)
        else
            DBG.Warning("bcc-waves:RegisterPeds received invalid netId: " .. tostring(netId))
        end
    end
end)

-- Register a mission site to a player source
RegisterNetEvent('bcc-waves:RegisterMission', function(site)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return
    end

    -- Validate site parameter
    if not site then
        DBG.Error('No site provided for mission registration')
        return
    end

    Missions[tostring(site)] = src
    DBG.Info(string.format("Registered mission site %s to source %s", tostring(site), tostring(src)))
end)

-- Unregister a mission site after completion or cancellation
RegisterNetEvent('bcc-waves:UnregisterMission', function(site)
    local src = source
    local user = Core.getUser(src)

    -- Validate user exists
    if not user then
        DBG.Error('User not found for source: ' .. tostring(src))
        return
    end

    -- Validate site parameter
    if not site then
        DBG.Error('No site provided for mission unregistration')
        return
    end

    -- only owner can unregister (or if owner disconnected, server cleanup will be automatic)
    if Missions[tostring(site)] ~= src then
        DBG.Warning(string.format("bcc-waves:UnregisterMission: source %s attempted to unregister site %s but owner is %s", tostring(src), tostring(site), tostring(Missions[tostring(site)])))
        return
    end

    -- attempt to delete any active ped entities associated with this site
    for netId, s in pairs(ActivePeds) do
        if s == tostring(site) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity and DoesEntityExist(entity) then
                DBG.Info(string.format("UnregisterMission: deleting entity for netId %s (site=%s)", tostring(netId), tostring(site)))
                -- try to delete the entity server-side
                DeleteEntity(entity)
            end
            -- remove from active map after attempting deletion
            ActivePeds[netId] = nil
        end
    end

    Missions[tostring(site)] = nil
    DBG.Info(string.format("Unregistered mission site %s (by %s) and cleaned %d peds", tostring(site), tostring(src), tostring(#(ActivePeds) or 0)))
end)

-- When a player disconnects, automatically unregister any missions they owned and cleanup associated peds
AddEventHandler('playerDropped', function(reason)
    local src = source
    DBG.Info(string.format("playerDropped: source %s disconnected (%s). Cleaning missions.", tostring(src), tostring(reason)))

    local removed = {}
    for site, owner in pairs(Missions) do
        if owner == src then
            Missions[site] = nil
            table.insert(removed, site)
        end
    end

    if #removed > 0 then
        -- attempt to delete entities for all ActivePeds that belonged to removed sites
        for netId, s in pairs(ActivePeds) do
            for _, site in ipairs(removed) do
                if s == tostring(site) then
                    local entity = NetworkGetEntityFromNetworkId(netId)
                    if entity and DoesEntityExist(entity) then
                        DBG.Info(string.format("playerDropped: deleting entity for netId %s (site=%s)", tostring(netId), tostring(site)))
                        DeleteEntity(entity)
                    end
                    ActivePeds[netId] = nil
                    break
                end
            end
        end
        DBG.Info(string.format("Cleaned up missions for disconnected source %s: %s", tostring(src), table.concat(removed, ", ")))
    end
end)
