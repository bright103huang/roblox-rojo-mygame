-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.PromotionUI.local.lua
-- 功能：晋升仪式动画 — 监听 PromotionCeremony 事件，
--       播放 8 秒动画，显示排行榜面板
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- ============================================================
-- 等待 TaskEvent
-- ============================================================
local function waitForTaskEvent()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = ReplicatedStorage:WaitForChild("Events", 15)
	end
	if not eventsFolder then return nil end
	return eventsFolder:FindFirstChild("TaskEvent")
end

local taskEvent = waitForTaskEvent()
if not taskEvent then
	warn("PromotionUI: TaskEvent not found")
	return
end

-- ============================================================

-- ============================================================
-- 排行榜面板
-- ============================================================
local function showRankings(gui, rankings)
	-- 清理仪式元素
	local titleLabel = gui:FindFirstChild("TitleLabel")
	if titleLabel then titleLabel:Destroy() end
	local subtitleLabel = gui:FindFirstChild("SubtitleLabel")
	if subtitleLabel then subtitleLabel:Destroy() end
	local infoLabel = gui:FindFirstChild("InfoLabel")
	if infoLabel then infoLabel:Destroy() end
	local lbButton = gui:FindFirstChild("LeaderboardButton")
	if lbButton then lbButton:Destroy() end

	-- 清理爆发粒子
	for _, child in ipairs(gui:GetChildren()) do
		if child.Name:find("Burst_") then
			child:Destroy()
		end
	end

	-- 排行榜面板框架
	local panel = Instance.new("Frame")
	panel.Name = "RankingsPanel"
	panel.Size = UDim2.new(0, 350, 0, 450)
	panel.Position = UDim2.new(0.5, -175, 0.5, -225)
	panel.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
	panel.BorderColor3 = Color3.fromRGB(200, 170, 50)
	panel.BorderSizePixel = 2
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panel

	-- 面板标题
	local title = Instance.new("TextLabel")
	title.Name = "PanelTitle"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "天兵排行榜"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextSize = 28
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = panel

	-- 排名列表
	local list = Instance.new("ScrollingFrame")
	list.Name = "RankingList"
	list.Size = UDim2.new(1, -20, 1, -80)
	list.Position = UDim2.new(0, 10, 0, 70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, math.max(#rankings * 36 + 10, 50))
	list.Parent = panel

	for i, entry in ipairs(rankings) do
		local entryLabel = Instance.new("TextLabel")
		entryLabel.Size = UDim2.new(1, 0, 0, 32)
		entryLabel.Position = UDim2.new(0, 0, 0, (i - 1) * 36)
		entryLabel.BackgroundTransparency = 0.8
		entryLabel.BackgroundColor3 = (i <= 3) and Color3.fromRGB(200, 170, 50) or Color3.new(1, 1, 1)
		entryLabel.Text = "#" .. i .. "    " .. (entry.Name or "未知") .. "    " .. tostring(entry.Days or 0) .. "天"
		entryLabel.TextColor3 = (i <= 3) and Color3.fromRGB(255, 215, 0) or Color3.new(0.8, 0.8, 0.8)
		entryLabel.TextSize = 20
		entryLabel.Font = Enum.Font.SourceSans
		entryLabel.TextXAlignment = Enum.TextXAlignment.Left
		entryLabel.TextTruncate = Enum.TextTruncate.AtEnd
		entryLabel.Parent = list
	end

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 80, 0, 30)
	closeBtn.Position = UDim2.new(1, -90, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	closeBtn.Text = "关闭"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)

	-- 淡入动画
	panel.BackgroundTransparency = 1
	TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.2,
	}):Play()
	title.TextTransparency = 1
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
end

