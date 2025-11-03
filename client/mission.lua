-- mission.lua: mission flow, event handlers and UI
local MainPrompt = 0
local MainGroup = GetRandomIntInRange(0, 0xffffff)
local RewardPrompt = 0
local RewardGroup = GetRandomIntInRange(0, 0xffffff)
local PromptsStarted = false
InMission = false
AreaBlip = AreaBlip or 0
CurrentMissionSite = CurrentMissionSite or nil
LootChest = LootChest or nil

local function LoadStartPrompt()
    if PromptsStarted then
        DBG.Success('Main prompt already started')
        return
    end

    if not MainGroup or not RewardGroup then
        DBG.Error('MainGroup or RewardGroup not initialized')
        return
    end

    if not Config or not Config.keys or not Config.keys.start or not Config.keys.reward then
        DBG.Error('Start or Reward key is not configured properly')
        return
    end

    MainPrompt = UiPromptRegisterBegin()
    if not MainPrompt or MainPrompt == 0 then
        DBG.Error('Failed to register MainPrompt')
        return
    end
    UiPromptSetControlAction(MainPrompt, Config.keys.start)
    UiPromptSetText(MainPrompt, CreateVarString(10, 'LITERAL_STRING', 'Start Waves'))
    UiPromptSetVisible(MainPrompt, true)
    Citizen.InvokeNative(0x74C7D7B72ED0D3CF, MainPrompt, 'MEDIUM_TIMED_EVENT') -- PromptSetStandardizedHoldMode
    UiPromptSetGroup(MainPrompt, MainGroup, 0)
    UiPromptRegisterEnd(MainPrompt)

    RewardPrompt = UiPromptRegisterBegin()
    if not RewardPrompt or RewardPrompt == 0 then
        DBG.Error('Failed to register RewardPrompt')
        return
    end
    UiPromptSetControlAction(RewardPrompt, Config.keys.reward)
    UiPromptSetText(RewardPrompt, CreateVarString(10, 'LITERAL_STRING', 'Claim Reward'))
    UiPromptSetEnabled(RewardPrompt, true)
    UiPromptSetVisible(RewardPrompt, true)
    Citizen.InvokeNative(0x74C7D7B72ED0D3CF, RewardPrompt, 'MEDIUM_TIMED_EVENT') -- PromptSetStandardizedHoldMode
    UiPromptSetGroup(RewardPrompt, RewardGroup, 0)
    UiPromptRegisterEnd(RewardPrompt)

    PromptsStarted = true
    DBG.Success('Main Prompt started successfully')
end

local function isShopClosed(siteCfg)
    local hour = GetClockHours()
    local hoursActive = siteCfg.shop.hours.active

    if not hoursActive then
        return false
    end

    local openHour = siteCfg.shop.hours.open
    local closeHour = siteCfg.shop.hours.close

    if openHour < closeHour then
        -- Normal: shop opens and closes on the same day
        return hour < openHour or hour >= closeHour
    else
        -- Overnight: shop closes on the next day
        return hour < openHour and hour >= closeHour
    end
end

local function ManageBlip(site, closed)
    local siteCfg = Sites[site]

    if (closed and not siteCfg.blip.show.closed) or (not siteCfg.blip.show.open) then
        if siteCfg.Blip then
            RemoveBlip(siteCfg.Blip)
            siteCfg.Blip = nil
        end
        return
    end

    if not siteCfg.Blip then
        siteCfg.Blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300, siteCfg.shop.coords) -- BlipAddForCoords
        SetBlipSprite(siteCfg.Blip, siteCfg.blip.sprite, true)
        Citizen.InvokeNative(0x9CB1A1623062F402, siteCfg.Blip, siteCfg.blip.name)                -- SetBlipName
    end

    local color = siteCfg.blip.color.open
    if siteCfg.shop.jobsEnabled then color = siteCfg.blip.color.job end
    if closed then color = siteCfg.blip.color.closed end

    if Config.BlipColors[color] then
        Citizen.InvokeNative(0x662D364ABF16DE2F, siteCfg.Blip, joaat(Config.BlipColors[color])) -- BlipAddModifier
    else
        print('Error: Blip color not defined for color: ' .. tostring(color))
    end
end

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

-- Draw marker when player is in range
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

