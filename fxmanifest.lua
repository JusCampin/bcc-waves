game 'rdr3'
fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'
author 'BCC Team / itskaaas'

shared_scripts {
    'configs/*.lua',
    'debug_init.lua',
    'locale.lua',
    'languages/*.lua'
}

server_scripts {
    'server/state.lua',
    'server/rewards.lua',
    'server/jobs.lua',
    'server/cooldowns.lua',
    'server/peds.lua',
    'server/missions.lua',
    'server/version.lua',
}

client_scripts {
    'client/utils.lua',
    'client/mission_state.lua',
    'client/blips.lua',
    'client/peds.lua',
    'client/prompts.lua',
    'client/mission.lua',
}

version '1.0.0'
