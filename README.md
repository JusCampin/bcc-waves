# bcc-waves

## Description

> Stake your claim and stand fast as tides of enemies try to take the ground. Success brings riches and glory; failure means a hard retreat. Every site is tuned for danger — timed assaults, focused spawn zones, and rewards worth the risk.

## Features

- Start a mission at a site using an in-world prompt; a blip and marker show the area.
- Waves of enemies spawn around the site and attack players inside the radius.
- Missions end when the final wave is cleared; a loot phase rewards players (cash, gold, items).
- Per-site tuning: wave counts, spawn radius, and per-wave timeouts (minutes).
- Cooldowns prevent immediate restarts; optional job restrictions per site.
- Server tracking ensures spawned NPCs are cleaned up when missions end or owner disconnects.

## Dependencies

- [vorp_core](https://github.com/VORPCORE/vorp-core-lua)
- [vorp_inventory](https://github.com/VORPCORE/vorp_inventory)
- [bcc-utils](https://github.com/BryceCanyonCounty/bcc-utils)

## Installation

- Make sure dependencies are installed and ensured above `bcc-waves`
- Add the `bcc-waves` folder to your resources folder
- Add `ensure bcc-waves` to your resources.cfg
- Restart your server

## Configuration

- Per-site config lives in `configs/sites.lua` (`areaRadius`, `enemyWaves`, `mission.waveTimeoutMin` etc.)
- Global tuning in `configs/config.lua` (PedUpdater, finalWaveTimeoutMin)

## Credits

- Created with: [itskaaas](https://github.com/itskaaas)

## GitHub

[bcc-waves](https://github.com/BryceCanyonCounty/bcc-waves)
