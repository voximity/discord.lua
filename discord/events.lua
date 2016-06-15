local json = require("cjson")
return function(class)

	return {
		["READY"] = function(client, bot, data, raw)
			bot._heartbeat_interval = data.heartbeat_interval
			bot.id = data.user.id
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
		["GUILD_CREATE"] = function(client, bot, data, raw)
			local server = class.new "Server"
			server.name = data.name
			server.id = data.id
			server.large = data.large
			server.channels = {}
			server.roles = {}
			server.members = {}
			for i,v in next, data.channels do
				local channel = class.new "Channel"
				channel.name = v.name
				channel.type = v.type
				channel.bitrate = v.bitrate
				channel.server_id = data.id
				channel.is_private = false
				channel.topic = v.topic
				channel.position = v.position
				table.insert(server.channels, v)
			end
			for i,v in next, data.roles do
				local role = class.new "Role"
				role.name = v.name
				role.position = v.position
				role.color = v.color
				role.permissions = v.permissions
				role.id = v.id
				table.insert(server.roles, role)
			end
			for i,v in next, data.members do
				local member = class.new "Member"
				member.username = v.user.username
				member.nickname = v.nick
				member.roles = v.roles
				member.joined_at = v.joined_at
				member.deaf = v.deaf
				member.mute = v.mute
				member.user = class.new "User"
				member.user.username = member.username
				member.user.id = v.user.id
				member.user.discriminator = v.user.discriminator
				table.insert(server.members, member)
			end
			table.sort(server.roles, function(a,b) return a.position < b.position end)
			table.sort(server.channels, function(a, b) return a.position < b.position end)
			table.insert(bot.servers, server)
			bot:event("create server", server)
		end,
	}

end
