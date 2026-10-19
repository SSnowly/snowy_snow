fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'snowy_snow'
description 'Snow piles in admin-placed zones, shovel scooping and wheelbarrow hauling'

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/_index.lua',
}

client_scripts {
    'client/_index.lua',
}

files {
    'configs/shared/main.lua',
    'client/prompt.lua',
    'client/ground.lua',
    'client/status.lua',
    'client/attach.lua',
    'client/carry.lua',
    'client/piles.lua',
    'client/barrow.lua',
    'client/shovel.lua',
    'client/admin.lua',
}

data_file 'DLC_ITYP_REQUEST' 'stream/snowy_snow.ytyp'
