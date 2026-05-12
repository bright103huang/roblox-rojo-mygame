# 仙丹阁改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task.

**Goal:** Transform the empty DanShop scene into a grand pharmacy with NPC shopkeeper and bargain dialogue system.

**Architecture:** (1) New `ShopkeeperNPC.lua` builds the NPC from parts (2) `SceneSetup.server.lua` builds grand scene (3) `ShopService.server.lua` adds bargain logic + dialogue DB (4) `ShopUI.local.lua` adds bargain button + dialogue popup.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `ServerScriptService/server/Systems/ShopkeeperNPC.lua` | **Create** | NPC part building + animation loops + BillboardGui + touch binding |
| `ServerScriptService/server/Systems/SceneSetup.server.lua` | **Modify** | Replace `setupShopScene()` with 80-wide grand layout |
| `ServerScriptService/server/Systems/ShopService.server.lua` | **Modify** | Add bargain dialogue DB + `HandleBargain()` + session bargain tracking |
| `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua` | **Modify** | Add bargain button + dialogue popup + discounted price display |

---

### Task 1: Create ShopkeeperNPC.lua

**File:** `ServerScriptService/server/Systems/ShopkeeperNPC.lua`

```lua
--[[
  ShopkeeperNPC — 仙丹阁掌柜
  16-part NPC built with WeldConstraint (follows BeastNPC.buildAnimalShape pattern)
  Animations: breathing float, head turn, arm wave, player tracking
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
```

- [ ] **Step 1: Create file** — Write the complete code above to `ServerScriptService/server/Systems/ShopkeeperNPC.lua`

- [ ] **Step 2: Verify syntax** — Open in Roblox Studio, check Output for any load errors

- [ ] **Step 3: Commit**

```bash
git add ServerScriptService/server/Systems/ShopkeeperNPC.lua
git commit -m "feat: add ShopkeeperNPC module with 18-part merchant + animations + touch binding"
```

---

### Task 2: Rewrite setupShopScene() in SceneSetup.server.lua

**File:** `ServerScriptService/server/Systems/SceneSetup.server.lua`

Replace the existing `setupShopScene()` function (lines 574-626) with:

