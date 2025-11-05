function EnsureMissionActive()
    if not InMission then
        ResetWaves()
        return false
    end
    return true
end

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 1000

        for _, siteCfg in pairs(Sites) do
            local distance = #(playerCoords - siteCfg.shop.coords)
            if distance <= siteCfg.shop.markerDistance then
                sleep = 0
                Citizen.InvokeNative(0x2A32FAA57B937173, siteCfg.shop.markerHash, siteCfg.shop.coords.x,
                    siteCfg.shop.coords.y, siteCfg.shop.coords.z - 0.9,
                    0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 255, 0, 250, false, false, 2, false, false) -- DrawMarker
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('bcc-waves:MissionHandler', function(site, siteCfg)
    local dict = "menu_textures"
    LoadTextureDict(dict)
    Core.NotifyLeft(_U('missionStart'), "", dict, "menu_icon_alert", 4000, "COLOR_RED")

    CurrentMissionSite = site
    TriggerServerEvent('bcc-waves:RegisterMission', site)

    -- Validate required per-site settings
    if not siteCfg.areaBlip.radius then
        DBG.Error(string.format('Site %s missing required config: areaBlip.radius', tostring(site)))
        InMission = false
        return
    end

    if not siteCfg.enemyWaves then
        DBG.Error(string.format('Site %s missing required config: enemyWaves', tostring(site)))
        InMission = false
        return
    end

    AreaBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, siteCfg.shop.coords.x, siteCfg.shop.coords.y,
        siteCfg.shop.coords.z, siteCfg.areaBlip.radius) -- BlipAddForRadius
    local blipStyle = siteCfg.areaBlip.style or 'BLIP_STYLE_ENEMY'
    BlipAddModifier(AreaBlip, joaat(blipStyle))
    SetBlipName(AreaBlip, siteCfg.blip.name)

    TriggerEvent('bcc-waves:EnemyPeds', site, siteCfg)

    while InMission do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local distance = #(playerCoords - siteCfg.shop.coords)
        if distance > siteCfg.areaBlip.radius then
            DBG.Info("Player left the mission area")
            -- Notify player that they left the area, then show the generic failure message
            local textureDict = "menu_textures"
            LoadTextureDict(textureDict)
            Core.NotifyLeft(_U('leftArea') or 'You left the mission area', "", textureDict, "menu_icon_alert", 3000, "COLOR_WHITE")
            Wait(800)
            Core.NotifyLeft(_U('missionFailed') or 'Mission Failed', "", dict, "menu_icon_alert", 4000, "COLOR_WHITE")
            InMission = false
            ResetWaves()
            return
        end

        Wait(0)
    end
end)

-- Remote mission blip handling (centralized watcher + remote enemy blips)
local RemoteAreaBlips = {}      -- siteKey -> blip handle
local RemoteMissionActive = {}  -- siteKey -> boolean
local RemoteSitePeds = {}       -- siteKey -> { netId, ... }
local RemoteEnemyBlips = {}     -- netId -> blip handle

-- safety cap: maximum remote enemy blips to show per client at once
local MAX_REMOTE_ENEMY_BLIPS = 20

local function getSiteCfg(site)
    return Sites and (Sites[site] or Sites[tostring(site)])
end

-- Server events simply toggle the active flag for the site. The centralized
-- watcher will create/remove local blips based on player distance.
RegisterNetEvent('bcc-waves:MissionStarted', function(site)
    RemoteMissionActive[tostring(site)] = true
end)

RegisterNetEvent('bcc-waves:MissionEnded', function(site)
    RemoteMissionActive[tostring(site)] = false
    -- immediate cleanup if a blip exists
    local key = tostring(site)
    if RemoteAreaBlips[key] and DoesBlipExist(RemoteAreaBlips[key]) then
        RemoveBlip(RemoteAreaBlips[key])
        RemoteAreaBlips[key] = nil
    end
    -- remove any enemy blips belonging to this site
    local netList = RemoteSitePeds[key] or {}
    for _, nid in ipairs(netList) do
        if RemoteEnemyBlips[nid] and DoesBlipExist(RemoteEnemyBlips[nid]) then
            RemoveBlip(RemoteEnemyBlips[nid])
            RemoteEnemyBlips[nid] = nil
        end
    end
    RemoteSitePeds[key] = nil
end)