-- ============================================================
-- 晋升仪式动画
-- ============================================================
local function startCeremony(data)
	if not data then
		warn("PromotionUI: ceremony data is nil")
		return
	end
	-- 创建全屏 ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PromotionCeremony"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 黑暗背景遮罩
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	-- 主标题文字
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0.3, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.35, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = ""
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)  -- 金色
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.TextSize = 48
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextScaled = true
	titleLabel.RichText = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = gui

	-- 副标题（预留，序列中复用 titleLabel）
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Size = UDim2.new(1, 0, 0.15, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	subtitleLabel.TextStrokeTransparency = 0
	subtitleLabel.TextSize = 28
	subtitleLabel.Font = Enum.Font.SourceSansBold
	subtitleLabel.TextScaled = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	subtitleLabel.Visible = false
	subtitleLabel.Parent = gui

	-- 用时/排名信息
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0.1, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.7, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = ""
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
	infoLabel.TextSize = 22
	infoLabel.Font = Enum.Font.SourceSans
	infoLabel.TextScaled = true
	infoLabel.TextXAlignment = Enum.TextXAlignment.Center
	infoLabel.Visible = false
	infoLabel.Parent = gui

	-- ============================================================
	-- 动画序列（使用 task.delay 控制时序）
	-- ============================================================

	-- t=0: 背景遮罩已显示

	-- t=1: 金色爆发效果（粒子从中心向外扩散）
	task.delay(1, function()
		if not gui or not gui.Parent then return end
		for i = 1, 6 do
			local burst = Instance.new("TextLabel")
			burst.Name = "Burst_" .. i
			burst.Size = UDim2.new(0, 20, 0, 20)
			local angle = (i / 6) * math.pi * 2
			burst.Position = UDim2.new(0.5, -10 + math.cos(angle) * 100, 0.5, -10 + math.sin(angle) * 100)
			burst.BackgroundTransparency = 1
			burst.Text = "✦"
			burst.TextColor3 = Color3.fromRGB(255, 215, 0)
			burst.TextSize = 24
			burst.Font = Enum.Font.SourceSansBold
			burst.Parent = gui

			-- 向外扩散并淡出
			TweenService:Create(burst, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -10 + math.cos(angle) * 200, 0.5, -10 + math.sin(angle) * 200),
				TextTransparency = 1,
			}):Play()

			task.delay(1, function()
				if burst and burst.Parent then burst:Destroy() end
			end)
		end
	end)

	-- t=3: 显示主标题 "祝贺你成为天兵天将！"
	task.delay(3, function()
		if not gui or not gui.Parent then return end
		titleLabel.Text = "祝贺你成为天兵天将！"
		titleLabel.TextTransparency = 1
		TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
	end)

	-- t=5: 过渡文字 "你已经成为 初级天兵"
	task.delay(5, function()
		if not gui or not gui.Parent then return end
		TweenService:Create(titleLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		if not gui or not gui.Parent then return end
		titleLabel.Text = "你已经成为 初级天兵"
		titleLabel.TextTransparency = 1
		TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
	end)

	-- t=6: 显示用时/排名信息
	task.delay(6, function()
		if not gui or not gui.Parent then return end
		infoLabel.Visible = true
		infoLabel.TextTransparency = 1
		infoLabel.Text = "仅用时 " .. tostring(data.Days) .. " 天 ｜ 全服排名 #" .. tostring(data.Rank or "?")
		TweenService:Create(infoLabel, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end)

	-- t=8: 显示 "查看排行榜" 按钮
	task.delay(8, function()
		if not gui or not gui.Parent then return end
		local lbButton = Instance.new("TextButton")
		lbButton.Name = "LeaderboardButton"
		lbButton.Size = UDim2.new(0, 200, 0, 50)
		lbButton.Position = UDim2.new(0.5, -100, 0.82, 0)
		lbButton.BackgroundColor3 = Color3.fromRGB(200, 170, 50)
		lbButton.BorderColor3 = Color3.fromRGB(255, 215, 0)
		lbButton.Text = "查看排行榜"
		lbButton.TextColor3 = Color3.new(1, 1, 1)
		lbButton.TextSize = 22
		lbButton.Font = Enum.Font.SourceSansBold
		lbButton.AutoButtonColor = false
		lbButton.BackgroundTransparency = 1
		lbButton.Parent = gui

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = lbButton

		-- 按钮淡入
		TweenService:Create(lbButton, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
		}):Play()

		-- 悬停效果
		lbButton.MouseEnter:Connect(function()
			if lbButton and lbButton.Parent then
				TweenService:Create(lbButton, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(230, 200, 70),
				}):Play()
			end
		end)
		lbButton.MouseLeave:Connect(function()
			if lbButton and lbButton.Parent then
				TweenService:Create(lbButton, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(200, 170, 50),
				}):Play()
			end
		end)

		-- 点击展示排行榜
		lbButton.MouseButton1Click:Connect(function()
			if gui and gui.Parent then
				showRankings(gui, data.Rankings or {})
			end
		end)
	end)
end
	local ceremonyConnection
	ceremonyConnection = taskEvent.OnClientEvent:Connect(function(eventName, data)
		if eventName == "PromotionCeremony" then
			ceremonyConnection:Disconnect()
			startCeremony(data)
		end
	end)

print("PromotionUI 已加载")
