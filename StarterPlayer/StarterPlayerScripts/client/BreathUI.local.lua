local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local ShopEvent = ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("ShopEvent")
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)
local BreathUI = {}
local isActive, currentPhase, phaseStartTime, isFPressed, consecutivePerfect, currentLayer, malAdjust, currentTrack
local phaseTimers = { INHALE = 2.0, HOLD = 1.5, EXHALE = 2.0 }
local screenGui, outerRing, phaseLabel, feedbackLabel, layerLabel, backpackFrame
local fDownConn, fUpConn

function BreathUI:CreateUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BreathUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    local backdrop = Instance.new("ImageLabel")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.Parent = screenGui
    local rc = Instance.new("Frame")
    rc.Name = "RingContainer"
    rc.Size = UDim2.new(0, 200, 0, 200)
    rc.Position = UDim2.new(0.5, -100, 0.5, -120)
    rc.BackgroundTransparency = 1
    rc.Parent = screenGui
    outerRing = Instance.new("Frame")
    outerRing.Name = "OuterRing"
    outerRing.Size = UDim2.new(0, 40, 0, 40)
    outerRing.Position = UDim2.new(0.5, -20, 0.5, -20)
    outerRing.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    outerRing.BackgroundTransparency = 0.6
    outerRing.Parent = rc
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = outerRing
    phaseLabel = Instance.new("TextLabel")
    phaseLabel.Size = UDim2.new(0, 200, 0, 30)
    phaseLabel.Position = UDim2.new(0.5, -100, 0.5, 50)
    phaseLabel.BackgroundTransparency = 1
    phaseLabel.Text = "准备"
    phaseLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
    phaseLabel.TextSize = 24
    phaseLabel.Parent = screenGui
    feedbackLabel = Instance.new("TextLabel")
    feedbackLabel.Size = UDim2.new(0, 200, 0, 24)
    feedbackLabel.Position = UDim2.new(0.5, -100, 0.5, 80)
    feedbackLabel.BackgroundTransparency = 1
    feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    feedbackLabel.TextSize = 18
    feedbackLabel.Parent = screenGui
    layerLabel = Instance.new("TextLabel")
    layerLabel.Size = UDim2.new(0, 200, 0, 20)
    layerLabel.Position = UDim2.new(0.5, -100, 0.5, 105)
    layerLabel.BackgroundTransparency = 1
    layerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    layerLabel.TextSize = 14
    layerLabel.Parent = screenGui
    backpackFrame = Instance.new("Frame")
    backpackFrame.Size = UDim2.new(0, 120, 0, 300)
    backpackFrame.Position = UDim2.new(0, 10, 0.5, -150)
    backpackFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    backpackFrame.BackgroundTransparency = 0.3
    backpackFrame.Parent = screenGui
    local bpLabel = Instance.new("TextLabel")
    bpLabel.Size = UDim2.new(1, 0, 0, 24)
    bpLabel.BackgroundTransparency = 1
    bpLabel.Text = "丹药"
    bpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    bpLabel.TextSize = 14
    bpLabel.Parent = backpackFrame
    BreathUI:Hide()
end

function BreathUI:Start()
    screenGui.Enabled = true
    isActive = true
    consecutivePerfect = 0
    currentLayer = 0
    layerLabel.Text = ""
    local malice = player:GetAttribute("Malice") or 0
    malAdjust = 1.0
    if malice > 50 then BreathUI:Hide(); return end
    if malice > 30 then malAdjust = 1.33 end
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            currentTrack = AnimationFactory:PlayAnimation(humanoid, AnimationFactory:CreateSitSequence())
            humanoid.WalkSpeed = 0
            humanoid.AutoRotate = false
        end
    end
    HomeEvent:FireServer("GetBackpack")
    BreathUI:StartPhase("INHALE")
end
function BreathUI:Hide()
    isActive = false
    if screenGui then screenGui.Enabled = false end
    currentPhase = nil
end