-- Remote peds registration handlers: server tells clients which netIds belong to a site
RegisterNetEvent('bcc-waves:RemotePedsRegistered', function(site, netIds)
    if not site then return end
    RemoteSitePeds[tostring(site)] = netIds or {}
end)

RegisterNetEvent('bcc-waves:RemotePedsRemoved', function(site, netIds)
    local key = tostring(site)
    if not netIds or #netIds == 0 then
        -- clear all for site
        RemoteSitePeds[key] = nil
    else
        local existing = RemoteSitePeds[key]
        if existing then
            -- remove specific netIds from the list
            local keep = {}
            local removeMap = {}
            for _, nid in ipairs(netIds) do removeMap[nid] = true end
            for _, nid in ipairs(existing) do
                if not removeMap[nid] then table.insert(keep, nid) end
            end
            RemoteSitePeds[key] = keep
        end
    end

    -- remove any local enemy blips tied to these netIds
    for _, nid in ipairs(netIds or {}) do
        if RemoteEnemyBlips[nid] and DoesBlipExist(RemoteEnemyBlips[nid]) then
            RemoveBlip(RemoteEnemyBlips[nid])
            RemoteEnemyBlips[nid] = nil
        end
    end
end)

-- Central watcher: checks all active remote missions once per second and
-- creates/removes blips based on the configured hint radius.
CreateThread(function()
    while true do
        for siteKey, active in pairs(RemoteMissionActive) do
            if not active then
                -- ensure cleanup
                if RemoteAreaBlips[siteKey] and DoesBlipExist(RemoteAreaBlips[siteKey]) then
                    RemoveBlip(RemoteAreaBlips[siteKey])
                    RemoteAreaBlips[siteKey] = nil
                end
                -- clean enemy blips too
                local netList = RemoteSitePeds[siteKey] or {}
                for _, nid in ipairs(netList) do
                    if RemoteEnemyBlips[nid] and DoesBlipExist(RemoteEnemyBlips[nid]) then
                        RemoveBlip(RemoteEnemyBlips[nid])
                        RemoteEnemyBlips[nid] = nil
                    end
                end
                goto CONTINUE
            end

            local siteCfg = getSiteCfg(siteKey)
            if not siteCfg or not siteCfg.areaBlip or not siteCfg.areaBlip.radius then
                goto CONTINUE
            end

            -- Don't show remote blip on the mission owner's client (owner already
            -- creates a proper AreaBlip in MissionHandler).
            if InMission and tostring(CurrentMissionSite) == tostring(siteKey) then
                if RemoteAreaBlips[siteKey] and DoesBlipExist(RemoteAreaBlips[siteKey]) then
                    RemoveBlip(RemoteAreaBlips[siteKey])
                    RemoteAreaBlips[siteKey] = nil
                end
                goto CONTINUE
            end

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - siteCfg.shop.coords)

            local hint = (Config and Config.RemoteBlip and Config.RemoteBlip.hintRadius) or 50
            local showRadius = (siteCfg.areaBlip.radius or 0) + hint

            if distance <= showRadius then
                if not RemoteAreaBlips[siteKey] or not DoesBlipExist(RemoteAreaBlips[siteKey]) then
                    local b = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, siteCfg.shop.coords.x,
                        siteCfg.shop.coords.y, siteCfg.shop.coords.z, siteCfg.areaBlip.radius) -- BlipAddForRadius

                    -- prefer the configured remote color; fall back to site style
                    local colorKey = (Config and Config.RemoteBlip and Config.RemoteBlip.color) or 'LIGHT_YELLOW'
                    if Config and Config.BlipColors and Config.BlipColors[colorKey] then
                        Citizen.InvokeNative(0x662D364ABF16DE2F, b, joaat(Config.BlipColors[colorKey])) -- BlipAddModifier
                    else
                        local blipStyle = siteCfg.areaBlip.style or 'BLIP_STYLE_ENEMY'
                        BlipAddModifier(b, joaat(blipStyle))
                    end
                    SetBlipName(b, siteCfg.blip.name)
                    RemoteAreaBlips[siteKey] = b
                end
                -- create local enemy blips for remote peds (owner keeps entity control)
                local netList = RemoteSitePeds[siteKey] or {}
                local created = 0
                for _, nid in ipairs(netList) do
                    if created >= MAX_REMOTE_ENEMY_BLIPS then break end
                    if not RemoteEnemyBlips[nid] then
                        local ent = NetworkGetEntityFromNetworkId(nid)
                        if ent and DoesEntityExist(ent) and not IsEntityDead(ent) then
                            local sprite = (siteCfg.bandits and siteCfg.bandits.blipSprite) or 1
                            RemoteEnemyBlips[nid] = Citizen.InvokeNative(0x23F74C2FDA6E7C61, sprite, ent)
                            created = created + 1
                        end
                    else
                        created = created + 1
                    end
                end
            else
                if RemoteAreaBlips[siteKey] and DoesBlipExist(RemoteAreaBlips[siteKey]) then
                    RemoveBlip(RemoteAreaBlips[siteKey])
                    RemoteAreaBlips[siteKey] = nil
                end
                -- remove any enemy blips for this site when leaving show radius
                local netList = RemoteSitePeds[siteKey] or {}
                for _, nid in ipairs(netList) do
                    if RemoteEnemyBlips[nid] and DoesBlipExist(RemoteEnemyBlips[nid]) then
                        RemoveBlip(RemoteEnemyBlips[nid])
                        RemoteEnemyBlips[nid] = nil
                    end
                end
            end

            ::CONTINUE::
        end
        Wait(1000)
    end
