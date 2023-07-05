
local Class = require(script.Parent.Class)
local Promise = require(script.Parent.Packages.Promise)
local AquaNetwork = require(script.Parent.AquaNetwork)
local Templates = require(script.Parent.Templates)
local AquaScheduler = require(script.Parent.AquaScheduler)

type AquaOptions = {
    Middleware: {
        Inbound: {}?,
        Outbound: {}?
    }?,
    IgnoreUnderscoreInClient: boolean?,
    UsePromise: boolean?
}


local AQUA_CONFIGURATION_TAG = newproxy()
local AQUA_EVENT_MARKER = newproxy()

local AquaStarted = false
local AquaHosts = {}

local function getN(tbl: table)
    local n = #tbl
    for j in pairs(tbl) do
        if type(j) ~= "number" then
             n += 1
        end
    end
    return n
end

local AquaServer = {}
AquaServer.EventMarker = AQUA_EVENT_MARKER
AquaServer[AQUA_CONFIGURATION_TAG] = { Middleware = {}, UsePromise = true }
function AquaServer.CreateHost(hostProps: { Name: string, Client: {}? })
    assert(type(hostProps) == "table", "Argument 1 must be a table")
    assert(#hostProps.Name > 0, "Argument 1 cannot be an empty string")
    assert(not AquaStarted, "Aqua.CreateHost() can only be run before Aqua.Hydrate() is called! (SERVER)")
    local class = Class { Client = hostProps.Client or {}, Name = hostProps.Name }
    AquaHosts[hostProps.Name] = class
    Templates.regNet(class)
    Templates.regSched(class)
    return class
end

function AquaServer.GetHost(hostName: string)
    assert(#hostName > 0, "Argument 1 cannot be an empty string")
    assert(AquaStarted, "Can only call Aqua.GetHost() after Aqua.Hydrate() is ran (SERVER)")
    return assert(AquaHosts[hostName], "Could not find host '" .. hostName .. "'")
end

function AquaServer.All(folder: Folder)
    for _, pot in ipairs(folder:GetChildren()) do
        local ok, srcOrErr = pcall(require, pot)
        if not ok then
            warn(srcOrErr)
        end
    end
end

function AquaServer.Hydrate(aquaOptions: AquaOptions?)
    return Promise.new(function()
        if AquaStarted then
            error("Cannot start Aqua when it has already been started!", 2)
        end
        AquaStarted = true
    
        if type(aquaOptions) == "table" then
            local configuration = AquaServer[AQUA_CONFIGURATION_TAG]
            if type(aquaOptions.Middleware) == "table" then
                configuration.Middleware = aquaOptions.Middleware
            end
    
            if type(aquaOptions.UsePromise) == "boolean" then
                configuration.UsePromise = aquaOptions.UsePromise
            end
        end
        
        local REMOTES_FOLDER = Instance.new("Folder")
        REMOTES_FOLDER.Name = "Remotes"
        
        local initHosts = {}
        for name, rawHost in pairs(AquaHosts) do
            table.insert(initHosts, Promise.new(function()
                local host = rawHost.new()
                AquaHosts[name] = host
                local scheduler = AquaScheduler.new(host)
                host:__registerScheduler(scheduler)
                coroutine.wrap(function()
                    xpcall(function()
                        if getN(host.Client) > 0 then
                            local net = AquaNetwork.new(name, REMOTES_FOLDER, AquaServer[AQUA_CONFIGURATION_TAG].Middleware)
                            for key, value in pairs(host.Client) do
                                if key:sub(1, 1) == "_" and aquaOptions.IgnoreUnderscoreInClient then
                                    warn("A network object (" .. key .. ") was assumed to be a private-ized method/function, consider renaming and relocating the said method outside of the '.Client' table in the future!")
                                end

                                if value == AQUA_EVENT_MARKER then
                                    host.Client[key] = net:fromEvent(key)
                                elseif type(value) == "function" then
                                    host.Client[key] = net:fromMethod(host.Client, key)
                                end
                            end
                            host.Client.Server = host
                            host:__registerNet(net)
                        end
        
                        if host.__start then
                            host:__start()
                        end
                    end, error)
                end)()
    
                return true
            end))
        end
        Promise.all(initHosts)
        REMOTES_FOLDER.Parent = script.Parent
    end)
end

return AquaServer