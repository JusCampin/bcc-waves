Sites =
{
    ['lakay'] = {                                              -- Each location must have a unique name
        shop = {
            prompt         = 'Lakay Bandit Camp',              -- Text Below Prompt Button
            markerHash     = 0x07DCE236,                       -- Hashes can be found here: https://github.com/femga/rdr3_discoveries/blob/master/graphics/markers/marker_types.lua
            coords         = vector3(2256.46, -772.11, 42.78), -- Marker location to start enemy waves
            markerDistance = 50.0,                             -- Distance from marker coords to show marker to player
            promptDistance = 1,                                -- Distance from marker to show prompt
            jobsEnabled    = false,                            -- Allow Access to Specified Jobs Only
            jobs           = {                                 -- Allowed Jobs - ex. jobs = {{name = 'police', grade = 1},{name = 'doctor', grade = 3}}
                { name = 'police', grade = 0 },
            },
            hours          = {
                active = false, -- Location uses Open and Closed Hours
                open   = 7,     -- Location Open Time / 24 Hour Clock
                close  = 21     -- Location Close Time / 24 Hour Clock
            }
        },
        blip = {
            name   = 'Lakay Bandit Camp', -- Name of Blip on Map
            sprite = -1606321000,         -- Default: -1606321000
            show   = {
                open = true,              -- Show Blip On Map when Open
                closed = true,            -- Show Blip On Map when Closed
            },
            color  = {
                open   = 'WHITE',        -- Open - Default: White - Blip Colors Shown Below
                closed = 'RED',          -- Closed - Default: Red - Blip Colors Shown Below
                job    = 'YELLOW_ORANGE' -- Job Locked - Default: Yellow - Blip Colors Shown Below
            }
        },
        bandits = {
            model = 'a_m_m_huntertravelers_cool_01', -- model of the enemy npc
            blipSprite = 953018525,                  -- blip sprite for enemy npc
            accuracy = 30,                           -- accuracy of enemies (0-100)
            seeingRange = 100.0,                     -- seeing range of enemies (in units)
            hearingRange = 100.0,                    -- hearing range of enemies (in units)
        },
        rewards = {                                  -- Rewards for Completing Mission (min/max per payout)
            distance = 1.0,                          -- distance from rewards prop to show prompt
            cash = { min = 50, max = 450 },          -- Cash reward range (set max=0 to disable range / will use min value)
            gold = { min = 1, max = 5 },             -- Gold reward range (set max=0 to disable range / will use min value)
            rol = { min = 10, max = 50 },            -- Rol reward range (set max=0 to disable range / will use min value)
            items = {
                -- Item reward range (set max=0 to disable range / will use min value)
                { itemName = 'iron', label = 'Iron', quantity = { min = 1, max = 5 } },
            },
        },
        areaBlip = {
            style = 'BLIP_STYLE_ENEMY',
            radius = 100.0, -- Radius of the wave area in units (for blip and distance checks)
        },
        -- example, {3, 3, 3, 5, 5} means 5 waves: the first 3 with 3 enemies, the last 2 with 5 enemies
        enemyWaves = { 2, 3, 4, 5 },
        mission = {
            waveTimeoutMin = 3,         -- Time limit for each wave in minutes (default 3 minutes)
            showWaveTimeNotifs = true,  -- Players will receive time-left messages at start, 1/2 and final 30s.
            notifyOnWaveTimeout = true, -- Show an in-game notification to the player when a per-wave timeout/reset occurs (mission failed)
            chestModel = 'p_chest01x',  -- model name to spawn for the loot chest
            -- animation played by the player when claiming the chest
            chestAnimDict = 'mech_ransack@chest@med@open@crouch@b',
            chestAnim = 'base',
        },
    },
    -----------------------------------------------------

    ['heartlands'] = {                                      -- Each location must have a unique name
        shop = {
            prompt         = 'Heartlands Bandit Camp',      -- Text Below Prompt Button
            markerHash     = 0x07DCE236,                    -- Hashes can be found here: https://github.com/femga/rdr3_discoveries/blob/master/graphics/markers/marker_types.lua
            coords         = vector3(-46.20, 33.36, 92.27), -- Marker location to start enemy waves
            markerDistance = 50.0,                          -- Distance from marker coords to show marker to player
            promptDistance = 1,                             -- Distance from marker to show prompt
            jobsEnabled    = false,                         -- Allow Access to Specified Jobs Only
            jobs           = {                              -- Allowed Jobs - ex. jobs = {{name = 'police', grade = 1},{name = 'doctor', grade = 3}}
                { name = 'police', grade = 0 },
            },
            hours          = {
                active = false, -- Location uses Open and Closed Hours
                open   = 7,     -- Location Open Time / 24 Hour Clock
                close  = 21     -- Location Close Time / 24 Hour Clock
            }
        },
        blip = {
            name   = 'Heartlands Bandit Camp', -- Name of Blip on Map
            sprite = -1606321000,              -- Default: -1606321000
            show   = {
                open = true,                   -- Show Blip On Map when Open
                closed = true,                 -- Show Blip On Map when Closed
            },
            color  = {
                open   = 'WHITE',        -- Open - Default: White - Blip Colors Shown Below
                closed = 'RED',          -- Closed - Default: Red - Blip Colors Shown Below
                job    = 'YELLOW_ORANGE' -- Job Locked - Default: Yellow - Blip Colors Shown Below
            }
        },
        bandits = {
            model = 'a_m_m_huntertravelers_cool_01', -- model of the enemy npc
            blipSprite = 953018525,                  -- blip sprite for enemy npc
            accuracy = 30,                           -- accuracy of enemies (0-100)
            seeingRange = 100.0,                     -- seeing range of enemies (in units)
            hearingRange = 100.0,                    -- hearing range of enemies (in units)
        },
        rewards = {                                  -- Rewards for Completing Mission (min/max per payout)
            distance = 1.0,                          -- distance from rewards prop to show prompt
            cash = { min = 50, max = 450 },          -- Cash reward range (set max=0 to disable range / will use min value)
            gold = { min = 1, max = 5 },             -- Gold reward range (set max=0 to disable range / will use min value)
            rol = { min = 10, max = 50 },            -- Rol reward range (set max=0 to disable range / will use min value)
            items = {
                -- Item reward range (set max=0 to disable range / will use min value)
                { itemName = 'iron', label = 'Iron', quantity = { min = 1, max = 5 } },
            },
        },
        areaBlip = {
            style = 'BLIP_STYLE_ENEMY',
            radius = 100.0, -- Radius of the wave area in units (for blip and distance checks)
        },
        -- example, {3, 3, 3, 5, 5} means 5 waves: the first 3 with 3 enemies, the last 2 with 5 enemies
        enemyWaves = { 1, 1 },
        mission = {
            waveTimeoutMin = 3,         -- Time limit for each wave in minutes (default 3 minutes)
            showWaveTimeNotifs = true,  -- Players will receive time-left messages at start, 1/2 and final 30s.
            notifyOnWaveTimeout = true, -- Show an in-game notification to the player when a per-wave timeout/reset occurs (mission failed)
            chestModel = 'p_chest01x',  -- model name to spawn for the loot chest
            -- animation played by the player when claiming the chest
            chestAnimDict = 'mech_ransack@chest@med@open@crouch@b',
            chestAnim = 'base',
        },
    },
}
