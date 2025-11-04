-- utils.lua: shared helpers
-- expose common globals used across client modules
Core = exports.vorp_core:GetCore()
---@type BCCWavesDebugLib
DBG = BCCWavesDebug

-- Initialize random seed for better math.random usage
math.randomseed(GetGameTimer() + GetRandomIntInRange(1, 1000))

function LoadTextureDict(dict)
    if not dict or dict == "" then return end

    if not HasStreamedTextureDictLoaded(dict) then
        RequestStreamedTextureDict(dict, true)

        local timeout = 5000
        local startTime = GetGameTimer()
        while not HasStreamedTextureDictLoaded(dict) do
            if GetGameTimer() - startTime > timeout then
                print('Failed to load texture dict:', dict)
                return
            end
            Wait(10)
        end
    end
end

function LoadModel(model, modelName)
    if not IsModelValid(model) then
        return print('Invalid model:', modelName)
    end

    if not HasModelLoaded(model) then
        RequestModel(model, false)

        local timeout = 10000
        local startTime = GetGameTimer()

        while not HasModelLoaded(model) do
            if GetGameTimer() - startTime > timeout then
                print('Failed to load model:', modelName)
                return
            end
            Wait(10)
        end
    end
end

function ComputeSpawnCoords(markerCoords, playerCoords, dist, zBase, jitterDeg)
    jitterDeg = jitterDeg or 15

    local angle = math.random() * 2 * math.pi
    if playerCoords and markerCoords and (playerCoords.x ~= markerCoords.x or playerCoords.y ~= markerCoords.y) then
        local dir = playerCoords - markerCoords
        local angleToPlayer = math.atan(dir.y, dir.x)
        local jitter = (math.random() - 0.5) * math.rad(jitterDeg * 2)
        angle = angleToPlayer + math.pi + jitter
    end

    local x = markerCoords.x + dist * math.cos(angle)
    local y = markerCoords.y + dist * math.sin(angle)
    local z = (zBase or markerCoords.z) + 50
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 10, false)
    if foundGround then
        z = groundZ
    end

    return x, y, z
end

function GenerateNpcCoords(markerCoords, playerCoords, totalEnemies, areaRadius)
    local NpcCoords = {}

    if not areaRadius then
        DBG.Warning('GenerateNpcCoords: missing areaBlip.radius (site config). Defaulting to 100')
        areaRadius = 100
    end

    local minDist = math.floor(areaRadius / 2)
    local maxDist = areaRadius - 10

    for i = 1, totalEnemies do
        local angle = math.random() * 2 * math.pi
        local dist = math.random(minDist, maxDist)
        local x = markerCoords.x + dist * math.cos(angle)
        local y = markerCoords.y + dist * math.sin(angle)
        local z = markerCoords.z + 50

        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if foundGround then z = groundZ end

        local spawnCoords = vector3(x, y, z)
        local playerDist = #(spawnCoords - playerCoords)
        if playerDist < 30 then
            x, y, z = ComputeSpawnCoords(markerCoords, playerCoords, dist, markerCoords.z, 15)
        end

        table.insert(NpcCoords, { x = x, y = y, z = z })
    end
    return NpcCoords
end

function IsWaveDead(wavePeds, waveIndex, enemyPedsTable)
    if not wavePeds or not wavePeds[waveIndex] then return true end

    for _, pedIndex in pairs(wavePeds[waveIndex]) do
        local ped = enemyPedsTable[pedIndex]
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            return false
        end
    end

    return true
end

function GetClosestPlayer()
    local players = GetActivePlayers()
    local player = PlayerId()
    local coords = GetEntityCoords(PlayerPedId())
    local closestPlayer = nil
    local closestDistance = math.huge

    for _, playerId in ipairs(players) do
        if playerId ~= player then
            if NetworkIsPlayerActive(playerId) then
                local targetPed = GetPlayerPed(playerId)
                if targetPed and targetPed ~= 0 and not IsEntityDead(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    local distance = #(coords - targetCoords)
                    if distance < closestDistance then
                        closestPlayer = targetPed
                        closestDistance = distance
                    end
                end
            end
        end
    end

    return closestPlayer or PlayerPedId()
end

function IsShopClosed(siteCfg)
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

-- format milliseconds into human-readable time (e.g. "1m 05s" or "30s")
function FormatMs(ms)
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

-- Build notification thresholds for a given wave timeout.
-- Returns: notifThresholds (sorted desc), t_h, t_30
function BuildNotifThresholds(showTimeNotifs, waveTimeout)
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
    return notifThresholds, t_h, t_30
end
