-- ============================================================
-- 文件：ServerScriptService.Server.Systems.BeastNPC.lua
-- 功能：妖兽 NPC 生成、AI、攻击管理
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StatusService = require(script.Parent.StatusService)
local DataManager = require(script.Parent.DataManager)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 妖兽属性配置
-- ============================================================
local BEAST_TIERS = {
	Normal = {
		Name = "妖兽·普通",
		HP = 30,
		Damage = 5,
		Speed = 12,
		RewardMult = 1,
	},
	Elite = {
		Name = "妖兽·精英",
		HP = 60,
		Damage = 8,
		Speed = 15,
		RewardMult = 2,
	},
	Boss = {
		Name = "妖兽·BOSS",
		HP = 120,
		Damage = 12,
		Speed = 18,
		RewardMult = 3,
	},
}

local PATROL_RADIUS = 10
local AGGRO_RANGE = 15
local ATTACK_RANGE = 6
local ATTACK_COOLDOWN = 2
local DESPAWN_TIMEOUT = 30
local FLEE_RANGE = 30

-- ============================================================
-- 状态
-- ============================================================
local activeBeasts = {}  -- [beastId] = beastState
local nextBeastId = 0

-- ============================================================
-- 获取 TaskEvent
-- ============================================================
local function getTaskEvent()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then return nil end
	return eventsFolder:FindFirstChild("TaskEvent")
end

-- ============================================================
-- BeastNPC
-- ============================================================

local BeastNPC = {}

-- 生成妖兽
function BeastNPC.SpawnBeast(player, spawnPart, tier)
	local tierCfg = BEAST_TIERS[tier] or BEAST_TIERS.Normal

	nextBeastId += 1
	local beastId = nextBeastId
	local spawnPos = spawnPart.Position

	-- 创建妖兽 NPC（简单的 Part 组合，2D：Z 锁定为 0）
	local npc = Instance.new("Model")
	npc.Name = "Beast_" .. beastId

	-- 主体（Z=0）
	local root = Instance.new("Part")
	root.Name = "BeastRoot"
	root.Size = Vector3.new(3, 2, 3)
	root.Position = Vector3.new(spawnPos.X, spawnPos.Y + 3, 0)
	root.Anchored = false
	root.CanCollide = true
	root.BrickColor = tier == "Boss" and BrickColor.new("Really red")
		or tier == "Elite" and BrickColor.new("Bright yellow")
		or BrickColor.new("Bright green")
		root.Material = Enum.Material.SmoothPlastic
	root.Parent = npc
	npc.PrimaryPart = root

	-- 碰撞体（Z=0）
	local hitbox = Instance.new("Part")
	hitbox.Name = "BeastHitbox"
	hitbox.Size = Vector3.new(5, 4, 5)
	hitbox.Position = Vector3.new(spawnPos.X, spawnPos.Y + 3, 0)
	hitbox.Anchored = false
	hitbox.CanCollide = false
	hitbox.Transparency = 0.8
	hitbox.BrickColor = BrickColor.new("Bright red")
	hitbox.Parent = npc

	-- 焊接主体和碰撞体
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox

	-- HP 血条 BillBoard
	local bb = Instance.new("BillboardGui")
	bb.Name = "BeastHP"
	bb.Size = UDim2.new(0, 100, 0, 30)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	bb.Parent = root

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Size = UDim2.new(1, 0, 1, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = tierCfg.Name .. ": " .. tierCfg.HP .. "/" .. tierCfg.HP
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0
	hpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	hpLabel.TextSize = 14
	hpLabel.Font = Enum.Font.SourceSansBold
	hpLabel.Parent = bb

	npc.Parent = workspace

	-- 保存妖兽状态
	local beastState = {
		Id = beastId,
		NPC = npc,
		Root = root,
		SpawnPart = spawnPart,
		Player = player,
		Tier = tier,
		HP = tierCfg.HP,
		MaxHP = tierCfg.HP,
		Stats = tierCfg,
		LastPlayerAttackTime = tick(),
		LastBeastAttackTime = 0,
	}

	activeBeasts[beastId] = beastState

	-- 启动 AI
	task.spawn(function()
		BeastNPC:BeastAI(beastId)
	end)

	print("🐾 " .. player.Name .. " 唤醒了 " .. tierCfg.Name .. "（ID:" .. beastId .. "）")
	return beastId
end

-- 妖兽 AI 协程
function BeastNPC:BeastAI(beastId)
	local beast = activeBeasts[beastId]
	if not beast then return end

	local npc = beast.NPC
	local root = beast.Root
	local spawnPos = beast.SpawnPart.Position
	local targetPos = self:RandomPatrolPoint(spawnPos)

	while beast and npc.Parent do
		task.wait(0.1)
		local player = beast.Player
		if not player or not player.Parent then
			BeastNPC.Despawn(beastId, "player left")
			break
		end

		local char = player.Character
		if not char then
			task.wait(0.5)
			char = player.Character
			if not char then continue end
		end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local distance = (root.Position - hrp.Position).Magnitude

		if distance < AGGRO_RANGE then
			-- 追击玩家
			targetPos = hrp.Position

			-- 攻击判定
			local now = tick()
			if distance < ATTACK_RANGE
				and (now - beast.LastBeastAttackTime) >= ATTACK_COOLDOWN then
				beast.LastBeastAttackTime = now
				BeastNPC.BeastAttackPlayer(beastId)
			end
		elseif distance > FLEE_RANGE then
			BeastNPC.Despawn(beastId, "player fled")
			break
		end

		-- 移动
		local direction = (targetPos - root.Position).Unit
		local speed = beast.Stats.Speed
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(180), 0)
		-- 2D 移动（仅 X 轴，Z=0）
		local newPos = root.Position + Vector3.new(
			direction.X * speed * 0.1, 0, 0
		)
		root.CFrame = CFrame.new(Vector3.new(newPos.X, newPos.Y, 0))

		-- 到达巡逻点后选新点
		if (root.Position - targetPos).Magnitude < 2 then
			targetPos = BeastNPC.RandomPatrolPoint(spawnPos)
		end

		-- 超时消失
		local timeSinceAttack = tick() - (beast.LastPlayerAttackTime or tick())
		if timeSinceAttack > DESPAWN_TIMEOUT then
			BeastNPC.Despawn(beastId, "timeout")
			break
		end
	end
