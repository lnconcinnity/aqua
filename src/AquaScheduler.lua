local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local AquaScheduleMetatable = {}
function AquaScheduleMetatable:onRenderStepped(fn: (dt: number) -> (), overridePriority: number?)
    assert(not IS_SERVER, "Scheduler:onRenderStepped() can only")
    if overridePriority or (type(self.renderPriority) == "number" and self.renderPriority > 0) then
        local id = HttpService:GenerateGUID(false)
        RunService:BindToRenderStep(id, overridePriority or self.renderPriority, fn)
        table.insert(self.cleanupTasks, function()
            RunService:UnbindFromRenderStep(id)
        end)
    else
        table.insert(self.cleanupTasks, RunService.RenderStepped:Connect(fn))
    end
end

function AquaScheduleMetatable:onHeartbeat(fn: (dt: number) -> ())
    table.insert(self.cleanupTasks, RunService.Heartbeat:Connect(fn))
end

function AquaScheduleMetatable:onStepped(fn: (t: number, dt: number) -> ())
    table.insert(self.cleanupTasks, RunService.Stepped:Connect(fn))
end

function AquaScheduleMetatable:Cleanup()
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

local AquaScheduler = {}
function AquaScheduler.listen(source: {__heartbeatUpdate: () -> (), __renderUpdate: () -> (), __steppedUpdate: () -> (), RenderPriorityValue: number?})
    local scheduler = {}
    scheduler.cleanupTasks = {}
    scheduler.priority = if not IS_SERVER then source.RenderPriorityValue or 999 else nil
    return setmetatable(scheduler, {__index = AquaScheduleMetatable})
end

return AquaScheduler