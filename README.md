# ABANDONED
This library is abandoned. It has not been worked on for a long time and probably doesn't even support Discord's latest API changes. You're free to play around if you wish, but I recommend you check out my newer library for Dart named [Dartsicord](https://github.com/voximity/dartsicord).

# discord.lua
Discord library written in only Luajit

Discord.lua is a Discord library written entirely in Luajit. This means no Luvit, no async i/o, just pure Lua. This comes with its
upsides and downsides. On the upside, you have more control over what is happening and more things are guaranteed to be asynchronous. On the downside, you cannot guarantee the efficiency of async I/O. Discord.lua is in a VERY early stage and shouldn't be used to host big bots yet. It can do simple text-channel tasks currently but nothing much else.

## Installation
Requirements: Luajit, lua-websockets, luasec (must be built) and lua-sockets.

1. Make sure all requirements are placed accordingly and the %LUA_PATH% has successfully been set.

2. Download the discord.lua repository. Place the "discord" folder, the "discord.lua" file and "schedule.lua" directly into your %LUA_PATH%. Then put the "client_tsched.lua" file in the websocket folder.

3. Take an example from the examples directory and place it somewhere, preferably in your %LUA_PATH%.

4. Finally, to run your newly created bot, open a terminal where your scheduler is and type "lua[jit] schedule.lua PATH-TO-BOT.lua"

## Issues
Please put your issues in the Issues located in the repo. A wiki will be coming soon, but for now rely off of examples.
