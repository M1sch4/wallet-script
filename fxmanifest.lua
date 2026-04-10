fx_version 'cerulean'
game 'gta5'

author 'M1scha'
description 'Qbox Wallet & Lizenzsystem'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/fahrzeugpapier.png'
} 