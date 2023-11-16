fx_version 'cerulean'
game 'gta5'

description 'QBX_Weed'
repository 'https://github.com/Qbox-project/qbx_weed'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/utils.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

provide 'qb-weed'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
