-- Camera2D.client.lua

local camera = workspace.CurrentCamera

camera.CameraType = Enum.CameraType.Scriptable

game:GetService("RunService").RenderStepped:Connect(function()
    local player = game.Players.LocalPlayer
    local char = player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    camera.CFrame = CFrame.new(
        root.Position + Vector3.new(0, 10, 30),
        root.Position
    )
end)