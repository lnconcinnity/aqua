local Players = game:GetService("Players")

local Class = require(script.Parent.Parent.Parent.Class)
local Signal = require(script.Parent.Parent.Parent.Packages.Signal)
local Condition = require(script.Parent.Parent.Parent.Condition)

type fn = (...any) -> (...any)

local ServerEvent = Class()
function ServerEvent:__init(eventName: string, folder: Folder, inbounds: {fn}?, outbounds: {fn}?)
    assert(#eventName > 0, "Argument 1 cannot be an empty string")
    assert(typeof(folder) == "Instance", "Argument 2 must be an instance")
    self._re = Instance.new("RemoteEvent")
    self._re.Name = eventName
    self._re.Parent = folder

    self.__hasOutbounds = Condition(type(outbounds) == "table" and #outbounds > 0, function()
        self._outbounds = outbounds
    end)
    
    self.__hasInbounds = Condition(type(inbounds) == "table" and #inbounds > 0, function()
        self._signal = Signal.new()
        self._re.OnServerEvent:Connect(function(player, ...)
			local args = table.pack(...)
			for _, fn in ipairs(inbounds) do
				local result = table.pack(fn(player, args))
				if not result[1] then
					return
				end
				args.n = #args
			end
			self._signal:Fire(player, table.unpack(args, 1, args.n))
        end)
    end)
    self._directConnect = not self.__hasInbounds
end

function ServerEvent:_processOutboundMiddleware(player: Player?, ...: any)
	if not self.__hasOutbounds then
		return ...
	end
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

function ServerEvent:Connect(callback)
    if self._directConnect then
        return self._re.OnServerEvent:Connect(callback)
    else
        return self._signal:Connect(callback)
    end
end

function ServerEvent:Fire(player: Player, ...)
    assert(typeof(player) == "Instance" and player:IsA("Player"), "Expected a player instance for Argument 1")
    self._re:FireClient(player, self:_processOutboundMiddleware(player, ...))
end

function ServerEvent:FirePredicate(predicate: (player: Player) -> boolean, ...)
    for _, player in ipairs(Players:GetPlayers()) do
        if predicate(player) then
            self:Fire(player, ...)
        end
    end
end

function ServerEvent:FireFor(players: {Player}, ...)
    for _, player in ipairs(players) do
        self:Fire(player, ...)
    end
end

function ServerEvent:FireExcept(player: Player, ...)
    self:FirePredicate(function(other)
        return player ~= other
    end, ...)
end

function ServerEvent:Destroy()
    self._re:Destroy()
    self._re = nil

    if self._signal then
        self._signal:Destroy()
        self._signal = nil
    end
end

return ServerEvent