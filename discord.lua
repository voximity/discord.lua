--[[

	discord.lua core
	voximity


]]
-- requires
local class = require("discord.class")
local endpoints = require("discord.endpoints")
local websocket = require("websocket")
local https = require("ssl.https")
local json = require("cjson")
local ltn12 = require("ltn12")

-- initial definition
local shared = {}
local private = {}

private.get_and_decode = function(url)
	local result, status, content = https.request(url)
	return json.decode(result)
end

private.gateway = "?"
private.get_gateway = function(override) -- Cacheing gateway and only retrieving it if it is lost.
	if override then private.gateway = private.get_and_decode(endpoints.gateway).url end
	if private.gateway ~= "?" then
		return private.gateway
	else
		return private.get_gateway(true)
	end
end

private.do_ = function(ok, err, ...)
	return {
		ok = ok,
		error = err,
		err = err,
		doerror = function() error(err) return nil, err end,
		extra = {...}
	}
end

private.identify = function(token)
	return {
		token = token,
		properties = {
			["$os"] = "linux",
			["$browser"] = "discord.lua",
			["$device"] = "discord.lua",
			["$referrer"] = "",
			["$referring_domain"] = ""
		},
		compress = false,
		large_threshold = 100
	}
end

private.send = function(client, data)
	return private.do_(client:send(json.encode(data), 1))
end

private.handle_events = {
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

private.request = function(token, url, method, yayson)
	local resp_table = {}
	local result, status, content = https.request {
		url = url,
		method = method,
		source = yayson and ltn12.source.string(json.encode(yayson)) or nil,
		headers = {
			["Authorization"] = token,
			["Content-Type"] = "application/json",
			["Content-Length"] = string.len(json.encode(yayson))
		},
		sink = ltn12.sink.table(resp_table)
	}
	return resp_table[1] and json.decode(resp_table[1]) or true
end
private.getrequest = function(token, url, method, yayson)
	local resp_table = {}
	local result, status, content = https.request {
		url = url,
		headers = {
			["Authorization"] = token
		},
		sink = ltn12.sink.table(resp_table)
	}
	print(resp_table[1])
	return resp_table[1] and json.decode(resp_table[1]) or true
end


-- setup classes

class.define "Bot" {
	ready = false,
	token = "",
	client = 0,
	_heartbeat_interval = 0,
	_last_seq = 0,
	events = {
		["message"] = {},
		["ready"] = {}
	};

	on = function(self, event_name, event_action)
		table.insert(self.events[event_name], event_action)
	end,
	event = function(self, event_name, ...)
		for _, ev in next, self.events[event_name] do
			ev(...)
		end
	end,
	send = function(self, channel_id, text, tts)
		local text = tostring(text)
		if #text >= 2000 then return false end
		private.request(self.token, endpoints.send:gsub("CHANNEL_ID", channel_id), "POST", {content = text, tts = tts or false})
		return true
	end,
	_update = function(self)
		local message, opcode = self.client:receive()
		if message ~= nil and opcode == 1 then
			local data = json.decode(message)
			self._last_seq = data.s
			if private.handle_events[data.t] then
				private.handle_events[data.t](self.client, self, data.d, message)
			else
				print("Unhandled payload: " .. data.t .. " [ignore]")
			end
		else
			error("Lost connection to WSS server.")
		end
		spawn(function() self._update(self) end)
	end,
	_heartbeat = function(self)
		wait(self._heartbeat_interval / 1000)
		print("heartbeat")
		local hbsend = private.do_(private.send(self.client, {op = 1, d = self._last_seq}))
		if not hbsend.ok then return hbsend.doerror() else spawn(function() self._heartbeat(self) end) end
	end,
	connect = function(self, token)
		self.token = token
		shared.current_bot = self

		self.client = websocket.client.new()
		local conn = private.do_(self.client:connect(private.get_gateway(), "wss", {mode = "client", protocol = "sslv23"}))
		if not conn.ok then return conn.doerror() end

		local identify = private.identify(self.token)
		local ident = private.do_(private.send(self.client, {op = 2, d = identify}))
		if not ident.ok then return ident.doerror() end

		spawn(function() self._update(self) end)
	end
}





class.define "Message" {
	content = "Message content",
	id = "Message ID",
	channel_id = "Channel ID",
	author = {},
	_channel = "non",

	get_channel = function(self)
		if self._channel ~= "non" then return self._channel end
		local rj = private.getrequest(shared.current_bot.token, endpoints.channel:gsub("CHANNEL_ID", self.channel_id))
		local channel = class.new "Channel"
		self._channel = channel
		if rj.is_private then
			channel.is_private = true
			channel.name = "@" .. rj.recipient.username
			channel.id = rj.id
			channel.server_id = ""
			channel.type = "private"
			channel.topic = ""
		else
			channel.is_private = false
			channel.type = rj.type
			channel.name = rj.name
			channel.server_id = rj.guild_id
			channel.topic = rj.topic
			channel.id = rj.id
		end
		return channel
	end,
	reply = function(self, text, tts)
		return shared.current_bot:send(self.channel_id, self.author:mention() .. ", " .. text, tts)
	end
}
class.define "User" {
	username = "Username",
	id = "ID",

	mention = function(self)
		return "<@" .. self.id .. ">"
	end,
}
class.define "Channel" {
	name = "",
	id = "",
	server_id = "",
	is_private = false,
	type = "",
	topic = "",

	send = function(self, text, tts)
		return shared.current_bot:send(self.id, text, tts)
	end,
}
class.define "Server" {

}

shared.current_bot = {}
shared.new = function()
	local bot = class.new "Bot"
	return bot
end
return shared
