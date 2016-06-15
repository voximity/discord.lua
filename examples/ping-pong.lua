discord = require("discord")
bot = discord.new()

bot:connect("<-- TOKEN -->")

bot:on("message", function(m)
	if m.content == "ping" then
		m:reply("pong!")
		--another way of doing this:
		--  m:get_channel():send(m.author:mention() .. ", pong!")
		--  bot:send(m.channel_id, m.author:mention() .. ", pong!")
	end
end)
bot:on("ready", function()
	print("I am now ready to receive actions!")
end)
