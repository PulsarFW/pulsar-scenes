fx_version 'cerulean'
games({ 'gta5' }) -- 'gta5' for GTAv / 'rdr3' for Red Dead 2, 'gta5','rdr3' for both

name 'Pulsar Scenes'
description 'World-space text and label rendering'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.0'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_scenes'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

client_scripts({
	'config/**/*.lua',
	'client/**/*.lua',
})

server_scripts({
	'server/**/*.lua',
})

shared_scripts({
	'shared/**/*.lua',
})

lua54 'yes'