CreateThread(function()
    LoadStartPrompt()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 1000

        if IsEntityDead(PlayerPedId()) then
            if InMission then
                InMission = false
                DBG.Info("Player died, resetting mission")
                ResetWaves()
            end
            goto END
        end

        if InMission then goto END end

        for site, siteCfg in pairs(Sites) do
            local distance = #(playerCoords - siteCfg.shop.coords)
            IsShopClosed = isShopClosed(siteCfg)

            ManageBlip(site, IsShopClosed)

            if distance <= siteCfg.shop.promptDistance then
                sleep = 0
                local promptText = ''
                if IsShopClosed then
                    promptText = ('%s %s %d %s %d %s'):format(
                        siteCfg.shop.prompt,
                        _U('hours'),
                        siteCfg.shop.hours.open,
                        _U('to'),
                        siteCfg.shop.hours.close,
                        _U('hundred')
                    )
                else
                    promptText = siteCfg.shop.prompt
                end
                UiPromptSetActiveGroupThisFrame(MainGroup, CreateVarString(10, 'LITERAL_STRING', promptText), 1, 0, 0, 0)
                UiPromptSetEnabled(MainPrompt, not IsShopClosed)

                if Citizen.InvokeNative(0xE0F65F0640EF0617, MainPrompt) then -- PromptHasHoldModeCompleted
                    Wait(500)
                    if siteCfg.shop.jobsEnabled then
                        local hasJob = Core.Callback.TriggerAwait('bcc-waves:CheckJob', site)
                        if hasJob ~= true then
                            goto END
                        end
                    end
                    local canStart = Core.Callback.TriggerAwait('bcc-waves:CheckCooldown', site)
                    if canStart then
                        InMission = true
                        TriggerEvent('bcc-waves:MissionHandler', site, siteCfg)
                    else
                        Core.NotifyRightTip(_U('onCooldown'), 4000)
                    end
                end
            end
        end
        ::END::
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
            InMission = false
            ResetWaves()
            return
        end

        Wait(0)
    end
end)

