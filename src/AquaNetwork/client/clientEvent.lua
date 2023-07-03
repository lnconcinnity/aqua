
local Class = require(script.Parent.Parent.Parent.Class)
local Condition = require(script.Parent.Parent.Parent.Condition)
local Signal = require(script.Parent.Parent.Parent.Packages.Signal)

type fn = (...any) -> (...any)

local ClientEvent = Class()
function ClientEvent:__init(re: RemoteEvent, inbounds: {fn}?, outbounds: {fn}?)
    self._re = re

    self.__hasOutbounds = Condition(type(outbounds) == "table" and #outbounds > 0, function()
		self._outbounds = outbounds
	end)
    self.__hasInbounds = Condition(type(inbounds) == "table" and #inbounds > 0, function()
        self._signal = Signal.new()
        self._re.OnClientEvent:Connect(function(...)
			local args = table.pack(...)
			for _, fn in ipairs(inbounds) do
				local result = table.pack(fn(args))
				if not result[1] then
					return
				end
				args.n = #args
			end
			self._signal:Fire(table.unpack(args, 1, args.n))
        end)
    end)
    self._directConnect = not self.__hasInbounds
end

function ClientEvent:_processOutboundMiddleware(...: any)
	if not self.__hasOutbounds then
		return ...
	end
	local args = table.pack(...)
	for _, fn in ipairs(self._outbounds) do
		local result = table.pack(fn(args))
		if not result[1] then
			return table.unpack(result, 2, result.n)
		end
		args.n = #args
	end
	return table.unpack(args, 1, args.n)
end

function ClientEvent:Connect(callback)
    if self._directConnect then
        return self._re.OnClientEvent:Connect(callback)
    else
        return self._signal:Connect(callback)
    end
end

function ClientEvent:Fire(...)
    self._re:FireServer(self:_processOutboundMiddleware(...))
end

return ClientEvent