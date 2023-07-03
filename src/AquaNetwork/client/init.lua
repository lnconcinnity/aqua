local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(script.Parent.Parent.Class)
local ClientEvent = require(script.clientEvent)
local Promise = require(script.Parent.Parent.Packages.Promise)
local Signal = require(script.Parent.Parent.Packages.Signal)

local ClientNet = Class()
function ClientNet:__init(name: string, from: Instance?, middleware: {}?, usePromise: boolean?)
    assert(#name > 0, "Argument 1 cannot be an emtpy string")
    local folder = assert((from or ReplicatedStorage):FindFirstChild(name), "Could not find remotes '" .. name .. "' from Argument 2")
    local reFolder = folder:WaitForChild("RE")
    local rfFolder = folder:WaitForChild("RF")

    self._usePromise = usePromise
    self._outbounds = middleware and middleware.Outbind or nil
    self._inbounds = middleware and middleware.Inbound or nil
    
    self._remoteLoadedSignals = {}

    for _, re in ipairs(reFolder:GetChildren()) do
        local event = ClientEvent.new(re, self._inbounds, self._outbounds)
        self:GetRemoteLoaded(re.Name):Fire(event)
        self[re.Name] = event
    end

    for _, rf in ipairs(rfFolder:GetChildren()) do
        local method = self:_wrapMethod(rf)
        self:GetRemoteLoaded(rf.Name):Fire(method)
        self[rf.Name] = method
    end
end

function ClientNet:GetRemoteLoaded(key)
    if self._remoteLoadedSignals[key] then return self._remoteLoadedSignals[key] end
    local signal = Signal.new()
    self._remoteLoadedSignals[key] = signal
    return signal
end

function ClientNet:_wrapMethod(rf)
    local hasInbound = type(self._inbounds) == "table" and #self._inbounds > 0
    local hasOutbound = type(self._outbounds) == "table" and #self._outbounds > 0
    local function processOutbound(args)
        for _, fn in ipairs(self._outbounds) do
            local result = table.pack(fn(args))
            if not result[1] then
                return table.unpack(result, 2, result.n)
            end
            args.n = #args
        end
        return table.unpack(args, 1, args.n)
    end
    if hasInbound then
        if self._usePromise then
            return function(...)
                local args = table.pack(...)
                return Promise.new(function(resolve, reject)
                    local success, results = pcall(function()
                        if hasOutbound then
                            return table.pack(rf:InvokeServer(processOutbound(args)))
                        else
                            return table.pack(rf:InvokeServer(table.unpack(args, 2, args.n)))
                        end
                    end)
                    if success then
                        for _, fn in ipairs(self._inbounds) do
                            local result = table.pack(fn(results))
                            if not result[1] then
                                return table.unpack(result, 2, result.n)
                            end
                            results.n = #results
                        end
                        resolve(table.unpack(results, 1, results.n))
                    else
                        reject(results)
                    end
                end)
            end
        else
            return function(...)
                local results
                if hasOutbound then
                    results = table.pack(rf:InvokeServer(processOutbound(table.pack(...))))
                else
                    results = table.pack(rf:InvokeServer(...))
                end
                for _, fn in ipairs(results) do
                    local result = table.pack(fn(results))
                    if not result[1] then
                        return table.unpack(result, 2, result.n)
                    end
                    results.n = #results
                end
                return table.unpack(results, 1, results.n)
            end
        end
    else
        if self._usePromise then
            return function(...)
                local args = table.pack(...)
                return Promise.new(function(resolve, reject)
                    local success, results = pcall(function()
                        if hasOutbound then
                            return table.pack(rf:InvokeServer(processOutbound(args)))
                        else
                            return table.pack(rf:InvokeServer(table.unpack(args, 2, args.n)))
                        end
                    end)
                    if success then
                        resolve(table.unpack(results, 1, results.n))
                    else
                        reject(results)
                    end
                end)
            end
        else
            if hasOutbound then
                return function(...)
                    return rf:InvokeServer(processOutbound(table.pack(...)))
                end
            else
                return function(...)
                    return rf:InvokeServer(...)
                end
            end
        end
    end
end

return ClientNet