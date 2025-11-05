local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local Discord = BccUtils.Discord.setup(Config.Webhook.URL, Config.Webhook.Title, Config.Webhook.Avatar)
---@type BCCWavesDebugLib
local DBG = BCCWavesDebug

-- Access global missions state for ownership validation
local Missions = rawget(_G, 'Missions') or {}

-- Server-side reward payout logic (moved from server.lua)
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

    -- Validate that the caller is the owner of the mission for this site
    if Missions[tostring(site)] ~= src then
        DBG.Warning(string.format("RewardPayout: source %s attempted to payout for site %s but owner is %s", tostring(src), tostring(site), tostring(Missions[tostring(site)])))
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

    -- send to Discord
    pcall(function()
        Discord:sendMessage('Name: ' ..
            character.firstname .. ' ' .. character.lastname .. '\nIdentifier: ' .. character.identifier ..
            '\nReward: ' .. '$' .. tostring(cash) ..
            '\nReward: ' .. tostring(gold) .. ' gold' ..
            '\nReward: ' .. tostring(rol) .. ' rol')
    end)

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
                pcall(function()
                    Discord:sendMessage('Name: ' ..
                        character.firstname ..
                        ' ' ..
                        character.lastname ..
                        '\nIdentifier: ' .. character.identifier .. '\nReward: ' .. count .. ' ' .. name)
                end)
            else
                Core.NotifyRightTip(src, _U('noSpace'), 4000)
            end
        end
    end

    return cb(true)
end)
