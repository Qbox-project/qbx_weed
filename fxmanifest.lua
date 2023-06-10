fx_version 'cerulean'
game 'gta5'

description 'QBX-Weed'
version '1.0.0'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua', -- Change to the language you want
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_script 'client/main.lua'

provide 'qb-weed'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
