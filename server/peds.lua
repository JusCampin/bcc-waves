local Core = exports.vorp_core:GetCore()
---@type BCCWavesDebugLib
local DBG = BCCWavesDebug

-- Use global state exported by server/state.lua
local ActivePeds = rawget(_G, 'ActivePeds') or {}
local Missions = rawget(_G, 'Missions') or {}

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
    local owner = Missions and Missions[tostring(site)]
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
