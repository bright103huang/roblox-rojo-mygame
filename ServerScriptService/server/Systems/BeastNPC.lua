-- ============================================================
-- 文件：ServerScriptService.Server.Systems.BeastNPC.lua
-- 功能：角斗场妖兽 — 三击碰撞战斗系统
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StatusService = require(script.Parent.StatusService)
local DataManager = require(script.Parent.DataManager)
local Config = require(ReplicatedStorage.Shared.Config)
local RiskConfig = require(ReplicatedStorage.Shared.Config.RiskConfig)

-- ============================================================
-- 妖兽属性配置
-- ============================================================
local BEAST_TIERS = {
	Normal = { Name = "妖兽·普通", Damage = 5, Strength = 3, RewardMult = 1, RingColor = BrickColor.new("Bright green") },
	Elite  = { Name = "妖兽·精英", Damage = 8, Strength = 6, RewardMult = 2, RingColor = BrickColor.new("Bright yellow") },
	Boss   = { Name = "妖兽·BOSS",  Damage = 12, Strength = 10, RewardMult = 3, RingColor = BrickColor.new("Really red") },
}

local CHARGE_SPEED = 50      -- 冲锋速度（格/秒）
local BOUNCE_BACK = 5        -- 弹回距离
local RING_RADIUS = 3.5
local RING_BALL_COUNT = 8
local PLAYER_WAIT_TIMEOUT = 12  -- 每轮等待玩家靠近的超时（秒）

