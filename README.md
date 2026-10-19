# snowy_snow

![FiveM](https://img.shields.io/badge/FiveM-resource-F40552?style=for-the-badge)
![Lua](https://img.shields.io/badge/Lua-5.4-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![ox_lib](https://img.shields.io/badge/requires-ox__lib-4C8BF5?style=for-the-badge)
![oxmysql](https://img.shields.io/badge/requires-oxmysql-4C8BF5?style=for-the-badge)
![ox_inventory](https://img.shields.io/badge/requires-ox__inventory-4C8BF5?style=for-the-badge)
![Synced](https://img.shields.io/badge/fully-synced-8A2BE2?style=for-the-badge)
![AI assisted](https://img.shields.io/badge/AI%20assisted-human%20supervised-orange?style=for-the-badge)

Snow piles that spawn in zones you place around the map. Players grab a shovel, scoop the piles away bit by bit and haul the snow off in a wheelbarrow. Piles come back on a timer, and everything is synced for every player.

[![Watch the video](https://img.youtube.com/vi/H6CiK-I6Usc/maxresdefault.jpg)](https://youtu.be/H6CiK-I6Usc)

▶ **[Watch it on YouTube](https://youtu.be/H6CiK-I6Usc)**

> **Note:** Part of this project was made with AI, under human supervision. Every feature was directed, reviewed and tested by a human.

## Features

- 5 hand-made snow piles that shrink chunk by chunk as they are scooped
- Piles sit on the ground and tilt with the slope
- Admin-placed zones with their own pile count and respawn time (default 2 hours)
- Custom snow shovel and animations: carry, walk, scoop, dump
- Wheelbarrow that you push around, fill up (half load at 3, full at 6) and empty
- Shovel and wheelbarrow are inventory items, and the wheelbarrow keeps its snow when picked up
- Piles only spawn for players nearby, so they cost nothing elsewhere on the map
- Zones are saved and come back after a restart

## Installation

1. Put the `snowy_snow` folder in your `resources` folder.
2. Add `ensure snowy_snow` to your `server.cfg`, **after** `ox_lib`, `oxmysql` and `ox_inventory`.
3. Add the two items below to `ox_inventory/data/items.lua`.
4. Give your admins the `group.admin` ace (needed to place and remove zones).
5. Restart the server and **reconnect** (the models and animations only load on connect).

The database table is created on its own the first time the resource starts.

```lua
['snowy_shovel'] = {
    label = 'Snow shovel',
    weight = 2500,
    stack = false,
    close = true,
    client = { export = 'snowy_snow.toggleShovel' },
},

['snowy_wheelbarrow'] = {
    label = 'Wheelbarrow',
    weight = 15000,
    stack = false,
    close = true,
    server = { export = 'snowy_snow.useWheelbarrow' },
},
```

## Admin commands

| Command | What it does |
|---|---|
| `/snowzone_add <radius> <piles> [minutes] [name]` | Place a zone around you |
| `/snowzone_remove <id>` | Remove a zone and its piles |
| `/snowzone_list` | Show all zones, their piles and the time until they respawn |
| `/snowzone_respawn [id]` | Respawn the piles of one zone, or all zones |
| `/snowzone_debug` | Show or hide the zone outlines |

### Placing a zone

1. Stand in the middle of the area you want to cover.
2. Type for example `/snowzone_add 20 8` for a 20 m zone with 8 piles.
3. Add a respawn time in minutes if you don't want the default 2 hours: `/snowzone_add 20 8 60 Parking lot`.

## How to use

Use the shovel from your inventory to take it out, and use it again to put it away. Using the wheelbarrow item puts it down in front of you.

| Where you are | `E` | `G` | `H` |
|---|---|---|---|
| Shovel out, next to a pile | Scoop snow | | |
| Snow on the shovel | | Dump it on the ground | |
| Snow on the shovel, next to a wheelbarrow | Put it in the wheelbarrow | Dump it on the ground | |
| Next to a wheelbarrow, shovel away | Push it / let go | Empty it | Pick it up |

Every pile takes several scoops before it is gone, depending on its size. A wheelbarrow holds 6 scoops.

## Configuration

| File | What you can change |
|---|---|
| `configs/shared/main.lua` | Item names, keys, pile types, wheelbarrow capacity, shovel and animation settings |
| `configs/server/main.lua` | Default respawn time, zone limits, cooldowns, interaction distance, admin group |

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_inventory](https://github.com/overextended/ox_inventory)
