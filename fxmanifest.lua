fx_version 'cerulean'
game 'gta5'

description 'https://github.com/Qbox-project/qbx-weed'
version '1.0.0'

shared_scripts {
    '@qbx-core/import.lua',
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua', -- Change to the language you want
    '@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

modules {
	'qbx-core:core',
    'qbx-core:utils'
}

provide 'qb-weed'
lua54 'yes'
use_experimental_fxv2_oal 'yes'