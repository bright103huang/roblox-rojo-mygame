-- StarterPlayer.StarterPlayerScripts.Client.TaskClient.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- 等待 TaskEvent
local function waitForTaskEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		repeat
			eventsFolder = ReplicatedStorage:FindFirstChild("Events")
			RunService.Heartbeat:Wait()
		until eventsFolder
	end

	local taskEvent = eventsFolder:WaitForChild("TaskEvent", 10)
	if not taskEvent then
		error("TaskEvent not found - server may not be running")
	end
	return taskEvent
end

local TaskEvent = waitForTaskEvent()

local carrying = false
local debounce = false

TaskEvent.OnClientEvent:Connect(function(result)
	if result == "DropSuccess" then
		print("客户端：交付成功")
		carrying = false

		-- 手动删除手中盘子（防止服务端删除失败）
		local char = player.Character
		if char then
			local plate = char:FindFirstChild("Plate")
			if plate then plate:Destroy() end
		end

	elseif result == "DropFailed" then
		print("客户端：错误桌子")
	end
end)

local function bind(part)
	if part.Name ~= "DishArea" and part.Name ~= "TableArea" then return end

	part.Touched:Connect(function(hit)
		if not player.Character then return end
		if hit.Parent ~= player.Character then return end
		if debounce then return end

		debounce = true

		if part.Name == "DishArea" and not carrying then
			carrying = true
			print("拿菜")
			TaskEvent:FireServer("Pick")

		elseif part.Name == "TableArea" and carrying then
			local tableId = part:GetAttribute("TableId")
			print("尝试交菜，桌子ID：", tableId)
			TaskEvent:FireServer("Drop", tableId)
		end

		task.wait(0.3)
		debounce = false
	end)
end

for _, v in pairs(workspace:GetDescendants()) do
	bind(v)
end

workspace.DescendantAdded:Connect(bind)