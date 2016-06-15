local endpoints = {}
endpoints.self = "https://discordapp.com/api"
endpoints.gateway = endpoints.self .. "/gateway"
endpoints.channel = endpoints.self .. "/channels"
endpoints.user = endpoints.self .. "/users"
return endpoints
