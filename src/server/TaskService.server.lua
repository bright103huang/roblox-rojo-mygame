-- TaskService.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvent
local eventsFolder = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
eventsFolder.Name = "Events"
eventsFolder.Parent = ReplicatedStorage

local TaskEvent = eventsFolder:FindFirstChild("TaskEvent") or Instance.new("RemoteEvent")
TaskEvent.Name = "TaskEvent"
TaskEvent.Parent = eventsFolder

-- 数据
local carrying = {}
local currentTarget = nil

-- 收集桌子
local tables = {}
for _, v in pairs(workspace:GetDescendants()) do
	if v.Name == "TableArea" then
		table.insert(tables, v)
	end
end

-- 分配订单
local function assignOrder()
	if #tables == 0 then return end

	currentTarget = tables[math.random(1, #tables)]

	print("🎯 当前目标桌子ID：", currentTarget:GetAttribute("TableId"))
end

assignOrder()

-- 盘子
local plateTemplate = ReplicatedStorage:WaitForChild("Plate")

-- 事件
TaskEvent.OnServerEvent:Connect(function(player, action, tableId)
	-- 拿菜
	if action == "Pick" then
		if carrying[player.UserId] then return end
		carrying[player.UserId] = true

		local char = player.Character
		if not char then return end

		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		if not hand then return end

		local plate = plateTemplate:Clone()
		plate.Name = "Plate"
		plate.Parent = char

		plate.PrimaryPart = plate:FindFirstChild("PlateBase")

		plate:SetPrimaryPartCFrame(hand.CFrame * CFrame.new(0, -0.3, -1))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = plate.PrimaryPart
		weld.Parent = plate.PrimaryPart

	-- 交菜
	elseif action == "Drop" then
		if not carrying[player.UserId] then return end
		if not tableId then return end
		if not currentTarget then return end

		local targetId = currentTarget:GetAttribute("TableId")

		if tableId ~= targetId then
			-- ❗失败也要通知客户端
			TaskEvent:FireClient(player, "DropFailed")
			return
		end

		carrying[player.UserId] = nil

		-- 删除盘子
		local char = player.Character
		if char then
			local plate = char:FindFirstChild("Plate")
			if plate then
				plate:Destroy()
			end
		end

		-- 加钱
		local stats = player:FindFirstChild("leaderstats")
		local gold = stats and stats:FindFirstChild("仙晶")

		if gold then
			gold.Value += 10
			print("✅ 加钱成功")
		end

		-- ✅ 通知客户端成功
		TaskEvent:FireClient(player, "DropSuccess")

		assignOrder()
	end
end)