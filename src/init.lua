local RunService = game:GetService("RunService")
if RunService:IsServer() then
    return require(script.AquaServer)
else
    local hasServer = script:FindFirstChild("AquaServer")
    if hasServer then
        hasServer:Destroy()
    end
    return require(script.AquaClient)
end