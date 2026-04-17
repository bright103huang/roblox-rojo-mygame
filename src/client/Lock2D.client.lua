-- Lock2D.client.lua

local player = game.Players.LocalPlayer

game:GetService("RunService").RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    root.Position = Vector3.new(root.Position.X, root.Position.Y, 0)
end)