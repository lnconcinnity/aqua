local RunService = game:GetService("RunService")
if RunService:IsServer() then
    return require(script.server)
else
    local hasServer = script:FindFirstChild("server")
    if hasServer then
        hasServer:Destroy()
    end
    return require(script.client)
end