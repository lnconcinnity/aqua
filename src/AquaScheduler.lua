local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Class = require(script.Parent.Class)

local IS_SERVER = RunService:IsServer()

local AquaScheduler = Class {}
function AquaScheduler:__init(source)
    self._cleanupTasks = {}
    self.__priority = if not IS_SERVER then source.RenderPriorityValue or 999 else nil
    self.__source__ = source
end

function AquaScheduler:onRenderStepped(fn: (dt: number) -> (), overridePriority: number?)
    assert(not IS_SERVER, "Scheduler:onRenderStepped() can only")
    if overridePriority or (type(self.renderPriority) == "number" and self.renderPriority > 0) then
        local id = HttpService:GenerateGUID(false)
        RunService:BindToRenderStep(id, overridePriority or self.renderPriority, self.__source__:__registerCHandler__(fn))
        table.insert(self.cleanupTasks, function()
            RunService:UnbindFromRenderStep(id)
        end)
    else
        table.insert(self.cleanupTasks, self.__source__:__wrapSignal(RunService.RenderStepped, fn))
    end
end

function AquaScheduler:onHeartbeat(fn: (dt: number) -> ())
    table.insert(self.cleanupTasks, self.__source__:__wrapSignal(RunService.Heartbeat, fn))
end

function AquaScheduler:onStepped(fn: (t: number, dt: number) -> ())
    table.insert(self.cleanupTasks, self.__source__:__wrapSignal(RunService.Stepped, fn))
end

function AquaScheduler:cleanup()
    while #self.cleanupTasks > 0 do
        local cleanup = self.cleanupTasks[#self.cleanupTasks]
        self.cleanupTasks[#self.cleanupTasks] = nil

        if type(cleanup) == "function" then
            cleanup()
        elseif typeof(cleanup) == "RBXScriptConnection" then
            cleanup:Disconnect()
        end
    end
end

return AquaScheduler