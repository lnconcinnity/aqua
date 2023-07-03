local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(script.Parent.Parent.Class)
local ServerEvent = require(script.serverEvent)

local function getFolder(key: string, from: Instance?)
    from = from or ReplicatedStorage

    local container = from:FindFirstChild(key)
    if not container then
        container = Instance.new("Folder")
        container.Name = key
        container.Parent = from
    end
    return container
end

local ServerNet = Class()
function ServerNet:__init(name: string, parent: Instance?, middleware: {}?)
    assert(#name > 0, "Argument 1 cannot be an empty string")
    self._folder = getFolder(name, parent)
    self._reFolder = getFolder('RE', self._folder)
    self._rfFolder = getFolder('RF', self._folder)

    self._outbounds = middleware and middleware.Outbind or nil
    self._inbounds = middleware and middleware.Inbound or nil
end

function ServerNet:_bindFunction(methodName: string, callback: (...any) -> any)
    local rf = Instance.new("RemoteFunction")
    local function processOutbound(player, ...)
		local args = table.pack(...)
		for _, fn in ipairs(self._outbounds) do
			local result = table.pack(fn(player, args))
			if not result[1] then
				return table.unpack(result, 2, result.n)
			end
			args.n = #args
		end
		return table.unpack(args, 1, args.n)
	end

	local hasInbound = self._inbounds and #self._inbounds > 0
	local hasOutbound = self._outbounds and #self._outbounds > 0

    if hasInbound and hasOutbound then
        local function onServerInvoke(player, ...)
			local args = table.pack(...)
			for _, fn in ipairs(self._inbounds) do
				local result = table.pack(fn(player, args))
				if not result[1] then
					return table.unpack(result, 2, result.n)
				end
				args.n = #args
			end
			return processOutbound(player, callback(player, table.unpack(args, 1, args.n)))
		end
        rf.OnServerInvoke = onServerInvoke
    elseif hasInbound then
        local function onServerInvoke(player, ...)
			local args = table.pack(...)
			for _, fn in ipairs(self._inbounds) do
				local result = table.pack(fn(player, args))
				if not result[1] then
					return table.unpack(result, 2, result.n)
				end
				args.n = #args
			end
			return callback(player, table.unpack(args, 1, args.n))
		end
        rf.OnServerInvoke = onServerInvoke
    elseif hasOutbound then
         local function onServerInvoke(player, ...)
            return processOutbound(player, callback(player, ...))
        end
        rf.OnServerInvoke = onServerInvoke
    else
        rf.OnServerInvoke = callback
    end

    rf.Name = methodName
    rf.Parent = self._rfFolder
    return rf
end

function ServerNet:fromEvent(eventName: string)
    local event = ServerEvent.new(eventName, self._reFolder, self._inbounds, self._outbounds)
    return event
end

function ServerNet:fromMethod(source: table, methodName: string)
    assert(type(source) == "table", "Argument 1 must be a table")
    local callback = assert(source[methodName], "Could not find '" .. methodName .. "' from source")
    return self:_bindFunction(methodName, function(...)
        callback(source, ...)
    end).OnServerInvoke
end

return ServerNet