-- ============================================================
-- 妖兽形象定义（Part 组合，2D：Z=0）
-- ============================================================
local ANIMAL_SHAPES = {
	Wolf = {
		Name = "狼妖",
		Color = BrickColor.new("Cool grey"),
		Scale = 1,
		Parts = {
			{ Name = "Body", Size = Vector3.new(2.4, 1, 1.4),  Offset = Vector3.new(0, 1.2, 0) },
			{ Name = "Head", Size = Vector3.new(1, 0.8, 1.2), Offset = Vector3.new(1.6, 1.4, 0) },
			{ Name = "LegFL", Size = Vector3.new(0.3, 0.6, 0.3), Offset = Vector3.new(-0.8, 0.4, 0.7), Cylinder = true },
			{ Name = "LegFR", Size = Vector3.new(0.3, 0.6, 0.3), Offset = Vector3.new(-0.8, 0.4, -0.7), Cylinder = true },
			{ Name = "LegBL", Size = Vector3.new(0.3, 0.6, 0.3), Offset = Vector3.new(0.8, 0.4, 0.7), Cylinder = true },
			{ Name = "LegBR", Size = Vector3.new(0.3, 0.6, 0.3), Offset = Vector3.new(0.8, 0.4, -0.7), Cylinder = true },
			{ Name = "Tail", Size = Vector3.new(0.2, 0.7, 0.2), Offset = Vector3.new(-1.6, 1.5, 0), Cylinder = true },
			{ Name = "EyeL", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(1.8, 1.7, 0.35), Neon = true, EyeColor = BrickColor.new("Bright yellow") },
			{ Name = "EyeR", Size = Vector3.new(0.25, 0.25, 0.25), Offset = Vector3.new(1.8, 1.7, -0.35), Neon = true, EyeColor = BrickColor.new("Bright yellow") },
		},
	},
	Tiger = {
		Name = "虎妖",
		Color = BrickColor.new("Bright orange"),
		Scale = 1.1,
		Parts = {
			{ Name = "Body", Size = Vector3.new(2.8, 1.2, 1.6),  Offset = Vector3.new(0, 1.4, 0) },
			{ Name = "Head", Size = Vector3.new(1.2, 1, 1.3), Offset = Vector3.new(1.8, 1.6, 0) },
			{ Name = "LegFL", Size = Vector3.new(0.35, 0.7, 0.35), Offset = Vector3.new(-1, 0.5, 0.8), Cylinder = true },
			{ Name = "LegFR", Size = Vector3.new(0.35, 0.7, 0.35), Offset = Vector3.new(-1, 0.5, -0.8), Cylinder = true },
			{ Name = "LegBL", Size = Vector3.new(0.35, 0.7, 0.35), Offset = Vector3.new(1, 0.5, 0.8), Cylinder = true },
			{ Name = "LegBR", Size = Vector3.new(0.35, 0.7, 0.35), Offset = Vector3.new(1, 0.5, -0.8), Cylinder = true },
			{ Name = "Tail", Size = Vector3.new(0.25, 0.8, 0.25), Offset = Vector3.new(-1.8, 1.7, 0), Cylinder = true },
			{ Name = "Stripe1", Size = Vector3.new(0.1, 0.3, 0.6), Offset = Vector3.new(-0.5, 1.5, 0.6), StripeColor = BrickColor.new("Black") },
			{ Name = "Stripe2", Size = Vector3.new(0.1, 0.3, 0.6), Offset = Vector3.new(0.5, 1.5, -0.6), StripeColor = BrickColor.new("Black") },
			{ Name = "EyeL", Size = Vector3.new(0.3, 0.3, 0.3), Offset = Vector3.new(2, 1.9, 0.4), Neon = true, EyeColor = BrickColor.new("Bright green") },
			{ Name = "EyeR", Size = Vector3.new(0.3, 0.3, 0.3), Offset = Vector3.new(2, 1.9, -0.4), Neon = true, EyeColor = BrickColor.new("Bright green") },
		},
	},
	Snake = {
		Name = "蛇妖",
		Color = BrickColor.new("Bright violet"),
		Scale = 1,
		Parts = {
			{ Name = "Body1", Size = Vector3.new(0.8, 0.8, 0.8), Offset = Vector3.new(0, 1.2, 0), Ball = true },
			{ Name = "Body2", Size = Vector3.new(0.7, 0.7, 0.7), Offset = Vector3.new(-0.7, 1, 0), Ball = true },
			{ Name = "Body3", Size = Vector3.new(0.6, 0.6, 0.6), Offset = Vector3.new(-1.3, 0.8, 0), Ball = true },
			{ Name = "Head", Size = Vector3.new(0.9, 0.6, 1.2), Offset = Vector3.new(0.9, 1.4, 0) },
			{ Name = "EyeL", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(1.1, 1.6, 0.35), Neon = true, EyeColor = BrickColor.new("Really red") },
			{ Name = "EyeR", Size = Vector3.new(0.2, 0.2, 0.2), Offset = Vector3.new(1.1, 1.6, -0.35), Neon = true, EyeColor = BrickColor.new("Really red") },
		},
	},
	Dragon = {
		Name = "龙妖",
		Color = BrickColor.new("Really red"),
		Scale = 1.3,
		Parts = {
			{ Name = "Body", Size = Vector3.new(3.2, 1.5, 2), Offset = Vector3.new(0, 1.6, 0) },
			{ Name = "Head", Size = Vector3.new(1.5, 1.2, 1.5), Offset = Vector3.new(2.2, 1.8, 0) },
			{ Name = "HornL", Size = Vector3.new(0.2, 0.5, 0.2), Offset = Vector3.new(2.2, 2.5, 0.5), Cylinder = true, HornColor = BrickColor.new("Dark grey") },
			{ Name = "HornR", Size = Vector3.new(0.2, 0.5, 0.2), Offset = Vector3.new(2.2, 2.5, -0.5), Cylinder = true, HornColor = BrickColor.new("Dark grey") },
			{ Name = "LegFL", Size = Vector3.new(0.4, 0.8, 0.4), Offset = Vector3.new(-1.2, 0.5, 1), Cylinder = true },
			{ Name = "LegFR", Size = Vector3.new(0.4, 0.8, 0.4), Offset = Vector3.new(-1.2, 0.5, -1), Cylinder = true },
			{ Name = "LegBL", Size = Vector3.new(0.4, 0.8, 0.4), Offset = Vector3.new(1.2, 0.5, 1), Cylinder = true },
			{ Name = "LegBR", Size = Vector3.new(0.4, 0.8, 0.4), Offset = Vector3.new(1.2, 0.5, -1), Cylinder = true },
			{ Name = "WingL", Size = Vector3.new(0.1, 2, 1.2), Offset = Vector3.new(-0.5, 2.5, 1.2), WingColor = BrickColor.new("Dark red") },
			{ Name = "WingR", Size = Vector3.new(0.1, 2, 1.2), Offset = Vector3.new(-0.5, 2.5, -1.2), WingColor = BrickColor.new("Dark red") },
			{ Name = "EyeL", Size = Vector3.new(0.35, 0.35, 0.35), Offset = Vector3.new(2.6, 2.1, 0.5), Neon = true, EyeColor = BrickColor.new("White") },
			{ Name = "EyeR", Size = Vector3.new(0.35, 0.35, 0.35), Offset = Vector3.new(2.6, 2.1, -0.5), Neon = true, EyeColor = BrickColor.new("White") },
		},
	},
}

-- ============================================================
-- 状态
-- ============================================================
local activeBeasts = {}
local nextBeastId = 0

-- ============================================================
-- 工具函数
-- ============================================================
local function getTaskEvent()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then return nil end
	return eventsFolder:FindFirstChild("TaskEvent")
