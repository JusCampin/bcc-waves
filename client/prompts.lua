-- small module API exported as `Prompts` (single global table)
local MainPrompt = 0
local MainGroup = GetRandomIntInRange(0, 0xffffff)
local RewardPrompt = 0
local RewardGroup = GetRandomIntInRange(0, 0xffffff)
local PromptsStarted = false

local Prompts = {}

function Prompts.LoadStartPrompt()
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

-- Prompt loop
CreateThread(function()
    Prompts.LoadStartPrompt()
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
            local shopClosed = IsShopClosed(siteCfg)

            ManageBlip(site, shopClosed)

            if distance <= siteCfg.shop.promptDistance then
                sleep = 0
                local promptText = ''
                if shopClosed then
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
                UiPromptSetEnabled(MainPrompt, not shopClosed)

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

-- expose a minimal API for other modules to query prompt handles/groups
function Prompts.GetMainGroup()
    return MainGroup
end

function Prompts.GetMainPrompt()
    return MainPrompt
end

function Prompts.GetRewardGroup()
    return RewardGroup
end

function Prompts.GetRewardPrompt()
    return RewardPrompt
end

-- export the module table as a single global to avoid polluting with multiple globals
_G.Prompts = Prompts
