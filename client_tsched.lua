-- tsched extension for lua-websockets

local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local function InProgress(err)
    return  (err == "Operation already in progress") or
            (err == "timeout") or
            (err == "wantread") or -- ?
            (err == "wantwrite") -- ?
end

local new = function()
  local self = {}
  
  self.sock_connect = function(self,host,port)
    self.sock = socket.tcp()
    self.sock:settimeout(0)

    local ret, err
    local tried_before = false
    --print("CONNECT START")
    yield(function()
        socket.sleep(0.01) -- luajit2faste4socket
        ret, err = self.sock:connect(host, port)

        if (ret or not InProgress(err)) then
            if ((not ret) and (err == "already connected" and tried_before)) then
                ret = 1
                err = nil
            end

            return true
        end

        tried_before = tried_before or true
        return false
    end)
    --print("CONNECT END")
    if err then
      self.sock:close()
      return nil,err
    end
  end
  
  self.sock_send = function(self, data, i, j)
    self.sock:settimeout(0)
    local ret, err, index
    --print("SEND START")
    yield(function()
      socket.sleep(0.01) -- luajit2faste4socket
      ret, err, index = self.sock:send(data, i, j)

      if (ret or not InProgress(err)) then
          return true
      end

      return false
    end)
    --print("SEND END")
    return ret, err, index
  end
  
  self.sock_receive = function(self, pattern, prefix)
    self.sock:settimeout(0)

    local s, err

    yield(function()
        socket.sleep(0.01) -- luajit2faste4socket

        s, err = self.sock:receive(pattern, prefix)
        if (s or not InProgress(err)) then
            return true
        end 

        return false
    end)

    return s, err
  end
  
  self.sock_close = function(self)
    --self.sock:shutdown() Causes errors?
    self.sock:close()
  end
  
  self = sync.extend(self)
  return self
end

return new
