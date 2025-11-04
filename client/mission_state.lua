-- mission_state.lua: mission-wide state and cleanup
InMission = InMission or false
AreaBlip = AreaBlip or 0
CurrentMissionSite = CurrentMissionSite or nil
LootChest = LootChest or nil

function ResetWaves()
    InMission = false

    if AreaBlip and AreaBlip ~= 0 and DoesBlipExist(AreaBlip) then
        RemoveBlip(AreaBlip)
        AreaBlip = 0
    end

    local netIds = {}
    for pedIndex, ent in pairs(EnemyPeds) do
        if DoesEntityExist(ent) then
            local nid = NetworkGetNetworkIdFromEntity(ent)
            if nid and nid ~= 0 then
                table.insert(netIds, nid)
            end
        end
    end
    if #netIds > 0 then
        TriggerServerEvent('bcc-waves:DeletePed', netIds)
    end

    for pedIndex, _ in pairs(EnemyPeds) do
        CleanupEnemyPed(pedIndex)
    end

    for k, v in pairs(EnemyBlips) do
        if DoesBlipExist(v) then RemoveBlip(v) end
        EnemyBlips[k] = nil
    end

    -- clean up any loot chest spawned during LootHandler
    if LootChest and DoesEntityExist(LootChest) then
        DeleteEntity(LootChest)
        LootChest = nil
    end

    if CurrentMissionSite then
        TriggerServerEvent('bcc-waves:UnregisterMission', CurrentMissionSite)
        CurrentMissionSite = nil
    end
end

function EnsureMissionActive()
    if not InMission then
        ResetWaves()
        return false
    end
    return true
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    ResetWaves()

    for _, siteCfg in pairs(Sites) do
        if siteCfg.Blip then
            if DoesBlipExist(siteCfg.Blip) then
                RemoveBlip(siteCfg.Blip)
            end
        end
        siteCfg.Blip = nil
    end
end)
