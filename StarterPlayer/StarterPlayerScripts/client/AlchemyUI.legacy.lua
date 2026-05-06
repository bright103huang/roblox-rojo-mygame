-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.AlchemyUI.client.lua
-- 功能：密室炼丹 UI
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 获取 TaskEvent
-- ============================================================
local TaskEvent = nil
local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
if eventsFolder then
	TaskEvent = eventsFolder:FindFirstChild("TaskEvent")
end

-- ============================================================
-- UI 状态
-- ============================================================
local AlchemyUI = {}
local screenGui = nil
local selectedIngredients = {}
local currentData = {}

-- ============================================================
-- 颜色常量
-- ============================================================
local COLORS = {
	Bg = Color3.fromRGB(20, 20, 30),
	Panel = Color3.fromRGB(30, 30, 45),
	Gold = Color3.fromRGB(255, 215, 0),
	Red = Color3.fromRGB(255, 60, 60),
	Green = Color3.fromRGB(80, 200, 80),
	White = Color3.new(1, 1, 1),
	Gray = Color3.fromRGB(150, 150, 150),
	DarkGray = Color3.fromRGB(60, 60, 60),
	Selected = Color3.fromRGB(60, 180, 60),
}

-- ============================================================
-- 创建 UI
-- ============================================================
function AlchemyUI:Open(data)
	currentData = data or {}
	selectedIngredients = {}
	self:CreateUI()
end