function BreathUI:StartPhase(phaseName)
    if not isActive then return end
    currentPhase = phaseName
    phaseStartTime = tick()
    local pt = { INHALE = "吸气", HOLD = "屏息", EXHALE = "呼气" }
    phaseLabel.Text = pt[phaseName] or ""
    local duration = phaseTimers[phaseName] or 2.0
    if malAdjust > 1 then duration = duration / malAdjust end
    local targetSize = UDim2.new(0, 40, 0, 40)
    if phaseName == "INHALE" then targetSize = UDim2.new(0, 200, 0, 200)
    elseif phaseName == "EXHALE" then targetSize = UDim2.new(0, 40, 0, 40)
    else targetSize = UDim2.new(0, 200, 0, 200) end
    local tween = TweenService:Create(outerRing, TweenInfo.new(duration, Enum.EasingStyle.OutQuad), { Size = targetSize })
    tween:Play()
end

function BreathUI:Judge(phase)
    local elapsed = tick() - phaseStartTime
    local expected = phaseTimers[phase] or 2.0
    local adjustedDuration = malAdjust > 1 and (expected / malAdjust) or expected
    local diff = math.abs(elapsed - adjustedDuration)
    local judgment = "normal"
    if diff < 0.15 then judgment = "perfect"
    elseif diff < 0.30 then judgment = "precise"
    elseif diff > 0.50 then judgment = "miss" end
    local jt = { perfect = "完美", precise = "精准", normal = "普通", miss = "失误" }
    local jc = { perfect = Color3.fromRGB(255,255,100), precise = Color3.fromRGB(150,255,150), normal = Color3.fromRGB(200,200,200), miss = Color3.fromRGB(255,100,100) }
    feedbackLabel.TextColor3 = jc[judgment]
    feedbackLabel.Text = jt[judgment]
    if judgment == "perfect" then
        consecutivePerfect = consecutivePerfect + 1
        if consecutivePerfect % 3 == 0 then
            currentLayer = math.min(3, currentLayer + 1)
            layerLabel.Text = "层数: " .. currentLayer
        end
    else
        consecutivePerfect = 0
        currentLayer = 0
        layerLabel.Text = ""
    end
    HomeEvent:FireServer("BreathResult", { Judgment = judgment, Layer = currentLayer })
    task.delay(0.5, function() if feedbackLabel then feedbackLabel.Text = "" end end)
end
function BreathUI:End()
    if currentTrack then currentTrack:Stop(); currentTrack = nil end
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = 16
        end
    end
    if fDownConn then fDownConn:Disconnect() end
    if fUpConn then fUpConn:Disconnect() end
    BreathUI:Hide()
end

fDownConn = UserInputService.InputBegan:Connect(function(input, gp)
    if not isActive or gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        if currentPhase == "INHALE" then
            BreathUI:Judge("INHALE")
            BreathUI:StartPhase("HOLD")
        end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        BreathUI:End()
    end
end)

fUpConn = UserInputService.InputEnded:Connect(function(input, gp)
    if not isActive or gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        if currentPhase == "HOLD" then BreathUI:StartPhase("EXHALE")
        elseif currentPhase == "EXHALE" then
            BreathUI:Judge("EXHALE")
            BreathUI:StartPhase("INHALE")
        end
    end
end)

HomeEvent.OnClientEvent:Connect(function(action, data)
    if action == "StartMeditation" then
        BreathUI:Start()
    elseif action == "BackpackData" then
        for _, child in ipairs(backpackFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local y = 30
        for itemKey, count in pairs(data.Backpack or {}) do
            if count <= 0 then continue end
            local btn = Instance.new("TextButton")
            btn.Name = itemKey
            btn.Size = UDim2.new(1, -10, 0, 28)
            btn.Position = UDim2.new(0, 5, 0, y)
            btn.Text = itemKey .. " x" .. count
            btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            btn.TextSize = 12
            btn.Parent = backpackFrame
            btn.MouseButton1Click:Connect(function()
                if not isActive then return end
                ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey, IsMeditating = true })
                task.wait(0.3)
                HomeEvent:FireServer("GetBackpack")
            end)
            y = y + 32
        end
    end
end)

BreathUI:CreateUI()
return BreathUI
