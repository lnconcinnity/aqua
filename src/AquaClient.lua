
local Class = require(script.Parent.Class)
local Promise = require(script.Parent.Packages.Promise)
local AquaNetwork = require(script.Parent.AquaNetwork)

type AquaOptions = {
    Middleware: {
        Inbound: {}?,
        Outbound: {}?
    }?,
}

type fnType = (...any) -> (...any)

local AQUA_POTS_CONTAINER = newproxy()
local AQUA_POT_IDENTIFIER = newproxy()
local AQUA_CONFIGURATION_TAG = newproxy()

local CANNOT_FIND_POT = "Could not find hydrated pot '%s'. Are you sure it exists; or have you yet to re-run Aqua.Hydrate() to initialize unhydrated pots?"

local REMOTES_FOLDER = script.Parent:WaitForChild("Remotes")

local AquaStarted = false
local UnhydratedPots = {}
local AquaHosts = {}

local AquaClient = {}
AquaClient[AQUA_CONFIGURATION_TAG] = { Middleware = {}, UsePromise = true }
AquaClient[AQUA_POTS_CONTAINER] = {}
function AquaClient.CreatePot(potName: string)
    assert(#potName > 0, "Argument 1 cannot be an empty string")
    local wrapper = {}
    local class = Class { Name = potName }
    class[AQUA_POT_IDENTIFIER] = potName
    setmetatable(class, {__index = wrapper})
    table.insert(UnhydratedPots, class)
    return wrapper
end

function AquaClient.TerminatePot(potName: string)
    assert(#potName > 0, "Argument 1 cannot be an empty string")
    local pot = AquaClient.GetPot(potName)
    if pot.__terminate then
        pot:__terminate()
    end
    AquaClient[AQUA_POTS_CONTAINER][potName] = nil
    return pot
end

function AquaClient.GetPot(potName: string)
    assert(#potName > 0, "Argument 1 cannot be an empty string")
    return assert(AquaClient[AQUA_POTS_CONTAINER][potName], string.format(CANNOT_FIND_POT, potName))
end

function AquaClient.GetHost(hostName: string)
    assert(AquaStarted, "Can only call Aqua.GetHost() after the initial Aqua.Hydrate() was ran (CLIENT)")
    if AquaHosts[hostName] then return AquaHosts[hostName] end
    local host = AquaNetwork.new(hostName, REMOTES_FOLDER, AquaClient[AQUA_CONFIGURATION_TAG].Middleware,AquaClient[AQUA_CONFIGURATION_TAG].UsePromise)
    return host
end

function AquaClient.All(folder: Folder)
    for _, pot in ipairs(folder:GetChildren()) do
        local ok, srcOrErr = pcall(require, pot)
        if not ok then
            warn(srcOrErr)
        end
    end
end

function AquaClient.Hydrate(aquaOptions: table)
    if not AquaStarted then
        AquaStarted = true
        if type(aquaOptions) == "table" then
            local configuration = AquaClient[AQUA_CONFIGURATION_TAG]
            if type(aquaOptions.Middleware) == "table" then
                configuration.Middleware = aquaOptions.Middleware
            end

            if type(aquaOptions.UsePromise) == "boolean" then
                configuration.UsePromise = aquaOptions.UsePromise
            end
        end
    end
    
    return Promise.new(function()
        local initPots = {}
        while #UnhydratedPots > 0 do
            local unhydrated = table.remove(UnhydratedPots, #UnhydratedPots)
            table.insert(initPots, Promise.new(function()
                local pot = unhydrated.new()
                if pot.__start then
                    coroutine.wrap(function()
                        xpcall(function()
                            pot:__start()
                        end, error)
                    end)()
                end
                AquaClient[AQUA_POTS_CONTAINER][pot[AQUA_POT_IDENTIFIER]] = pot
                return true
            end))
        end
        Promise.all(initPots)
    end)
end

function AquaClient.Drought()
    for _, pot in pairs(AquaClient[AQUA_POTS_CONTAINER]) do
        if pot.__terminate then
            pot:__terminate()
        end
    end
    AquaClient[AQUA_POTS_CONTAINER] = {}
end

return AquaClient