function AlchemyUI:CreateUI()
	-- 关闭已有 UI
	self:Close()

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AlchemyUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 遮罩
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- 关闭遮罩点击
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:Close()
		end
	end)

	-- 主面板
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 380, 0, 420)
	panel.Position = UDim2.new(0.5, -190, 0.5, -210)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	-- 标题
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "🧪 密室炼丹"
	title.TextColor3 = COLORS.Gold
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold
	title.Parent = panel

	-- 分割线
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.9, 0, 0, 1)
	divider.Position = UDim2.new(0.05, 0, 0, 46)
	divider.BackgroundColor3 = COLORS.Gray
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- 药材选择提示
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 0, 24)
	hintLabel.Position = UDim2.new(0, 10, 0, 52)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "选择药材（选 2 种不同药材）"
	hintLabel.TextColor3 = COLORS.White
	hintLabel.TextSize = 14
	hintLabel.Font = Enum.Font.SourceSans
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = panel

	-- 药材按钮网格（2x3）
	local available = currentData.AvailableIngredients or { "草药", "清水", "灵芝", "仙露", "火晶" }
	local buttonWidth = 100
	local buttonHeight = 44
	local gridStartX = 20
	local gridStartY = 82
	local spacingX = 20
	local spacingY = 12
	local cols = 3

	local ingredientButtons = {}

	for i, name in ipairs(available) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = gridStartX + col * (buttonWidth + spacingX)
		local y = gridStartY + row * (buttonHeight + spacingY)

		local btn = Instance.new("TextButton")
		btn.Name = "Ing_" .. name
		btn.Size = UDim2.new(0, buttonWidth, 0, buttonHeight)
		btn.Position = UDim2.new(0, x, 0, y)
		btn.Text = name
		btn.TextColor3 = COLORS.White
		btn.TextSize = 16
		btn.Font = Enum.Font.SourceSansBold
		btn.BackgroundColor3 = COLORS.DarkGray
		btn.BorderSizePixel = 0
		btn.Parent = panel
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		-- 选中状态
		local isSelected = false
		btn.MouseButton1Click:Connect(function()
			isSelected = not isSelected
			if isSelected then
				table.insert(selectedIngredients, name)
				btn.BackgroundColor3 = COLORS.Selected
			else
				for j = #selectedIngredients, 1, -1 do
					if selectedIngredients[j] == name then
						table.remove(selectedIngredients, j)
						break
					end
				end
				btn.BackgroundColor3 = COLORS.DarkGray
			end
			self:UpdateSelectionDisplay(panel, ingredientButtons, craftBtn)
		end)

		ingredientButtons[name] = btn
	end

	-- 当前选择显示区
	local selectionFrame = Instance.new("Frame")
	selectionFrame.Name = "SelectionFrame"
	selectionFrame.Size = UDim2.new(0.9, 0, 0, 40)
	selectionFrame.Position = UDim2.new(0.05, 0, 0, 220)
	selectionFrame.BackgroundColor3 = COLORS.Bg
	selectionFrame.BorderSizePixel = 0
	selectionFrame.Parent = panel
	local selectionCorner = Instance.new("UICorner")
	selectionCorner.CornerRadius = UDim.new(0, 6)
	selectionCorner.Parent = selectionFrame

	local selectionLabel = Instance.new("TextLabel")
	selectionLabel.Name = "SelectionLabel"
	selectionLabel.Size = UDim2.new(1, -10, 1, 0)
	selectionLabel.Position = UDim2.new(0, 5, 0, 0)
	selectionLabel.BackgroundTransparency = 1
	selectionLabel.Text = "已选：无"
	selectionLabel.TextColor3 = COLORS.Gray
	selectionLabel.TextSize = 14
	selectionLabel.Font = Enum.Font.SourceSans
	selectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectionLabel.Parent = selectionFrame

	-- 配方提示
	local recipeHint = Instance.new("TextLabel")
	recipeHint.Name = "RecipeHint"
	recipeHint.Size = UDim2.new(0.9, 0, 0, 20)
	recipeHint.Position = UDim2.new(0.05, 0, 0, 268)
	recipeHint.BackgroundTransparency = 1
	recipeHint.Text = ""
	recipeHint.TextColor3 = COLORS.Gold
	recipeHint.TextSize = 12
	recipeHint.Font = Enum.Font.SourceSans
	recipeHint.Parent = panel

	-- 炼制按钮
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "CraftBtn"
	craftBtn.Size = UDim2.new(0.6, 0, 0, 48)
	craftBtn.Position = UDim2.new(0.2, 0, 0, 300)
	craftBtn.Text = "🔥 开始炼制"
	craftBtn.TextColor3 = COLORS.White
	craftBtn.TextSize = 18
	craftBtn.Font = Enum.Font.SourceSansBold
	craftBtn.BackgroundColor3 = COLORS.DarkGray
	craftBtn.BorderSizePixel = 0
	craftBtn.Parent = panel
	local craftCorner = Instance.new("UICorner")
	craftCorner.CornerRadius = UDim.new(0, 8)
	craftCorner.Parent = craftBtn
	craftBtn.Active = false

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 6)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.Gray
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 炼制按钮点击事件
	craftBtn.MouseButton1Click:Connect(function()
		if #selectedIngredients < 2 then return end
		craftBtn.Text = "炼制中..."
		craftBtn.Active = false
		craftBtn.BackgroundColor3 = COLORS.DarkGray

		-- 发送炼制请求到服务器
		if TaskEvent then
			TaskEvent:FireServer("Craft:Alchemy", nil, {
				Ingredients = selectedIngredients,
			})
		else
			craftBtn.Text = "🔥 开始炼制"
		end
	end)

	-- 存储引用
	screenGui:SetAttribute("CraftBtn", craftBtn:GetAttributeChangedSignal("Text"))
	screenGui:SetAttribute("SelectionLabel", selectionLabel)
	screenGui:SetAttribute("RecipeHint", recipeHint)

	-- 保存引用供 UpdateSelectionDisplay 使用
	screenGui:SetAttribute("_craftBtnRef", craftBtn)
	screenGui:SetAttribute("_selectionLabelRef", selectionLabel)
	screenGui:SetAttribute("_recipeHintRef", recipeHint)

	-- 初始化更新
	self:UpdateSelectionDisplay(panel, ingredientButtons, craftBtn)
	self:UpdateRecipeHint(recipeHint)

	-- 存储 ingredients 引用
	screenGui:SetAttribute("_ingredientButtons", ingredientButtons)

	-- 结果弹窗（预创建，默认隐藏）
	self:CreateResultPopup(panel)
end

function AlchemyUI:UpdateSelectionDisplay(panel, ingredientButtons, craftBtn)
	local selectionLabel = screenGui and screenGui:GetAttribute("_selectionLabelRef")
	if not selectionLabel then return end

	if #selectedIngredients == 0 then
		selectionLabel.Text = "已选：无"
	else
		selectionLabel.Text = "已选：" .. table.concat(selectedIngredients, " + ")
	end

	-- 更新炼制按钮状态
	if craftBtn then
		if #selectedIngredients >= 2 then
			craftBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 30)
			craftBtn.Active = true
		else
			craftBtn.BackgroundColor3 = COLORS.DarkGray
			craftBtn.Active = false
		end
	end

	-- 配方提示
	local recipeHint = screenGui and screenGui:GetAttribute("_recipeHintRef")
	if recipeHint then
		self:UpdateRecipeHint(recipeHint)
	end
end

