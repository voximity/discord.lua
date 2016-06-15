local endpoints = {}
endpoints.self = "https://discordapp.com/api"
endpoints.gateway = endpoints.self .. "/gateway"
endpoints.send = endpoints.self .. "/channels/CHANNEL_ID/messages"
endpoints.channel = endpoints.self .. "/channels/CHANNEL_ID"
return endpoints