```lua
-- ============================================================
-- 仙丹阁 — 2D 横版布局（宽敞大气版）
-- ============================================================
local function setupShopScene()
	local origin = SCENES.DanShop
	local W = 80  -- 地面宽
	local H = 12  -- 墙高

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), W, 8, BrickColor.new("Bright violet"), 0.1)
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

	-- 后墙（z=-4）
	createWall(origin + Vector3.new(0, H/2, -4), W, H, 0.5, BrickColor.new("Dark green"))

	-- ============================================================
	-- 药柜墙（后层 Z=-4）
	-- ============================================================
	local cabinetY = 2
	local shelfColors = {
		BrickColor.new("Bright blue"),
		BrickColor.new("Bright violet"),
		BrickColor.new("Gold"),
		BrickColor.new("Bright green"),
		BrickColor.new("Really red"),
		BrickColor.new("Bright orange"),
	}
	for i = 1, 6 do
		local cx = -24 + (i - 1) * 9
		-- 隔板
		createDecor(origin + Vector3.new(cx, cabinetY, -4), Vector3.new(3, 3.5, 0.3), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)
		-- 展示瓶（大号）
		local bottle = createDecor(origin + Vector3.new(cx, cabinetY + 1.2, -4), Vector3.new(1, 1.5, 1), shelfColors[i], Enum.PartType.Cylinder)
		bottle.Material = Enum.Material.Glass
		-- 瓶盖
		createDecor(origin + Vector3.new(cx, cabinetY + 2.2, -4), Vector3.new(0.6, 0.3, 0.6), BrickColor.new("Gold"), Enum.PartType.Cylinder)
		-- 发光底座
		local glow = createDecor(origin + Vector3.new(cx, cabinetY - 0.5, -4), Vector3.new(1.2, 0.2, 1.2), shelfColors[i])
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.3
	end

	-- ============================================================
	-- 柜台（Z=0 交互层）
	-- ============================================================
	createDecor(origin + Vector3.new(0, 0.75, 0), Vector3.new(30, 1.5, 1.5), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)
	-- 台面样品丹（3 瓶）
	for i = 1, 3 do
		local sx = -8 + (i - 1) * 8
		local sample = createDecor(origin + Vector3.new(sx, 1.6, 0), Vector3.new(0.6, 0.6, 0.6), shelfColors[i + 1], Enum.PartType.Cylinder)
		sample.Material = Enum.Material.Glass
		createDecor(origin + Vector3.new(sx, 2.1, 0), Vector3.new(0.3, 0.15, 0.3), BrickColor.new("Gold"), Enum.PartType.Cylinder)
	end

	-- ============================================================
	-- 掌柜 NPC
	-- ============================================================
	local ShopkeeperNPC = require(script.Parent.ShopkeeperNPC)
	ShopkeeperNPC.Spawn(origin + Vector3.new(-3, 0.5, 0))

	-- ============================================================
	-- 牌匾（柜台上方）
	-- ============================================================
	createDecor(origin + Vector3.new(0, 6, -3), Vector3.new(8, 1.5, 0.3), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)
	-- 牌匾边框
	createDecor(origin + Vector3.new(-4, 6, -3), Vector3.new(0.3, 1.8, 0.3), BrickColor.new("Gold"))
	createDecor(origin + Vector3.new(4, 6, -3), Vector3.new(0.3, 1.8, 0.3), BrickColor.new("Gold"))
	-- 牌匾文字用 BillboardGui
	local signPart = createDecor(origin + Vector3.new(0, 6, -2.8), Vector3.new(7.5, 1.2, 0.1), BrickColor.new("Dark brown"))
	local bb = Instance.new("BillboardGui")
	bb.Name = "SignText"
	bb.Size = UDim2.new(0, 8, 0, 2)
	bb.StudsOffset = Vector3.new(0, 0.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = signPart
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "仙丹阁"
	signLabel.TextColor3 = Color3.new(1, 0.85, 0)
	signLabel.TextSize = 28
	signLabel.Font = Enum.Font.SourceSansBold
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = bb

	-- ============================================================
	-- 前层装饰（Z=4）
	-- ============================================================
	-- 左灯笼（入口侧）
	for i = 1, 2 do
		local lx = -35 + (i - 1) * 70
		local pole = createDecor(origin + Vector3.new(lx, 2, 4), Vector3.new(0.3, 4, 0.3), BrickColor.new("Dark brown"))
		local lantern = createDecor(origin + Vector3.new(lx, 3.5, 4), Vector3.new(1.2, 1.2, 1.2), BrickColor.new("Bright red"), Enum.PartType.Cylinder)
		local glowRing = createDecor(origin + Vector3.new(lx, 3.5, 4), Vector3.new(1.4, 0.2, 1.4), BrickColor.new("Bright yellow"))
		glowRing.Material = Enum.Material.Neon
		glowRing.Transparency = 0.5
	end
	-- 盆栽
	createDecor(origin + Vector3.new(-30, 0.8, 4), Vector3.new(1.5, 1.5, 1.5), BrickColor.new("Bright green"), Enum.PartType.Cylinder)
	createDecor(origin + Vector3.new(-30, 0.2, 4), Vector3.new(1.8, 0.4, 1.8), BrickColor.new("Dark brown"), Enum.PartType.Cylinder)
	createDecor(origin + Vector3.new(30, 0.8, 4), Vector3.new(1.5, 1.5, 1.5), BrickColor.new("Bright green"), Enum.PartType.Cylinder)
	createDecor(origin + Vector3.new(30, 0.2, 4), Vector3.new(1.8, 0.4, 1.8), BrickColor.new("Dark brown"), Enum.PartType.Cylinder)

	-- 门槛台阶
	createDecor(origin + Vector3.new(-38, 0.25, 0), Vector3.new(2, 0.5, 3), BrickColor.new("Dark grey"))

	-- 地面砖纹（浅色间隔条）
	for x = -39, 39, 5 do
		createDecor(origin + Vector3.new(x, -0.25, 0), Vector3.new(0.1, 0.05, 7), BrickColor.new("Dark grey"))
	end
	for z = -3, 3, 2 do
		createDecor(origin + Vector3.new(0, -0.25, z), Vector3.new(78, 0.05, 0.1), BrickColor.new("Dark grey"))
	end

	print("💎 仙丹阁已就绪（宽敞大气版）")
end
```