function AlchemyUI:UpdateRecipeHint(recipeHint)
	if not recipeHint then return end
	if #selectedIngredients < 2 then
		recipeHint.Text = ""
		return
	end

	-- 从当前数据查找配方
	local recipes = currentData.Recipes or {}
	for _, recipe in ipairs(recipes) do
		local sorted1 = table.clone(selectedIngredients)
		table.sort(sorted1)
		local sorted2 = table.clone(recipe.Ingredients)
		table.sort(sorted2)

		local match = #sorted1 == #sorted2
		if match then
			for i = 1, #sorted1 do
				if sorted1[i] ~= sorted2[i] then
					match = false
					break
				end
			end
		end

		if match then
			recipeHint.Text = "📖 " .. recipe.Name .. "：" .. (recipe.Description or "")
			recipeHint.TextColor3 = COLORS.Gold
			return
		end
	end

	recipeHint.Text = "⚠️ 未知配方组合"
	recipeHint.TextColor3 = COLORS.Gray
end

function AlchemyUI:CreateResultPopup(parent)
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultPopup"
	resultFrame.Size = UDim2.new(0.8, 0, 0, 120)
	resultFrame.Position = UDim2.new(0.1, 0, 0, -130)
	resultFrame.BackgroundColor3 = COLORS.Bg
	resultFrame.BorderSizePixel = 0
	resultFrame.BackgroundTransparency = 1
	resultFrame.Visible = false
	resultFrame.Parent = parent
	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 10)
	resultCorner.Parent = resultFrame

	local resultTitle = Instance.new("TextLabel")
	resultTitle.Name = "ResultTitle"
	resultTitle.Size = UDim2.new(1, 0, 0, 36)
	resultTitle.Position = UDim2.new(0, 0, 0, 8)
	resultTitle.BackgroundTransparency = 1
	resultTitle.Text = ""
	resultTitle.TextSize = 20
	resultTitle.Font = Enum.Font.SourceSansBold
	resultTitle.Parent = resultFrame

	local resultDesc = Instance.new("TextLabel")
	resultDesc.Name = "ResultDesc"
	resultDesc.Size = UDim2.new(1, -20, 0, 40)
	resultDesc.Position = UDim2.new(0, 10, 0, 44)
	resultDesc.BackgroundTransparency = 1
	resultDesc.Text = ""
	resultDesc.TextSize = 14
	resultDesc.Font = Enum.Font.SourceSans
	resultDesc.Parent = resultFrame

	screenGui:SetAttribute("_resultPopup", resultFrame)
	screenGui:SetAttribute("_resultTitle", resultTitle)
	screenGui:SetAttribute("_resultDesc", resultDesc)
end

-- 显示结果（由 TaskClient 调用）
function AlchemyUI:ShowResult(success, data)
	local resultPopup = screenGui and screenGui:GetAttribute("_resultPopup")
	local resultTitle = screenGui and screenGui:GetAttribute("_resultTitle")
	local resultDesc = screenGui and screenGui:GetAttribute("_resultDesc")
	if not resultPopup then return end

	resultPopup.Visible = true
	resultPopup.BackgroundTransparency = 0

	if success then
		resultTitle.Text = "✅ 炼制成功！"
		resultTitle.TextColor3 = COLORS.Green
		resultDesc.Text = (data.Recipe or "丹药") .. " +15 仙晶"
		if data.SpecialEffects then
			for effect, val in pairs(data.SpecialEffects) do
				resultDesc.Text = resultDesc.Text .. "\n" .. effect .. " " .. (val > 0 and "+" .. val or tostring(val))
			end
		end
		resultDesc.TextColor3 = COLORS.Gold
	else
		if data.Reason == "Explosion" then
			resultTitle.Text = "💥 炸炉了！"
			resultTitle.TextColor3 = COLORS.Red
			resultDesc.Text = "疲劳 +" .. (data.FatigueIncrease or 20) .. "，材料损失"
			resultDesc.TextColor3 = COLORS.Red
		elseif data.Reason == "InvalidRecipe" then
			resultTitle.Text = "❌ 无效配方"
			resultTitle.TextColor3 = COLORS.Gray
			resultDesc.Text = "这些药材无法组合成丹方"
			resultDesc.TextColor3 = COLORS.Gray
		elseif data.Reason == "SpiritTooLow" then
			resultTitle.Text = "❌ 精神不足"
			resultTitle.TextColor3 = COLORS.Gray
			resultDesc.Text = "需要至少 " .. (data.SpiritReq or 20) .. " 精神才能炼制此丹"
			resultDesc.TextColor3 = COLORS.Gray
		else
			resultTitle.Text = "❌ 炼制失败"
			resultTitle.TextColor3 = COLORS.Red
			resultDesc.Text = tostring(data.Reason or "未知原因")
			resultDesc.TextColor3 = COLORS.Red
		end
	end

	-- 3 秒后自动关闭
	task.delay(3, function()
		AlchemyUI:Close()
	end)
end

function AlchemyUI:Close()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	selectedIngredients = {}
	currentData = {}
end

return AlchemyUI
