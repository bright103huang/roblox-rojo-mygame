local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)

local SleepUI = {}
local isActive = false
local peaceTime = 0
local totalTime = 0
local pointerPos = 0.5
local pointerVel = 0
local peaceZoneCenter = 0.5
local peaceZoneHalf = 0.2
local isNightmare = false
local nightmareTimer = 0
local outOfBoundsTime = 0
local nightmareCount = 0
local elapsed = 0
local duration = 20
local currentTrack = nil

local screenGui, barFrame, pointer, peaceZone, timerLabel, statusLabel, hintLabel
local runConn

function SleepUI:CreateUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SleepUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local backdrop = Instance.new("ImageLabel")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.6
    backdrop.Parent = screenGui

    barFrame = Instance.new("Frame")
    barFrame.Name = "BarFrame"
    barFrame.Size = UDim2.new(0, 400, 0, 20)
    barFrame.Position = UDim2.new(0.5, -200, 0.5, -10)
    barFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    barFrame.BackgroundTransparency = 0.3
    barFrame.BorderSizePixel = 1
    barFrame.Parent = screenGui

    peaceZone = Instance.new("Frame")
    peaceZone.Name = "PeaceZone"
    peaceZone.Size = UDim2.new(0.4, 0, 1, 0)
    peaceZone.Position = UDim2.new(0.3, 0, 0, 0)
    peaceZone.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
    peaceZone.BackgroundTransparency = 0.3
    peaceZone.BorderSizePixel = 0
    peaceZone.Parent = barFrame

    pointer = Instance.new("Frame")
    pointer.Name = "Pointer"
    pointer.Size = UDim2.new(0, 6, 0, 26)
    pointer.Position = UDim2.new(0.5, -3, 0, -3)
    pointer.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    pointer.BackgroundTransparency = 0.1
    pointer.BorderSizePixel = 0
    pointer.Parent = screenGui

    timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 100, 0, 20)
    timerLabel.Position = UDim2.new(0.5, -50, 0.5, 20)
    timerLabel.BackgroundTransparency = 1
    timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timerLabel.TextSize = 14
    timerLabel.Parent = screenGui

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 200, 0, 24)
    statusLabel.Position = UDim2.new(0.5, -100, 0.5, 45)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
    statusLabel.TextSize = 18
    statusLabel.Parent = screenGui

    hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(0, 200, 0, 20)
    hintLabel.Position = UDim2.new(0.5, -100, 0.5, -40)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Click to balance"
    hintLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    hintLabel.TextSize = 12
    hintLabel.Parent = screenGui

    SleepUI:Hide()
end

function SleepUI:Start()
    screenGui.Enabled = true
    isActive = true
    peaceTime = 0
    totalTime = 0
    pointerPos = 0.5
    pointerVel = 0
    elapsed = 0
    nightmareTimer = 0
    outOfBoundsTime = 0
    nightmareCount = 0

    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            local laySeq = AnimationFactory:CreateLaySequence()
            currentTrack = AnimationFactory:PlayAnimation(humanoid, laySeq)
            humanoid.WalkSpeed = 0
            humanoid.AutoRotate = false
        end
    end

    runConn = RunService.Heartbeat:Connect(function(dt)
        SleepUI:Update(dt)
    end)
end

function SleepUI:Update(dt)
    if not isActive then return end
    elapsed = elapsed + dt
    totalTime = totalTime + dt

    -- Pointer physics: click pushes right, natural drift left
    pointerVel = pointerVel - 0.3 * dt
    pointerVel = pointerVel * 0.98
    pointerPos = pointerPos + pointerVel * dt
    pointerPos = math.clamp(pointerPos, 0.05, 0.95)

    -- Check peace zone
    local inZone = math.abs(pointerPos - peaceZoneCenter) < peaceZoneHalf
    if inZone then
        peaceTime = peaceTime + dt
        outOfBoundsTime = 0
        statusLabel.Text = "安宁"
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    else
        outOfBoundsTime = outOfBoundsTime + dt
        statusLabel.Text = "不宁"
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
    end

    -- Nightmare check
    nightmareTimer = nightmareTimer + dt
    local malice = player:GetAttribute("Malice") or 0
    if nightmareTimer > 10 and malice > 0 then
        if math.random() < 0.3 then
            isNightmare = true
            nightmareCount = nightmareCount + 1
            pointerVel = pointerVel + (math.random() > 0.5 and 0.8 or -0.8)
            peaceZoneHalf = 0.1
            statusLabel.Text = "梦魇!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            task.delay(3, function()
                peaceZoneHalf = 0.2
                isNightmare = false
            end)
        end
        nightmareTimer = 0
    end

    -- Check insomnia from long OOB
    if outOfBoundsTime > 3 then
        SleepUI:Complete()
        return
    end

    barFrame.Parent = screenGui
    pointer.Position = UDim2.new(pointerPos, -3, 0.5, -13)
    timerLabel.Text = string.format("%.1f / %ds", elapsed, duration)

    if elapsed >= duration then
        SleepUI:Complete()
    end
end

function SleepUI:Complete()
    if runConn then runConn:Disconnect() end
    isActive = false
    peaceZoneHalf = 0.2

    local ratio = totalTime > 0 and peaceTime / totalTime or 0
    HomeEvent:FireServer("SleepComplete", {
        PeaceRatio = ratio,
        NightmaresTriggered = nightmareCount,
    })

    if currentTrack then currentTrack:Stop(); currentTrack = nil end
    local char = player.Character
    if char then
        local h = char:FindFirstChild("Humanoid")
        if h then h.AutoRotate = true; h.WalkSpeed = 16 end
    end
    SleepUI:Hide()
end

function SleepUI:Hide()
    isActive = false
    if screenGui then screenGui.Enabled = false end
    if runConn then runConn:Disconnect() end
end

-- Click to push pointer right
UserInputService.InputBegan:Connect(function(input, gp)
    if not isActive or gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        pointerVel = pointerVel + 0.4
    elseif input.KeyCode == Enum.KeyCode.Escape then
        SleepUI:Complete()
    end
end)

HomeEvent.OnClientEvent:Connect(function(action, data)
    if action == "StartSleep" then
        SleepUI:Start()
    elseif action == "SleepSettlement" then
        -- Show settlement results briefly
        statusLabel.Text = data.Message or ""
        task.delay(3, function() SleepUI:Hide() end)
    end
end)

return SleepUI
