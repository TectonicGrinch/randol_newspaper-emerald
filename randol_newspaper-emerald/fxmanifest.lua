fx_version 'cerulean'
game 'gta5'

author 'Randol'
description 'Newspaper Delivery Job with Progression System'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared.lua'
}

client_scripts {
    'bridge/client.lua',
    'cl_delivery.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'sv_config.lua',
    'sv_delivery.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}