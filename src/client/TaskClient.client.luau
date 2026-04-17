-- TaskClient.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local TaskEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TaskEvent")

local carrying = false
local debounce = false

-- 🔥 接收服务器反馈（关键）
TaskEvent.OnClientEvent:Connect(function(result)
	if result == "DropSuccess" then
		print("客户端：交付成功")
		carrying = false
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

		-- 拿菜
		if part.Name == "DishArea" and not carrying then
			carrying = true
			print("拿菜")
			TaskEvent:FireServer("Pick")

		-- 交菜（不再修改 carrying）
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