end

-- 妖兽攻击玩家
function BeastNPC:BeastAttackPlayer(beastId)
	local beast = activeBeasts[beastId]
	if not beast then return end

	local player = beast.Player
	-- 扣 Stamina
	StatusService:ApplyCosts(player, { Stamina = -beast.Stats.Damage })

	-- 通知客户端
	local taskEvent = getTaskEvent()
	if taskEvent then
		taskEvent:FireClient(player, "BeastHit:Beast", {
			Damage = beast.Stats.Damage,
		})
	end

	print("🐾 妖兽攻击 " .. player.Name .. "，Stamina -" .. beast.Stats.Damage)
end

-- 玩家攻击妖兽
function BeastNPC.PlayerAttackBeast(beastId, player)
	local beast = activeBeasts[beastId]
	if not beast then return false, "NoBeast" end
	if beast.Player ~= player then return false, "NotYourBeast" end

	local data = require(script.Parent.DataManager).GetData(player)
	if not data then return false, "NoData" end

	-- 检查 狂躁 和 入魔倾向 伤害修正
	local hasKuangZao = (data.Fatigue or 0) > Config.Stats.CHAIN_REACTION.CHAIN_RAGE_FATIGUE
		and (data.Malice or 0) > Config.Stats.CHAIN_REACTION.CHAIN_RAGE_MALICE
	local hasRuMo = (data.Malice or 0) > Config.Stats.CHAIN_REACTION.CHAIN_DEMON_MALICE
		and (data.Risk or 10) > Config.Stats.CHAIN_REACTION.CHAIN_DEMON_RISK

	-- 伤害公式：基础 8 + Combat×2
	local damage = 8 + (data.Combat or 1) * 2
	if hasRuMo then
		damage = math.floor(damage * 1.2)  -- +20% 入魔倾向
	end
	if hasKuangZao then
		damage = math.floor(damage * 1.3)  -- +30% 狂躁（与入魔倾向叠加）
	end

	-- 狂躁: 15% 误伤自己
	if hasKuangZao and math.random() < 0.15 then
		local selfDamage = math.floor(damage * 0.3)
		local newStamina = math.max(0, (data.Stamina or 0) - selfDamage)
		data.Stamina = newStamina
		DataManager:UpdateField(player, "Stamina", newStamina)
		local taskEvent = getTaskEvent()
		if taskEvent then
			taskEvent:FireClient(player, "SelfHarm", {
				Damage = selfDamage,
				Message = "狂躁失控！误伤自己，体力 -" .. selfDamage
			})
		end
	end
	beast.HP = beast.HP - damage
	beast.LastPlayerAttackTime = tick()

	-- 更新血条
	local bb = beast.NPC:FindFirstChild("BeastHP", true)
	if bb then
		local label = bb:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = beast.Stats.Name .. ": " .. math.floor(beast.HP) .. "/" .. beast.MaxHP
		end
	end

	if beast.HP <= 0 then
		BeastNPC.Despawn(beastId, "killed")
		return true, { Killed = true, Damage = damage }
	end

	return true, { Killed = false, Damage = damage, RemainingHP = beast.HP }
end

-- 根据 Part 查找妖兽
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

-- 获取玩家的妖兽
function BeastNPC.GetPlayerBeast(player)
	for _, beast in pairs(activeBeasts) do
		if beast.Player == player then
			return beast
		end
	end
	return nil
end

-- 随机巡逻点（2D：Z=0）
function BeastNPC.RandomPatrolPoint(center)
	local dist = math.random() * PATROL_RADIUS
	local dir = math.random() * 2 - 1  -- -1 到 1
	return Vector3.new(center.X + dir * dist, center.Y, 0)
end

-- 销毁妖兽
function BeastNPC.Despawn(beastId, reason)
	local beast = activeBeasts[beastId]
	if not beast then return end
	if beast.NPC and beast.NPC.Parent then
		beast.NPC:Destroy()
	end
	activeBeasts[beastId] = nil
	print("🐾 妖兽（ID:" .. beastId .. "）消失: " .. reason)
end

-- 获取 activeBeasts 引用（用于遍历）
function BeastNPC.GetActiveBeasts()
	return activeBeasts
end

print("✅ BeastNPC 已加载")

return BeastNPC
