--[[

	discord.lua class system

]]

local class = {}
local classes = {}
class.define = function(name)
	if (function() for i,v in next, classes do if i == name then return true end end return false end)() then error("attempt to replace existing class") end
	return function(meta)
		classes[name] = meta
	end
end
class.new = function(name)
	if not (function() for i,v in next, classes do if i == name then return v end end return false end)() then error("attempt to create a nonexistant class") end
	local meta = (function() for i,v in next, classes do if i == name then return v end end return false end)()
	local newmeta = {}
	for i,v in next, meta do newmeta[i] = v end
	setmetatable(newmeta, {
		__index = function(t,i) error("attempt to access nonexistant property of class " .. name .. ": " .. tostring(i)) end;
		__newindex = function(t,i) error("attempt to set nonexistant property of class " .. name .. ": " .. tostring(i)) end;
		__len = function(t) error("attempt to get length of class " .. name) end;
	})
	return newmeta
end
return class
