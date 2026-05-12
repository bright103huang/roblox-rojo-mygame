--[[
  ShopkeeperNPC — 仙丹阁掌柜
  18-part NPC built with Anchored parts (no WeldConstraint — allows CFrame animation)
  Animations: breathing float, head turn, arm wave
  Touch binding: handled by ShopUI.local.lua (client-side)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- Part definitions (relative offsets from root)
-- ============================================================
local PART_DEFS = {
	{ Name = "RobeUpper", Shape = "Cylinder", Size = Vector3.new(1.8, 1.4, 1.8), Offset = Vector3.new(0, 1.8, 0), Color = BrickColor.new("Dark red") },
	{ Name = "RobeLower", Shape = "Cylinder", Size = Vector3.new(2.2, 0.8, 2.2), Offset = Vector3.new(0, 0.8, 0), Color = BrickColor.new("Dark red") },
	{ Name = "Head", Shape = "Sphere", Size = Vector3.new(1.2, 1.2, 1.2), Offset = Vector3.new(0, 3.2, 0), Color = BrickColor.new("Light reddish violet") },
	{ Name = "HatTop", Shape = "Sphere", Size = Vector3.new(1, 0.6, 1), Offset = Vector3.new(0, 4, 0), Color = BrickColor.new("Black") },
	{ Name = "HatBrim", Shape = "Block", Size = Vector3.new(1.2, 0.15, 1.2), Offset = Vector3.new(0, 3.7, 0), Color = BrickColor.new("Black") },
	{ Name = "EyeL", Shape = "Sphere", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(-0.25, 3.4, 0.45), Color = BrickColor.new("White"), Neon = true },
	{ Name = "EyeR", Shape = "Sphere", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(0.25, 3.4, 0.45), Color = BrickColor.new("White"), Neon = true },
	{ Name = "PupilL", Shape = "Sphere", Size = Vector3.new(0.1, 0.1, 0.1), Offset = Vector3.new(-0.25, 3.4, 0.6), Color = BrickColor.new("Black") },
	{ Name = "PupilR", Shape = "Sphere", Size = Vector3.new(0.1, 0.1, 0.1), Offset = Vector3.new(0.25, 3.4, 0.6), Color = BrickColor.new("Black") },
	{ Name = "EyebrowL", Shape = "Wedge", Size = Vector3.new(0.35, 0.1, 0.1), Offset = Vector3.new(-0.25, 3.6, 0.45), Color = BrickColor.new("Brown") },
	{ Name = "EyebrowR", Shape = "Wedge", Size = Vector3.new(0.35, 0.1, 0.1), Offset = Vector3.new(0.25, 3.6, 0.45), Color = BrickColor.new("Brown") },
	{ Name = "Beard", Shape = "Wedge", Size = Vector3.new(0.3, 0.3, 0.15), Offset = Vector3.new(0, 2.95, 0.4), Color = BrickColor.new("Brown") },
	{ Name = "Mouth", Shape = "Cylinder", Size = Vector3.new(0.3, 0.08, 0.08), Offset = Vector3.new(0, 3.15, 0.5), Color = BrickColor.new("Dark red") },
	{ Name = "ArmL", Shape = "Cylinder", Size = Vector3.new(0.3, 1, 0.3), Offset = Vector3.new(-1.1, 2.2, 0), Color = BrickColor.new("Dark red") },
	{ Name = "ArmR", Shape = "Cylinder", Size = Vector3.new(0.3, 1, 0.3), Offset = Vector3.new(1.1, 2.2, 0), Color = BrickColor.new("Dark red") },
	{ Name = "HandL", Shape = "Sphere", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(-1.1, 1.7, 0), Color = BrickColor.new("Light reddish violet") },
	{ Name = "HandR", Shape = "Sphere", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(1.1, 1.7, 0), Color = BrickColor.new("Light reddish violet") },
	{ Name = "Belt", Shape = "Block", Size = Vector3.new(1.7, 0.15, 1.7), Offset = Vector3.new(0, 1.3, 0), Color = BrickColor.new("Bright yellow") },
}

-- Cache offsets for animation lookups
local OFFSETS = {}
for _, def in ipairs(PART_DEFS) do
	OFFSETS[def.Name] = def.Offset
end

-- ============================================================
-- Build NPC
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

	local partMap = {}
	for _, def in ipairs(PART_DEFS) do
		local part = Instance.new("Part")
		part.Name = def.Name
		part.Size = def.Size
		part.Anchored = true
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
		part.CFrame = root.CFrame * CFrame.new(def.Offset)
		partMap[def.Name] = part
	end

	-- BillboardGui
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
	return model, root, partMap
end

-- ============================================================
-- Animation: Breathing float (Tween on root Position)
-- ============================================================
local function startBreathing(root)
	local upPos = root.Position + Vector3.new(0, 0.3, 0)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(root, tweenInfo, { Position = upPos })
	tween:Play()
	return tween
end

-- ============================================================
-- Animation: Head turn (updates CFrame relative to root)
-- ============================================================
local function startHeadTurn(root, partMap)
	local head = partMap["Head"]
	if not head then return end
	coroutine.wrap(function()
		local t = 0
		local hOffset = OFFSETS["Head"]
		while head and head.Parent and root and root.Parent do
			t = t + 0.05
			local angle = math.sin(t * 0.5) * 0.25
			head.CFrame = root.CFrame * CFrame.new(hOffset) * CFrame.Angles(0, angle, 0)
			task.wait(0.05)
		end
	end)()
end

-- ============================================================
-- Animation: Arm wave
-- ============================================================
local function startArmWave(root, partMap)
	local arm = partMap["ArmR"]
	if not arm then return end
	local aOffset = OFFSETS["ArmR"]
	coroutine.wrap(function()
		while arm and arm.Parent and root and root.Parent do
			task.wait(math.random(6, 10))
			if not arm or not arm.Parent or not root or not root.Parent then break end
			arm.CFrame = root.CFrame * CFrame.new(aOffset) * CFrame.Angles(0, 0, -0.3)
			task.wait(0.3)
			arm.CFrame = root.CFrame * CFrame.new(aOffset)
			task.wait(0.2)
		end
	end)()
end

-- ============================================================
-- Public API
-- ============================================================
local ShopkeeperNPC = {}

function ShopkeeperNPC.Spawn(position)
	local model, root, partMap = buildMerchant(position)
	startBreathing(root)
	startHeadTurn(root, partMap)
	startArmWave(root, partMap)
	print("🏪 掌柜已就位 at " .. tostring(position))
	return model
end

return ShopkeeperNPC
