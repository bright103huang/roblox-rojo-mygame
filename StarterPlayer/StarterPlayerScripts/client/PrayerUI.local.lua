local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)

local PrayerUI = {}
local screenGui
local currentTrack = nil

local OPTIONS = {
    Basic = { name = "诚心礼拜", cost = 0, desc = "功德+3, 戾气-1" },
    Incense = { name = "焚香祷告", cost = 10, desc = "功德+8, 戾气-3, 精神+5" },
    Offering = { name = "虔诚供奉", cost = 50, desc = "功德+20, 戾气-5, 精神+10, 修为" },
}

function PrayerUI:CreateUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PrayerUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local backdrop = Instance.new("ImageLabel")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.4
    backdrop.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 300, 0, 36)
    title.Position = UDim2.new(0.5, -150, 0.5, -100)
    title.BackgroundTransparency = 1
    title.Text = "祈 福"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.TextSize = 28
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = screenGui

    local y = -60
    for key, opt in pairs(OPTIONS) do
        local card = Instance.new("Frame")
        card.Name = key
        card.Size = UDim2.new(0, 260, 0, 60)
        card.Position = UDim2.new(0.5, -130, 0.5, y)
        card.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        card.BackgroundTransparency = 0.2
        card.Parent = screenGui
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 6)
        cardCorner.Parent = card

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -10, 0, 24)
        nameL.Position = UDim2.new(0, 5, 0, 2)
        nameL.BackgroundTransparency = 1
        nameL.Text = opt.name .. (opt.cost > 0 and " (" .. opt.cost .. " 仙晶)" or " (免费)")
        nameL.TextColor3 = opt.cost > 0 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(200, 200, 200)
        nameL.TextSize = 16
        nameL.Font = Enum.Font.SourceSansBold
        nameL.Parent = card

        local descL = Instance.new("TextLabel")
        descL.Size = UDim2.new(1, -10, 0, 20)
        descL.Position = UDim2.new(0, 5, 0, 28)
        descL.BackgroundTransparency = 1
        descL.Text = opt.desc
        descL.TextColor3 = Color3.fromRGB(150, 150, 150)
        descL.TextSize = 12
        descL.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 24)
        btn.Position = UDim2.new(1, -55, 0, 18)
        btn.Text = "选择"
        btn.BackgroundColor3 = Color3.fromRGB(60, 70, 100)
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.TextSize = 12
        btn.Parent = card
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            PrayerUI:Select(key)
        end)

        y = y + 70
    end

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 100, 0, 28)
    closeBtn.Position = UDim2.new(0.5, -50, 0.5, y + 10)
    closeBtn.Text = "取消"
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    closeBtn.TextSize = 14
    closeBtn.Parent = screenGui
    closeBtn.MouseButton1Click:Connect(function()
        PrayerUI:Hide()
    end)

    PrayerUI:Hide()
end

function PrayerUI:Show()
    screenGui.Enabled = true
end

function PrayerUI:Hide()
    screenGui.Enabled = false
end

function PrayerUI:Select(key)
    local opt = OPTIONS[key]
    if not opt then return end

    -- Play kneel animation
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            local kneelSeq = AnimationFactory:CreateKneelSequence()
            currentTrack = AnimationFactory:PlayAnimation(humanoid, kneelSeq)
        end
    end

    HomeEvent:FireServer("PrayerChoice", { Option = key })
end

HomeEvent.OnClientEvent:Connect(function(action, data)
    if action == "ShowPrayer" then
        PrayerUI:Show()
    elseif action == "PrayerResult" then
        if currentTrack then currentTrack:Stop(); currentTrack = nil end
        if data.Success then
            PrayerUI:Hide()
        end
    end
end)

PrayerUI:CreateUI()
return PrayerUI