end

-- 创建旋转光环（8 个 Neon 球体环绕）
local ringRotationLoops = {}
local function createLightRing(centerPart, color)
	local ring = Instance.new("Model")
	ring.Name = "LightRing"
	local balls = {}
	for i = 1, RING_BALL_COUNT do
		local ball = Instance.new("Part")
		ball.Size = Vector3.new(0.8, 0.8, 0.8)
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.Material = Enum.Material.Neon
		ball.BrickColor = color
		ball.Transparency = 0.15
		ball.Parent = ring
		balls[i] = ball
	end
	ring.Parent = centerPart

	local tag = {}
	ringRotationLoops[tag] = true
	task.spawn(function()
		local angle = 0
		while ringRotationLoops[tag] and ring.Parent and centerPart and centerPart.Parent do
			angle = angle + 0.08
			local pos = centerPart.Position
			for i, ball in ipairs(balls) do
				local a = angle + (i / RING_BALL_COUNT) * math.pi * 2
				ball.Position = Vector3.new(
					pos.X + math.cos(a) * RING_RADIUS,
					pos.Y + math.sin(a) * RING_RADIUS + 1,
					0
				)
			end
			task.wait(0.05)
		end
	end)

	return ring, tag
end

local function stopRingRotation(tag)
	if tag then
		ringRotationLoops[tag] = nil
	end
end

-- 将光环闪白后恢复
local function ringFlash(ring, color)
	if not ring or not ring.Parent then return end
	for _, ball in ipairs(ring:GetChildren()) do
		if ball:IsA("Part") then
			ball.Color = Color3.new(1, 1, 1)
		end
	end
	task.wait(0.15)
	for _, ball in ipairs(ring:GetChildren()) do
		if ball:IsA("Part") then
			ball.BrickColor = color
		end
	end
end

-- 创建妖兽躯体
local function buildAnimalShape(npc, root, animalDef)
	local s = animalDef.Scale or 1
	root.Size = Vector3.new(0.5, 0.5, 0.5)
	root.Transparency = 1

	for _, partDef in ipairs(animalDef.Parts) do
		local part = Instance.new("Part")
		part.Name = partDef.Name
		part.Size = partDef.Size * s
		part.Anchored = false
		part.CanCollide = false
		part.Material = partDef.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.BrickColor = partDef.EyeColor or partDef.StripeColor or partDef.HornColor or partDef.WingColor or animalDef.Color
		part.Parent = npc
		if partDef.Ball then
			part.Shape = Enum.PartType.Ball
		elseif partDef.Cylinder then
			part.Shape = Enum.PartType.Cylinder
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		-- Set the part's position relative to the root
		local partOffset = partDef.Offset * s
		part.CFrame = root.CFrame * CFrame.new(partOffset)
	end

	-- 龙妖额外火焰粒子
	if animalDef.Name == "龙妖" then
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 15
		fire.Parent = root
	end
end

-- ============================================================
-- BeastNPC
-- ============================================================
local BeastNPC = {}

-- 生成妖兽（角斗场入口）
function BeastNPC.SpawnBeast(player, spawnPart, tier)
	local tierCfg = BEAST_TIERS[tier] or BEAST_TIERS.Normal

	nextBeastId += 1
	local beastId = nextBeastId
