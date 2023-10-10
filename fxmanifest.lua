fx_version 'cerulean'
game 'gta5'

description 'QBX-Weed'
repository 'https://github.com/Qbox-project/qbx-weed'
version '1.0.0'

shared_scripts {
    '@qbx_core/import.lua',
    'config.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua', -- Change to the language you want
    '@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

modules {'qbx_core:utils'}

provide 'qb-weed'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