end)

-- Enemy peds handler
AddEventHandler('bcc-waves:EnemyPeds', function(site, siteCfg)
    if not EnsureMissionActive() then return end

    local markerCoords = siteCfg.shop.coords
    local waves = siteCfg.enemyWaves
    if not waves then
        DBG.Error(string.format('Site %s missing enemyWaves configuration', tostring(site)))
        InMission = false
        return
    end

    local totalEnemiesNeeded = 0
    for _, waveSize in ipairs(waves) do
        totalEnemiesNeeded = totalEnemiesNeeded + waveSize
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local NpcCoords = GenerateNpcCoords(markerCoords, playerCoords, totalEnemiesNeeded, siteCfg.areaBlip.radius)

    local model = siteCfg.bandits.model
    local hash = joaat(model)
    local currentWave = 1
    local totalEnemies = 0
    local wavePeds = {}

    LoadModel(hash, model)

    local ctx = {
        site = site,
        siteCfg = siteCfg,
        waves = waves,
        npcCoords = NpcCoords,
        hash = hash,
        totalEnemies = totalEnemies,
        wavePeds = wavePeds,
    }

    local delay = Config.FirstWaveDelay * 1000
    while delay > 0 do
        Wait(1000)
        delay = delay - 1000
        if not EnsureMissionActive() then return end
    end

    local function StartWaveLoop(startWave)
        CreateThread(function()
            local current = startWave

            while current <= #ctx.waves do
                -- wait for previous wave to be cleared
                local waveTimeoutMin = (siteCfg.mission and siteCfg.mission.waveTimeoutMin) or 3
                local waveTimeout = waveTimeoutMin * 60000
                local waveNotify = (siteCfg.mission and siteCfg.mission.notifyOnWaveTimeout) or false
                local waveMsg = _('missionFailed') or 'Mission Failed'
                local showTimeNotifs = (siteCfg.mission and siteCfg.mission.showWaveTimeNotifs) or false

                -- prepare notification thresholds (ms remaining).
                -- Notify at start (full time shown separately), then only at half-time and final 30s.
                local notifThresholds, t_h, t_30 = BuildNotifThresholds(showTimeNotifs, waveTimeout)

                local notified = {}

                local waitStart = GetGameTimer()
                -- initial timed notification (if enabled) only if there's actually
                -- something to wait for (previous wave not already cleared).
                if showTimeNotifs and #notifThresholds > 0 and not IsWaveDead(ctx.wavePeds, current - 1, EnemyPeds) then
                    local dict = "menu_textures"
                    LoadTextureDict(dict)
                    Core.NotifyLeft(_U('timeToClear') .. FormatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
                        "COLOR_WHITE")
                end

                while not IsWaveDead(ctx.wavePeds, current - 1, EnemyPeds) do
                    Wait(1000)
                    if not EnsureMissionActive() then return end

                    local elapsed = GetGameTimer() - waitStart
                    local remaining = waveTimeout - elapsed

                    if showTimeNotifs then
                        for _, thresh in ipairs(notifThresholds) do
                            if remaining <= thresh and not notified[thresh] then
                                notified[thresh] = true
                                local dict = "menu_textures"
                                LoadTextureDict(dict)
                                local msg = ''
                                if thresh == t_30 then
                                    msg = _U('final30') or 'Final 30 seconds!'
                                elseif thresh == t_h then
                                    msg = _U('halfTime') or 'Half time!'
                                end
                                if msg ~= '' then
                                    Core.NotifyLeft(msg, "", dict, "menu_icon_alert", 3000, "COLOR_WHITE")
                                end
                            end
                        end
                    end

                    if elapsed > waveTimeout then
                        DBG.Info(string.format('Per-wave timeout at wave %d for site %s, forcing reset', current - 1,
                            tostring(site)))
                        if waveNotify then
                            local dict = "menu_textures"
                            LoadTextureDict(dict)
                            Core.NotifyLeft(waveMsg, "", dict, "menu_icon_alert", 4000, "COLOR_WHITE")
                        end
                        InMission = false
                        ResetWaves()
                        return
                    end
                end
                if not EnsureMissionActive() then return end

                -- Don't apply the regular inter-wave delay before the very first
                -- wave; only wait between subsequent waves.
                local waveDelay = 0
                if current > startWave then
                    waveDelay = Config.EnemyWaveDelay * 1000
                end
                while waveDelay > 0 do
                    Wait(1000)
                    waveDelay = waveDelay - 1000
                    if not EnsureMissionActive() then return end
                end

                local dict = "menu_textures"
                LoadTextureDict(dict)
                Core.NotifyLeft(string.format(_U('wave') .. '%d' .. _U('of') .. '%d' .. _U('starting'), current,
                        #ctx.waves), "", dict, "menu_icon_alert",
                    3000, "COLOR_WHITE")

                -- Small delay so the "starting" message is visible, then show the
                -- starting timeout message (short) and spawn NPCs.
                Wait(500)
                if not EnsureMissionActive() then return end

                if showTimeNotifs and #notifThresholds > 0 then
                    LoadTextureDict(dict)
                    Core.NotifyLeft(_U('timeToClear') .. FormatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
                        "COLOR_WHITE")
                end

                local spawned = SpawnWave(ctx, current)
                ctx.totalEnemies = (ctx.totalEnemies or 0) + (spawned or 0)
                current = current + 1
            end

            local finalIndex = #ctx.waves
            local waveTimeoutMin = (siteCfg.mission and siteCfg.mission.waveTimeoutMin) or 3
            local waveTimeout = waveTimeoutMin * 60000
            local waveNotify = (siteCfg.mission and siteCfg.mission.notifyOnWaveTimeout) or false
            local waveMsg = _('missionFailed') or ' Mission Failed'
            local showTimeNotifs = (siteCfg.mission and siteCfg.mission.showWaveTimeNotifs) or false

            -- prepare notification thresholds (ms remaining).
            -- Notify at start (full time shown separately), then only at half-time and final 30s.
            local notifThresholds, t_h, t_30 = BuildNotifThresholds(showTimeNotifs, waveTimeout)

            local notified = {}

            local startWait = GetGameTimer()
            -- only show the final-wave start timer if the final wave hasn't already
            -- been cleared (avoid showing before a wait that won't happen)
            if showTimeNotifs and #notifThresholds > 0 and not IsWaveDead(ctx.wavePeds, finalIndex, EnemyPeds) then
                local dict = "menu_textures"
                LoadTextureDict(dict)
                Core.NotifyLeft(_U('timeToClear') .. FormatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
                    "COLOR_WHITE")
            end

            while not IsWaveDead(ctx.wavePeds, finalIndex, EnemyPeds) do
                Wait(1000)
                if not EnsureMissionActive() then return end
                local elapsed = GetGameTimer() - startWait
                local remaining = waveTimeout - elapsed

                if showTimeNotifs then
                    for _, thresh in ipairs(notifThresholds) do
                        if remaining <= thresh and not notified[thresh] then
                            notified[thresh] = true
                            local dict = "menu_textures"
                            LoadTextureDict(dict)
                            local msg = ''
                            if thresh == t_30 then
                                msg = _U('final30') or 'Final 30 seconds!'
                            elseif thresh == t_h then
                                msg = _U('halfTime') or 'Half time!'
                            end
                            if msg ~= '' then
                                Core.NotifyLeft(msg, "", dict, "menu_icon_alert", 3000, "COLOR_WHITE")
                            end
                        end
                    end
                end

                if elapsed > waveTimeout then
                    DBG.Info('Timeout waiting for final wave to clear, forcing reset')
                    if waveNotify then
                        local dict = "menu_textures"
                        LoadTextureDict(dict)
                        Core.NotifyLeft(waveMsg, "", dict, "menu_icon_alert", 4000, "COLOR_WHITE")
                    end
                    break
                end
            end

            -- Only proceed to loot if the final wave truly cleared (no timeout or cancel)
            if IsWaveDead(ctx.wavePeds, finalIndex, EnemyPeds) then
                TriggerEvent('bcc-waves:LootHandler', site, siteCfg)
                DBG.Info('All enemy waves completed')
            else
                DBG.Info('Final wave did not clear; performing mission cleanup')
                -- Ensure mission state is cleared and peds are removed when mission
                -- failed/timed out/cancelled while waiting for final wave.
                InMission = false
                ResetWaves()
                return
            end
        end)
    end

    StartWaveLoop(currentWave)

    CreateThread(function()
        while InMission do
            Wait(1000)
            for pedIndex, ped in pairs(EnemyPeds) do
                if DoesEntityExist(ped) and IsEntityDead(ped) then
                    if EnemyBlips[pedIndex] and DoesBlipExist(EnemyBlips[pedIndex]) then
                        RemoveBlip(EnemyBlips[pedIndex])
                        EnemyBlips[pedIndex] = nil
                    end
                end
            end
        end
    end)
end)

AddEventHandler('bcc-waves:LootHandler', function(site, siteCfg)
    if not EnsureMissionActive() then return end

    local textureDict = "generic_textures"
    LoadTextureDict(textureDict)
    Core.NotifyLeft(_U('collectRewards'), "", "generic_textures", "tick", 4000, "COLOR_GREEN")

    -- create a chest object at the shop location
    local chestModelName = (siteCfg.mission and siteCfg.mission.chestModel) or 'p_chest01x'
    local chestHash = joaat(chestModelName)
    local spawnPos = siteCfg.shop.coords
    -- offset the chest slightly in front of the marker
    local chestPos = vector3(spawnPos.x, spawnPos.y + 1.0, spawnPos.z)
    if chestHash ~= 0 then
        LoadModel(chestHash, chestModelName)
        if HasModelLoaded(chestHash) then
            LootChest = CreateObject(chestHash, chestPos.x, chestPos.y, chestPos.z, true, true, false, false, false)
            if LootChest and DoesEntityExist(LootChest) then
                -- properly position and freeze the chest
                SetEntityCollision(LootChest, false, false)
                SetEntityCoords(LootChest, chestPos.x, chestPos.y, chestPos.z - 1, false, false, false, false)
                SetEntityHeading(LootChest, 0.0)
                FreezeEntityPosition(LootChest, true)
                SetEntityCollision(LootChest, true, true)
            else
                LootChest = nil
            end
        else
            DBG.Warning('Failed to load chest model: ' .. tostring(chestModelName))
        end
    end

    local promptDist = siteCfg.rewards.distance or 1.5
    while InMission do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - chestPos)

        if distance <= promptDist then
            sleep = 0
            -- Activate the reward prompt group via the Prompts global API
            local prompts = rawget(_G, 'Prompts')
            local rewardGroup = prompts and prompts.GetRewardGroup and prompts.GetRewardGroup()
            local rewardPrompt = prompts and prompts.GetRewardPrompt and prompts.GetRewardPrompt()
            if rewardGroup then
                UiPromptSetActiveGroupThisFrame(rewardGroup, CreateVarString(10, 'LITERAL_STRING', siteCfg.shop.prompt), 1, 0, 0, 0)
            end
            if rewardPrompt and Citizen.InvokeNative(0xE0F65F0640EF0617, rewardPrompt) then -- PromptHasHoldModeCompleted
                HidePedWeapons(playerPed, 2, true)
                -- Play an animation then send rewards to server
                Wait(200)
                local animDict = (siteCfg.mission and siteCfg.mission.chestAnimDict) or 'mech_ransack@chest@med@open@crouch@b'
                local animName = (siteCfg.mission and siteCfg.mission.chestAnim) or 'base'
                RequestAnimDict(animDict)
                local tstart = GetGameTimer()
                while not HasAnimDictLoaded(animDict) and (GetGameTimer() - tstart) < 2000 do
                    Wait(0)
                end

                -- orient player towards chest
                if LootChest and DoesEntityExist(LootChest) then
                    local chestCoords = GetEntityCoords(LootChest)
                    TaskTurnPedToFaceCoord(playerPed, chestCoords.x, chestCoords.y, chestCoords.z, 1000)
                    Wait(1000)
                end

                if HasAnimDictLoaded(animDict) then
                    Citizen.InvokeNative(0xEA47FE3719165B94, playerPed, animDict, animName, 1.0, 1.0, 5000, 1, 1.0, true, 0, false, 0, false) -- TaskPlayAnim
                    Wait(5000)
                else
                    -- fallback short delay
                    Wait(1500)
                end

                -- request server-side payout (server will look up rewards for the site)
                -- Run the server callback in a separate thread and wait up to a timeout
                local payoutResult = nil
                local payoutDone = false
                CreateThread(function()
                    local ok = Core.Callback.TriggerAwait('bcc-waves:RewardPayout', site)
                    payoutResult = ok
                    payoutDone = true
                end)

                local waited = 0
                local timeoutMs = 10000
                while not payoutDone and waited < timeoutMs do
                    Wait(100)
                    waited = waited + 100
                end

                if not payoutDone then
                    -- Server did not respond in time. Clean up and notify player.
                    DBG.Warning('Reward payout timed out for site ' .. tostring(site))
                    Core.NotifyRightTip('Server did not respond to payout request', 5000)
                    if LootChest and DoesEntityExist(LootChest) then
                        DeleteEntity(LootChest)
                        LootChest = nil
                    end
                    InMission = false
                    ResetWaves()
                    return
                end

                DBG.Info('Requested reward payout from server for site ' ..
                tostring(site) .. ' (result=' .. tostring(payoutResult) .. ')')
                if payoutResult then
                    if LootChest and DoesEntityExist(LootChest) then
                        DeleteEntity(LootChest)
                        LootChest = nil
                    end
                    InMission = false
                    ResetWaves()
                    return
                end
            end
        end
        Wait(sleep)
    end
end)

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
