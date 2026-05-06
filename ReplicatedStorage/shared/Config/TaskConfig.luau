-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.TaskConfig.luau
-- 功能：集中管理所有打工任务的定义配置
-- 架构：Task Handler 模式 — 每种任务是一个独立的处理器模块
--       新增任务只需在此添加配置 + 新建处理器文件即可
-- ============================================================

local TaskConfig = {
	-- ============================================================
	-- 任务列表
	-- ============================================================
	Tasks = {
		Deliver = {
			-- 显示名称
			DisplayName = "传菜",

			-- 描述
			Description = "将御膳房的菜品送到指定仙桌",

			-- 任务处理器模块路径（Server 端）
			HandlerModule = "Tasks.DeliverTask",

			-- 交互区域配置
			InteractionAreas = {
				Pickup = {
					PartName = "DishArea",
					FireAction = "Pick",
				},
				Drop = {
					PartName = "TableArea",
					FireAction = "Drop",
					NeedsAttribute = "TableId",
				},
			},

			-- 奖励类型（对应 EconomyConfig.Rewards 的键名）
			RewardType = "Deliver",

			-- 是否需要目标分配（如随机选桌子等）
			TargetRequired = true,

			-- 完成时是否在目标位置生成物体
			SpawnOnComplete = true,

			-- 速度成长配置
			SpeedGrowth = {
				Enabled = true,         -- 是否开启
				DeliveriesPerLevel = 6, -- 每 N 次交付升一级
				SpeedPerLevel = 1,      -- 每级增加 WalkSpeed
				MaxBonusSpeed = 10,     -- 最大额外速度
			},
		},

		-- ============================================================
		-- 预留：后续在此添加新任务
		-- ============================================================

		Alchemy = {
			DisplayName = "炼丹",
			Description = "在丹房炼制仙丹，提升火候修为",
			HandlerModule = "Tasks.AlchemyTask",
			InteractionAreas = {
				Pickup = {
					PartName = "IngredientTable",
					FireAction = "Pick",
				},
				Drop = {
					PartName = "Furnace",
					FireAction = "Drop",
				},
			},
			RewardType = "Alchemy",
			TargetRequired = false,
			SpawnOnComplete = false,
		},

		Beast = {
			DisplayName = "妖兽",
			Description = "前往妖兽谷狩猎，淬炼仙力",
			HandlerModule = "Tasks.BeastTask",
			InteractionAreas = {
				Pickup = {
					PartName = "BeastSpawn",
					FireAction = "Pick",
				},
				Drop = {
					PartName = "BeastHitbox",
					FireAction = "Attack",
				},
			},
			RewardType = "BeastKill",
			TargetRequired = false,
			SpawnOnComplete = false,
		},

		-- ============================================================
		-- 天兵任务（入职后解锁）
		-- ============================================================

		Patrol = {
			DisplayName = "巡逻",
			Description = "在蟠桃园中巡逻，守护仙桃",
			HandlerModule = "Tasks.PatrolTask",
			InteractionAreas = {
				Pickup = {
					PartName = "PatrolStart",
					FireAction = "Pick",
				},
				Drop = {
					PartName = "PatrolPoint",
					FireAction = "Drop",
				},
			},
			RewardType = "Patrol",
			TargetRequired = false,
			SpawnOnComplete = false,
		},

		ExpelMonkey = {
			DisplayName = "驱猴",
			Description = "驱赶偷桃的猴妖",
			HandlerModule = "Tasks.ExpelMonkeyTask",
			InteractionAreas = {
				Pickup = {
					PartName = "MonkeySpawn",
					FireAction = "Pick",
				},
				Drop = {
					PartName = "Monkey",
					FireAction = "Drop",
				},
			},
			RewardType = "ExpelMonkey",
			TargetRequired = false,
			SpawnOnComplete = false,
		},
	},

	-- ============================================================
	-- 全局通用配置
	-- ============================================================
	General = {
		-- 当前活跃的任务列表（留空则启用全部）
		ActiveTasks = nil, -- nil 表示全部启用，或 {"Deliver"}

		-- 交互防抖时间（秒）
		DebounceTime = 0.3,
	},
}

return TaskConfig