-- Enemy peds handler
AddEventHandler('bcc-waves:EnemyPeds', function(site, siteCfg)
    if not EnsureMissionActive() then
        return
    end

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
        if not EnsureMissionActive() then
            return
        end
    end

    if not EnsureMissionActive() then
        return
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
                local notifThresholds = {}
                local t_h, t_30
                if showTimeNotifs then
                    t_h = math.floor(waveTimeout * 0.5)
                    t_30 = 30000
                    -- Deduplicate and sort descending
                    local seen = {}
                    for _, v in ipairs({ t_h, t_30 }) do
                        if v > 0 and not seen[v] then
                            table.insert(notifThresholds, v)
                            seen[v] = true
                        end
                    end
                    table.sort(notifThresholds, function(a, b) return a > b end)
                end

                local notified = {}
                local function formatMs(ms)
                    ms = math.max(0, ms)
                    local s = math.floor(ms / 1000)
                    local m = math.floor(s / 60)
                    s = s - m * 60
                    if m > 0 then
                        return string.format('%dm %02ds', m, s)
                    else
                        return string.format('%ds', s)
                    end
                end

                local waitStart = GetGameTimer()
                -- initial timed notification (if enabled) only if there's actually
                -- something to wait for (previous wave not already cleared).
                if showTimeNotifs and #notifThresholds > 0 and not IsWaveDead(ctx.wavePeds, current - 1, EnemyPeds) then
                    local dict = "menu_textures"
                    LoadTextureDict(dict)
                    Core.NotifyLeft(_U('timeToClear') .. formatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
                        "COLOR_WHITE")
                end

                while not IsWaveDead(ctx.wavePeds, current - 1, EnemyPeds) do
                    Wait(1000)
                    if not EnsureMissionActive() then
                        return
                    end

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
                                else
                                    msg = _U('timeRemaining') or 'Time remaining'
                                end
                                Core.NotifyLeft(msg, "", dict, "menu_icon_alert", 3000, "COLOR_WHITE")
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
                if not EnsureMissionActive() then
                    return
                end

                local waveDelay = Config.EnemyWaveDelay * 1000
                while waveDelay > 0 do
                    Wait(1000)
                    waveDelay = waveDelay - 1000
                    if not EnsureMissionActive() then
                        return
                    end
                end
                if not EnsureMissionActive() then
                    return
                end

                local dict = "menu_textures"
                LoadTextureDict(dict)
                Core.NotifyLeft(string.format(_U('wave') .. '%d' .. _U('of') .. '%d' .. _U('starting'), current,
                        #ctx.waves), "", dict, "menu_icon_alert",
                    3000, "COLOR_WHITE")

                -- Small delay so the "starting" message is visible, then show the
                -- starting timeout message (short) and spawn NPCs.
                Wait(500)
                if not EnsureMissionActive() then
                    return
                end
                if showTimeNotifs and #notifThresholds > 0 then
                    LoadTextureDict(dict)
                    Core.NotifyLeft(_U('timeToClear') .. formatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
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
            local notifThresholds = {}
            local t_h, t_30
            if showTimeNotifs then
                t_h = math.floor(waveTimeout * 0.5)
                t_30 = 30000
                local seen = {}
                for _, v in ipairs({ t_h, t_30 }) do
                    if v > 0 and not seen[v] then
                        table.insert(notifThresholds, v)
                        seen[v] = true
                    end
                end
                table.sort(notifThresholds, function(a, b) return a > b end)
            end

            local notified = {}
            local function formatMs(ms)
                ms = math.max(0, ms)
                local s = math.floor(ms / 1000)
                local m = math.floor(s / 60)
                s = s - m * 60
                if m > 0 then
                    return string.format('%dm %02ds', m, s)
                else
                    return string.format('%ds', s)
                end
            end

            local startWait = GetGameTimer()
            -- only show the final-wave start timer if the final wave hasn't already
            -- been cleared (avoid showing before a wait that won't happen)
            if showTimeNotifs and #notifThresholds > 0 and not IsWaveDead(ctx.wavePeds, finalIndex, EnemyPeds) then
                local dict = "menu_textures"
                LoadTextureDict(dict)
                Core.NotifyLeft(_U('timeToClear') .. formatMs(waveTimeout), "", dict, "menu_icon_alert", 3000,
                    "COLOR_WHITE")
            end

            while not IsWaveDead(ctx.wavePeds, finalIndex, EnemyPeds) do
                Wait(1000)
                if not InMission then break end
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
                            else
                                msg = _U('timeRemaining') or 'Time remaining'
                            end
                            Core.NotifyLeft(msg, "", dict, "menu_icon_alert", 3000, "COLOR_WHITE")
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
    if not EnsureMissionActive() then
        return
    end

    local textureDict = "generic_textures"
    LoadTextureDict(textureDict)
    Core.NotifyLeft(_U('collectRewards'), "", "generic_textures", "tick", 4000, "COLOR_GREEN")

    -- create a chest object at the shop location
    local chestModelName = (siteCfg.mission and siteCfg.mission.chestModel) or 'p_chest01x'
    local chestHash = joaat(chestModelName)
    if chestHash ~= 0 then
        LoadModel(chestHash, chestModelName)
        if HasModelLoaded(chestHash) then
            local spawnPos = siteCfg.shop.coords
            -- offset the chest slightly in front of the marker
            local chestPos = vector3(spawnPos.x, spawnPos.y + 1.0, spawnPos.z)
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

    while InMission do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - siteCfg.shop.coords)

        if distance <= 2 then
            sleep = 0
            UiPromptSetActiveGroupThisFrame(RewardGroup, CreateVarString(10, 'LITERAL_STRING', siteCfg.shop.prompt), 1, 0,
                0, 0)
            if Citizen.InvokeNative(0xE0F65F0640EF0617, RewardPrompt) then -- PromptHasHoldModeCompleted
                -- Play an animation (if available) then send rewards to server
                Wait(200)
                local animDict = (siteCfg.mission and siteCfg.mission.chestAnimDict) or
                    'mech_ransack@chest@med@open@crouch@b'
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
                end

                if HasAnimDictLoaded(animDict) then
                    TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, 5000, 17, 0.2, false, false, false)
                    Wait(5000)
                else
                    -- fallback short delay
                    Wait(2000)
                end

                -- request server-side payout (server will look up rewards for the site)
                local hasRewards = Core.Callback.TriggerAwait('bcc-waves:RewardPayout', site)
                DBG.Info('Requested reward payout from server for site ' .. tostring(site))
                if hasRewards then
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
