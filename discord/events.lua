return function(class)

	return {
		["READY"] = function(client, bot, data, raw)
			bot._heartbeat_interval = data.heartbeat_interval
			bot:event("ready")
			spawn(function() bot:_heartbeat() end)
		end,
		["MESSAGE_CREATE"] = function(client, bot, data, raw)
			local message = class.new "Message"
			message.content = data.content
			message.id = data.id
			message.channel_id = data.channel_id
			message.author = class.new "User"
			message.author.username = data.author.username
			message.author.id = data.author.id
			bot:event("message", message)
		end,
		["TYPING_START"] = function(client, bot, data, raw)
			print(raw)
		end,
		["PRESENCE_UPDATE"] = function(client, bot, data, raw)
			print(raw)
		end,
	}

end
