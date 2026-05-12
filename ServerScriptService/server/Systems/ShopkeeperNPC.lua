--[[
  ShopkeeperNPC — 仙丹阁掌柜
  18-part NPC built with WeldConstraint (follows BeastNPC.buildAnimalShape pattern)
  Animations: breathing float, head turn, arm wave
  Touch binding: fires ShopEvent "Pick:Shop" on touch
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- Build NPC at position
-- ============================================================
local function buildMerchant(position)
	local model = Instance.new("Model")
	model.Name = "Shopkeeper"

	local root = Instance.new("Part")
	root.Name = "ShopkeeperRoot"
	root.Size = Vector3.new(0.5, 0.5, 0.5)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Position = position
	root.Parent = model
	model.PrimaryPart = root

	local SKIN = BrickColor.new("Light reddish violet")
	local ROBE = BrickColor.new("Dark red")
	local HAT = BrickColor.new("Black")
	local GOLD = BrickColor.new("Bright yellow")
	local WHITE = BrickColor.new("White")
	local DARK = BrickColor.new("Black")
	local BROWN = BrickColor.new("Brown")

	local parts = {
		{ Name = "RobeUpper", Shape = "Cylinder", Size = Vector3.new(1.8, 1.4, 1.8), Offset = Vector3.new(0, 1.8, 0), Color = ROBE },
		{ Name = "RobeLower", Shape = "Cylinder", Size = Vector3.new(2.2, 0.8, 2.2), Offset = Vector3.new(0, 0.8, 0), Color = ROBE },
		{ Name = "Head", Shape = "Sphere", Size = Vector3.new(1.2, 1.2, 1.2), Offset = Vector3.new(0, 3.2, 0), Color = SKIN },
		{ Name = "HatTop", Shape = "Sphere", Size = Vector3.new(1, 0.6, 1), Offset = Vector3.new(0, 4, 0), Color = HAT },
		{ Name = "HatBrim", Shape = "Block", Size = Vector3.new(1.2, 0.15, 1.2), Offset = Vector3.new(0, 3.7, 0), Color = HAT },
		{ Name = "EyeL", Shape = "Sphere", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(-0.25, 3.4, 0.45), Color = WHITE, Neon = true },
		{ Name = "EyeR", Shape = "Sphere", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(0.25, 3.4, 0.45), Color = WHITE, Neon = true },
		{ Name = "PupilL", Shape = "Sphere", Size = Vector3.new(0.1, 0.1, 0.1), Offset = Vector3.new(-0.25, 3.4, 0.6), Color = DARK },
		{ Name = "PupilR", Shape = "Sphere", Size = Vector3.new(0.1, 0.1, 0.1), Offset = Vector3.new(0.25, 3.4, 0.6), Color = DARK },
		{ Name = "EyebrowL", Shape = "Wedge", Size = Vector3.new(0.35, 0.1, 0.1), Offset = Vector3.new(-0.25, 3.6, 0.45), Color = BROWN },
		{ Name = "EyebrowR", Shape = "Wedge", Size = Vector3.new(0.35, 0.1, 0.1), Offset = Vector3.new(0.25, 3.6, 0.45), Color = BROWN },
		{ Name = "Beard", Shape = "Wedge", Size = Vector3.new(0.3, 0.3, 0.15), Offset = Vector3.new(0, 2.95, 0.4), Color = BROWN },
		{ Name = "Mouth", Shape = "Cylinder", Size = Vector3.new(0.3, 0.08, 0.08), Offset = Vector3.new(0, 3.15, 0.5), Color = ROBE },
		{ Name = "ArmL", Shape = "Cylinder", Size = Vector3.new(0.3, 1, 0.3), Offset = Vector3.new(-1.1, 2.2, 0), Color = ROBE },
		{ Name = "ArmR", Shape = "Cylinder", Size = Vector3.new(0.3, 1, 0.3), Offset = Vector3.new(1.1, 2.2, 0), Color = ROBE },
		{ Name = "HandL", Shape = "Sphere", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(-1.1, 1.7, 0), Color = SKIN },
		{ Name = "HandR", Shape = "Sphere", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(1.1, 1.7, 0), Color = SKIN },
		{ Name = "Belt", Shape = "Block", Size = Vector3.new(1.7, 0.15, 1.7), Offset = Vector3.new(0, 1.3, 0), Color = GOLD },
	}

	for _, def in ipairs(parts) do
		local part = Instance.new("Part")
		part.Name = def.Name
		part.Size = def.Size
		part.Anchored = false
		part.CanCollide = false
		part.BrickColor = def.Color
		part.Material = def.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.Parent = model
		if def.Shape == "Sphere" then
			part.Shape = Enum.PartType.Ball
		elseif def.Shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif def.Shape == "Wedge" then
			part.Shape = Enum.PartType.Wedge
		end
		local cf = root.CFrame * CFrame.new(def.Offset)
		part.CFrame = cf
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	-- BillboardGui label
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.new(0, 4, 0, 1.2)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "掌柜"
	label.TextColor3 = Color3.new(1, 1, 0)
	label.TextSize = 20
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0.3
	label.Parent = bb

	model.Parent = Workspace
	return model, root
end

-- ============================================================
-- Animation: Breathing float
-- ============================================================
local function startBreathing(root)
	local upPos = root.Position + Vector3.new(0, 0.3, 0)
	local downPos = root.Position
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(root, tweenInfo, { Position = upPos })
	tween:Play()
	return tween
end

-- ============================================================
-- Animation: Head turn
-- ============================================================
local function startHeadTurn(model)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local baseCF = head.CFrame
	local t = 0
	coroutine.wrap(function()
		while head and head.Parent do
			t = t + 0.05
			local angle = math.sin(t * 0.5) * 0.25
			head.CFrame = baseCF * CFrame.Angles(0, angle, 0)
			task.wait(0.05)
		end
	end)()
end

-- ============================================================
-- Animation: Arm wave
-- ============================================================
local function startArmWave(model)
	local arm = model:FindFirstChild("ArmR")
	if not arm then return end
	local baseCF = arm.CFrame
	coroutine.wrap(function()
		while arm and arm.Parent do
			task.wait(math.random(6, 10))
			if not arm or not arm.Parent then break end
			arm.CFrame = baseCF * CFrame.Angles(0, 0, -0.3)
			task.wait(0.3)
			arm.CFrame = baseCF
			task.wait(0.2)
		end
	end)()
end

-- ============================================================
-- Touch binding — fires ShopEvent "Pick:Shop"
-- ============================================================
local function bindTouch(model)
	local ShopEvent = ReplicatedStorage:FindFirstChild("Events") and
		ReplicatedStorage.Events:FindFirstChild("ShopEvent")
	if not ShopEvent then
		warn("ShopkeeperNPC: ShopEvent not found")
		return
	end

	local debounce = {}
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") and child.Name ~= "ShopkeeperRoot" then
			child.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then return end
				local userId = player.UserId
				if debounce[userId] then return end
				debounce[userId] = true
				ShopEvent:FireServer("Pick:Shop")
				task.wait(0.5)
				debounce[userId] = nil
			end)
		end
	end
end

-- ============================================================
-- Public API
-- ============================================================
local ShopkeeperNPC = {}

function ShopkeeperNPC.Spawn(position)
	local model, root = buildMerchant(position)
	startBreathing(root)
	startHeadTurn(model)
	startArmWave(model)
	bindTouch(model)
	print("🏪 掌柜已就位 at " .. tostring(position))
	return model
end

return ShopkeeperNPC