- [ ] **Step 1: Replace setupShopScene()** — Open `SceneSetup.server.lua`, find lines starting at `local function setupShopScene()` and replace the entire function with the code above

- [ ] **Step 2: Verify** — Check in Roblox Studio that the scene renders correctly with all elements

- [ ] **Step 3: Commit**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: redesign DanShop scene with 80-wide grand layout, pharmacy cabinet, counter, signboard, NPC, decorations"
```


---

### Task 3: Add Bargain System to ShopService.server.lua

**File:** `ServerScriptService/server/Systems/ShopService.server.lua`

Add after `ShopService = {}`:
1. Dialogue database (12 questions)
2. pendingBargains tracking table  
3. HandleBargain, GetBargainDiscount, ClearBargains functions

Modify the RemoteEvent listener:
- **Pick:Shop** → add `ShopService:ClearBargains(player)` 
- **Purchase:Shop** → apply 20% discount if bargained
- **Add new** → `Bargain:Shop` listener

See the full code in `docs/superpowers/specs/2026-05-12-danshop-overhaul-design.md` for the dialogue DB.

- [ ] **Step 1: Add bargain DB + functions** — Insert dialogue DB table, pendingBargains, HandleBargain/GetBargainDiscount/ClearBargains after `ShopService = {}`
- [ ] **Step 2: Modify Pick:Shop** — Add `ShopService:ClearBargains(player)` after data check
- [ ] **Step 3: Modify Purchase:Shop** — Apply `GetBargainDiscount()` to price check and deduction
- [ ] **Step 4: Add Bargain:Shop listener** — New action handler for bargain requests
- [ ] **Step 5: Verify** — Check in Roblox Studio that bargain flow works
- [ ] **Step 6: Commit**

```bash
git add ServerScriptService/server/Systems/ShopService.server.lua
git commit -m "feat: add bargain dialogue system with 12 questions + 20% discount mechanic"
```

---

### Task 4: Modify ShopUI.local.lua — Bargain Button + Dialogue Popup

**File:** `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua`

Changes needed:
1. Add "砍价" button next to "购买" in each item slot
2. Add bargain dialogue popup (boss question + 3 option buttons)
3. Handle result display ("老板很开心！8折！" / "老板不高兴，原价")
4. Event flow: click 砍价 → ask server for random question → display choices → send choice → show result

- [ ] **Step 1: Add bargain button** — In item slot creation, add a "砍价" textbutton below "购买", gold background, smaller size
- [ ] **Step 2: Add bargain state per item** — Track which items have been bargained in current session
- [ ] **Step 3: Create dialogue popup** — Frame with boss text + 3 option buttons, positioned over the panel
- [ ] **Step 4: Wire events** — 砍价 → FireServer("Bargain:Shop") → receive question → show popup → option click → FireServer with choice → receive result → update UI
- [ ] **Step 5: Add OnClientEvent handler** — Listen for `BargainResult:Shop` and handle success/failure display
- [ ] **Step 6: Commit**

```bash
git add StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua
git commit -m "feat: add bargain button + dialogue popup to ShopUI"
```

---

## Verification Checklist

1. Enter DanShop → see 80-wide hall, pharmacy cabinet, counter, NPC, signboard, lanterns, floor tiles
2. NPC breathes (Tween float), head turns, arm waves periodically
3. Touch NPC → ShopUI opens (same UI, no regression)
4. Select item → click "砍价" button → boss dialogue popup with 3 options
5. Choose correct option → "老板很开心！8折！" → purchase applies 20% off
6. Choose wrong option → "老板不高兴，原价" → purchase at full price
7. Close and reopen panel → bargain resets (can try again)
8. Verify no errors in Output console