print("🐾 SpawnBeast: player=" .. player.Name .. " tier=" .. tostring(tier) .. " centerPos=" .. tostring(spawnPart.Position))
	local centerPos = spawnPart.Position

	-- 创建妖兽 Model
	local npc = Instance.new("Model")
	npc.Name = "Beast_" .. beastId

	-- Root（透明锚点）
	local root = Instance.new("Part")
	root.Name = "BeastRoot"
	root.Size = Vector3.new(0.5, 0.5, 0.5)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	-- 放置在右侧铁门处
	root.Position = Vector3.new(centerPos.X + 28, centerPos.Y - 0.5, 0)
	root.Parent = npc
	npc.PrimaryPart = root

	-- 选随机形象
	local shapeNames = { "Wolf", "Tiger", "Snake" }
	if tier == "Boss" then
		shapeNames = { "Dragon" }
	end
	local animalName = shapeNames[math.random(1, #shapeNames)]
	local animalDef = ANIMAL_SHAPES[animalName]
	buildAnimalShape(npc, root, animalDef)

	npc.Parent = workspace

	-- 创建光环（妖兽的）
	local ringColor = tierCfg.RingColor or BrickColor.new("Bright green")
	local beastRing, ringTag = createLightRing(root, ringColor)

	-- 创建玩家光环
	local playerRing = nil
	local playerRingTag = nil
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			playerRing, playerRingTag = createLightRing(hrp, BrickColor.new("Bright yellow"))
		end
	end

	-- 保存妖兽状态
	local beastState = {
		Id = beastId,
		NPC = npc,
		Root = root,
		SpawnPart = spawnPart,
		Player = player,
		Tier = tier,
		Stats = tierCfg,
		AnimalName = animalName,
		AnimalDef = animalDef,
		Ring = beastRing,
		RingTag = ringTag,
		PlayerRing = playerRing,
		PlayerRingTag = playerRingTag,
		RingColor = ringColor,
		StartX = centerPos.X + 28,
		FightStarted = false,
	}

	activeBeasts[beastId] = beastState

	-- 启动战斗序列
	task.spawn(function()
		BeastNPC:FightSequence(beastId)
	end)

	print("🏟️ " .. player.Name .. " 踏入角斗场！迎战 " .. animalDef.Name .. "（" .. tierCfg.Name .. "）")
	return beastId
end

-- ============================================================
-- 战斗序列（三击碰撞）
-- ============================================================
function BeastNPC:FightSequence(beastId)
	local beast = activeBeasts[beastId]
	if not beast then return end

	local player = beast.Player
	if not player or not player.Parent then
		BeastNPC.Despawn(beastId, "player left")
		return
	end

	local root = beast.Root
	beast.FightStarted = true

	-- 通知客户端战斗开始
	local taskEvent = getTaskEvent()
	if taskEvent then
		taskEvent:FireClient(player, "BeastFightStart", {
			BeastId = beastId,
			Tier = beast.Tier,
			AnimalName = beast.AnimalName,
		})
	end

	-- Round 1：自动冲锋（妖兽从右向左冲）
	local round1Ok = self:DoChargeRound(beastId, 1, true)
	if not round1Ok then return end
	task.wait(1)

	-- Round 2：等待玩家走近
	local round2Ok = self:DoChargeRound(beastId, 2, false)
	if not round2Ok then return end
	task.wait(1)

	-- Round 3：同上
	local round3Ok = self:DoChargeRound(beastId, 3, false)
	if not round3Ok then return end
	task.wait(0.5)

	-- 结算
	self:SettleFight(beastId)
end

-- 单轮冲锋碰撞
function BeastNPC:DoChargeRound(beastId, roundNum, isAuto)
	local beast = activeBeasts[beastId]
	if not beast then return false end

	local player = beast.Player
	if not player or not player.Parent then
		BeastNPC.Despawn(beastId, "player left")
		return false
	end

	local char = player.Character
	if not char then
		task.wait(0.5)
		char = player.Character
		if not char then
			BeastNPC.Despawn(beastId, "no character")
			return false
		end
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local root = beast.Root

	if not isAuto then
		-- 等待玩家走近妖兽
		local waited = 0
		local playerClose = false
		while waited < PLAYER_WAIT_TIMEOUT do
			if not root or not root.Parent then return false end
			char = player.Character
			if not char then
				task.wait(0.5)
				char = player.Character
				if not char then
					waited += 0.5
					continue
				end
			end
			hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				task.wait(0.5)
				waited += 0.5
				continue
			end

			local dist = math.abs(hrp.Position.X - root.Position.X)
			if dist < 18 then
				playerClose = true
				break
			end
			task.wait(0.3)
			waited += 0.3
		end

		if not playerClose then
			BeastNPC.Despawn(beastId, "player too far")
			return false
		end
	end

	-- 执行冲锋碰撞动画
	self:CollisionAnimation(beastId, roundNum)
	return true
end

-- 冲锋碰撞动画
function BeastNPC:CollisionAnimation(beastId, roundNum)
	local beast = activeBeasts[beastId]
	if not beast then return end

	local player = beast.Player
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local root = beast.Root
	local startX = root.Position.X
	local targetX = hrp.Position.X

	-- 冲锋方向：1=玩家在右，-1=玩家在左
	local chargeDir = targetX > startX and 1 or -1
	local chargeEnd = targetX - chargeDir * 2  -- 停在玩家面前 2 格

	-- Phase 1：冲锋到玩家面前停下
	local chargeDist = math.abs(targetX - startX)
	local chargeTime = math.min(0.35, chargeDist / CHARGE_SPEED)
	local steps = math.max(3, math.floor(chargeTime / 0.05))

	for i = 1, steps do
		if not root or not root.Parent then return end
		local t = i / steps
		local x = startX + (chargeEnd - startX) * t
		root.CFrame = CFrame.new(Vector3.new(x, root.Position.Y, 0))
		task.wait(0.05)
	end

	-- Phase 2：碰撞闪白
	if beast.Ring then
		ringFlash(beast.Ring, beast.RingColor)
	end
	if beast.PlayerRing and beast.PlayerRing.Parent then
		ringFlash(beast.PlayerRing, BrickColor.new("Bright yellow"))
	end

	-- 通知客户端碰撞事件
	local taskEvent = getTaskEvent()
	if taskEvent then
		taskEvent:FireClient(player, "BeastCollision", {
			BeastId = beastId,
			Round = roundNum,
		})
	end

	-- Phase 3：弹回起始侧
	local bounceTarget = startX + chargeDir * BOUNCE_BACK
	for i = 1, 4 do
		if not root or not root.Parent then return end
		local t = i / 4
		local x = chargeEnd + (bounceTarget - chargeEnd) * t
		root.CFrame = CFrame.new(Vector3.new(x, root.Position.Y, 0))
		task.wait(0.05)
	end

	root.CFrame = CFrame.new(Vector3.new(bounceTarget, root.Position.Y, 0))
end

-- 结算
function BeastNPC:SettleFight(beastId)
	local beast = activeBeasts[beastId]
	if not beast then return end

	local player = beast.Player
	local data = DataManager:GetData(player)
	if not data then
		BeastNPC.Despawn(beastId, "no data")
		return
	end

	-- 20% 概率碰到更强妖兽 → 玩家受伤
	local isStronger = math.random() < 0.2

	local taskEvent = getTaskEvent()

	if isStronger then
		-- 玩家受伤
		local damage = 10 * (beast.Stats.RewardMult or 1)
		StatusService:ApplyCosts(player, { Stamina = -damage })

		if taskEvent then
			taskEvent:FireClient(player, "BeastLost", {
				Damage = damage,
				Tier = beast.Tier,
				Message = "妖兽实力太强！体力 -" .. damage,
			})
		end

		print("💥 " .. player.Name .. " 不敌 " .. (beast.AnimalDef and beast.AnimalDef.Name or "妖兽") .. "，体力 -" .. damage)
		BeastNPC.Despawn(beastId, "player lost")
	else
		-- 玩家胜利
		local mult = beast.Stats.RewardMult or 1
		StatusService:ApplyCosts(player, {
			Stamina = -8 * mult,
			Malice = 3 * mult,
			CombatExp = 8 * mult,
			XianJing = 20 * mult,
			Risk = RiskConfig.Accumulation[beast.Tier] or RiskConfig.Accumulation.NormalKill,
		})

		if taskEvent then
			taskEvent:FireClient(player, "BeastVictory", {
				Tier = beast.Tier,
				AnimalName = beast.AnimalName,
				CombatExp = 8 * mult,
				XianJing = 20 * mult,
				Message = "击败" .. (beast.AnimalDef and beast.AnimalDef.Name or "妖兽") .. "！仙力经验 +" .. (8 * mult) .. " 仙晶 +" .. (20 * mult),
			})
		end

		print("⚔️ " .. player.Name .. " 击败了 " .. (beast.AnimalDef and beast.AnimalDef.Name or "妖兽") .. "！")
		BeastNPC.Despawn(beastId, "killed")
	end
end

-- ============================================================
-- 辅助查询
-- ============================================================

function BeastNPC.GetBeastByPart(part)
	for _, beast in pairs(activeBeasts) do
		if beast.NPC then
			for _, child in ipairs(beast.NPC:GetDescendants()) do
				if child == part then
					return beast
				end
			end
		end
	end
	return nil
end

function BeastNPC.GetPlayerBeast(player)
	for _, beast in pairs(activeBeasts) do
		if beast.Player == player then
			return beast
		end
	end
	return nil
end

-- ============================================================
-- 销毁妖兽
-- ============================================================
function BeastNPC.Despawn(beastId, reason)
	local beast = activeBeasts[beastId]
	if not beast then return end

	stopRingRotation(beast.RingTag)
	stopRingRotation(beast.PlayerRingTag)

	if beast.NPC and beast.NPC.Parent then
		beast.NPC:Destroy()
	end

	if beast.PlayerRing and beast.PlayerRing.Parent then
		beast.PlayerRing:Destroy()
	end

	activeBeasts[beastId] = nil
	print("🏟️ 妖兽（ID:" .. beastId .. "）消失: " .. reason)
end

function BeastNPC.GetActiveBeasts()
	return activeBeasts
end

print("✅ BeastNPC 已加载（角斗场三击碰撞系统）")

return BeastNPC
