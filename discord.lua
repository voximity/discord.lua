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
local events = require("discord.events")(class)

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
		doerror = function() error(tostring(err)) return nil, err end,
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


-- setup classes

class.define "Bot" {
	ready = false,
	token = "",
	client = 0,
	id = "",
	_heartbeat_interval = 0,
	_last_seq = 0,
	events = {},
	servers = {};

	on = function(self, event_name, event_action)
		if not self.events[event_name] then self.events[event_name] = {} end
		table.insert(self.events[event_name], event_action)
	end,
	event = function(self, event_name, ...)
		for _, ev in next, self.events[event_name] do
			ev(...)
		end
	end,
	get_user = function(self, id)
		local obj, res, stat, cont = self.client:request({endpoints.user, id}, "GET")
		if stat == 401 then
			return nil, "401: Unauthorized"
		elseif stat == 403 then
			return nil, "403: Forbidden"
		elseif stat == 200 then
			local obj = json.decode(obj)
			local user = class.new "User"
			user.id = obj.id
			user.username = obj.username
			user.discriminator = obj.discriminator
			return user, nil
		else
			return nil, tostring(stat) .. ": Unknown"
		end
	end,
	send = function(self, channel_id, text, tts)
		local text = tostring(text)
		if #text >= 2000 then return false end
		self.client:request({endpoints.channel, channel_id, "messages"}, "POST", {content = text, tts = tts or false})
		return true, nil
	end,
	type = function(self, channel_id)
		self.client:request(endpoints.channel:gsub("CHANNEL_ID", channel_id) .. "/typing", "POST", {})
	end,
	_update = function(self)
		local message, opcode = self.client.wclient:receive()
		if message ~= nil and opcode == 1 then
			local data = json.decode(message)
			self._last_seq = data.s
			if events[data.t] then
				events[data.t](self.client.wclient, self, data.d, message)
			else
				print("Unhandled payload: " .. data.t .. " [ignore]")
			end
		end
		spawn(function() self._update(self) end)
	end,
	_heartbeat = function(self, nowait)
		if not nowait then wait(self._heartbeat_interval / 1000) else wait(1) end
		local hbo, hbe = self.client:send{op = 1, d = self._last_seq}
		if not hbo then
			spawn(function()
				self:_heartbeat(true)
			end)
		else
			spawn(function()
				self:_heartbeat()
			end)
		end
	end,
	connect = function(self, token)
		self.token = token
		self.client = class.new "BotClient"
		self.client.wclient = websocket.client.new()
		self.client.token = self.token
		shared.current_bot = self

		local conn = private.do_(self.client.wclient:connect(private.get_gateway(), "wss", {mode = "client", protocol = "sslv23"}))
		if not conn.ok then return conn.doerror() end

		local identify = private.identify(self.token)
		local ident = private.do_(self.client:send{op = 2, d = identify})
		if not ident.ok then return ident.doerror() end

		spawn(function() self._update(self) end)
	end
}




class.define "BotClient" {
	wclient = 0,
	token = 0,

	request = function(self, url, method, sourcejson)
		if type(url) == "table" then url = table.concat(url, "/") end
		local out = {}
		local params = {
			url = url,
			sink = ltn12.sink.table(out),
			headers = {
				["Authorization"] = self.token
			}
		}
		if method then
			params.method = method
		end
		if sourcejson then
			if type(sourcejson) == "table" then
				sourcejson = json.encode(sourcejson)
			end
			params.source = ltn12.source.string(sourcejson)
			params.headers["Content-Type"] = "application/json"
			params.headers["Content-Length"] = #sourcejson
		end
		local result, status, content = https.request(params)
		return (out[1] or nil), result, status, content
	end,

	send = function(self, thej)
		return self.wclient:send(json.encode(thej), 1)
	end,

	check_response = function(self, code)
		if code == 200 then
			return true, nil
		elseif code == 201 then
			return true, nil
		elseif code == 304 then
			return true, "The entity was not modified"
		elseif code == 400 then
			return false, "Improper entity format"
		elseif code == 401 then
			return false, "Unauthorized (no token)"
		elseif code == 403 then
			return false, "Forbidden (no access)"
		elseif code == 404 then
			return false, "Not found"
		elseif code == 405 then
			return false, "Method not allowed (use https)"
		elseif code == 429 then
			return false, "Rate-limited"
		elseif code == 502 then
			return false, "Gateway unavailable (wait and try later)"
		elseif code == 501 or code > 502 then
			return false, "Server error"
		else
			return false, "Unknown"
		end
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
		local rj = shared.current_bot.client:request({endpoints.channel, self.channel_id}, "GET")
		rj = json.decode(rj)
		local channel = class.new "Channel"
		self._channel = channel
		if rj.is_private then
			channel.is_private = true
			channel.name = "@" .. rj.recipient.username
			channel.id = rj.id
			channel.server_id = ""
			channel.type = "private"
			channel.topic = ""
			channel.position = -1
			channel.bitrate = -1
		else
			channel.is_private = false
			channel.type = rj.type
			channel.name = rj.name
			channel.server_id = rj.guild_id
			channel.topic = rj.topic
			channel.id = rj.id
			channel.position = rj.position
			channel.bitrate = rj.type == "voice" and rj.bitrate or -1
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
	discriminator = "",

	mention = function(self)
		return "<@" .. self.id .. ">"
	end,
	send = function(self, text)
		if #text >= 2000 then return nil, false end
		local obj, resp, stat, cont = shared.current_bot.client:request({endpoints.user, "@me/channels"}, "POST", {
			recipient_id = self.id
		})
		local ok, err = shared.current_bot.client:check_response(stat)
		if not ok then return ok, err end
		local jsono = json.decode(obj)
		return shared.current_bot:send(jsono.id, text)
	end,
}
class.define "Channel" {
	name = "",
	id = "",
	server_id = "",
	is_private = false,
	type = "",
	topic = "",
	position = 0,
	bitrate = 0,

	send = function(self, text, tts)
		return shared.current_bot:send(self.id, text, tts)
	end,
	modify = function(self, options)
		if self.is_private then error("attempt to modify a private channel") end
		local options = options or {}
		options.name = options.name or self.name
		options.position = options.position or self.position
		options.topic = options.topic or self.topic
		options.bitrate = options.bitrate or self.bitrate
		local no = {}
		no.name = options.name
		no.position = options.position
		if self.type == "text" then
			no.topic = options.topic
		else
			no.bitrate = options.bitrate
		end
		local _, res, stat, cont = shared.current_bot.client:request({endpoints.channel, self.id}, "PATCH", no)
		return shared.current_bot.client:check_response(stat)
	end,
	delete = function(self)
		if self.is_private then error("attempt to delete a private channel") end
		local _, res, stat, cont = shared.current_bot.client:request({endpoints.channel, self.id}, "DELETE")
		return shared.current_bot.client:checkresponse(stat)
	end,
}
class.define "Member" {
	deaf = false,
	mute = false,
	user = {},
	joined_at = "",
	roles = {},
	nickname = "",
	username = ""
}
class.define "Server" {
	name = "",
	id = "",
	large = false,
	channels = {},
	roles = {},
	members = {},
}
class.define "Role" {
	name = "",
	position = 0,
	id = "",
	permissions = 0,
	color = 0
}

shared.current_bot = {}
shared.new = function()
	local bot = class.new "Bot"
	return bot
end
return shared
