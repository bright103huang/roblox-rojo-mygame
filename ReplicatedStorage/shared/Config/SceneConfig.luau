-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.SceneConfig.luau
-- 功能：集中管理所有场景的叙事数据与出生坐标
-- ============================================================

local SceneConfig = {
	-- 人间（传菜打工）
	Work = {
		SpawnPosition = Vector3.new(0, 3, 0),
	},

	-- 炼丹洞天
	Alchemy = {
		SpawnPosition = Vector3.new(1000, 3, 0),
	},

	-- 妖兽战场
	Beast = {
		SpawnPosition = Vector3.new(2000, 3, 0),
	},

	-- 仙丹阁
	DanShop = {
		SpawnPosition = Vector3.new(-1000, 3, 0),
	},

	-- 南天门（考编考核地点）
	SouthGate = {
		SpawnPosition = Vector3.new(-2000, 3, 0),
		Scenes = {
			{
				Text = "你来到南天门前，云雾缭绕，天兵林立...",
				ImageId = "rbxassetid://6035084653",
			},
			{
				Text = "一名天将打量着你：「你就是那个想考编的？」",
				ImageId = "rbxassetid://1234567890",
			},
			{
				Text = "「身法、火候、仙力均达标的苗子，难得。准了。」",
				ImageId = "rbxassetid://9876543210",
			},
			{
				Text = "你换上金甲，正式成为蟠桃园天兵守卫！",
				ImageId = "rbxassetid://6035084653",
			},
		}
	},

	-- 蟠桃园（天兵驻地）
	PeachGarden = {
		SpawnPosition = Vector3.new(3000, 3, 50),
	},

	-- ============================================================
	-- 大闹天宫结局场景
	-- ============================================================
	EndingLoyal = {
		SpawnPosition = Vector3.new(6000, 3, 2),
		Scenes = {
			{
				Text = "你临危不乱，护住了蟠桃园。天庭降旨：破格提拔为天将！",
				ImageId = "rbxassetid://6035084653",
			},
			{
				Text = "从此你统领一队天兵，镇守南天门，威震四方。",
				ImageId = "rbxassetid://1234567890",
			},
		}
	},
	EndingWukong = {
		SpawnPosition = Vector3.new(6000, 3, 2),
		Scenes = {
			{
				Text = "你跟着孙悟空一路打出南天门，身后天兵天将追来...",
				ImageId = "rbxassetid://6035084653",
			},
			{
				Text = "「好兄弟，跟我回花果山，吃桃喝酒！」大圣拍了拍你的肩。",
				ImageId = "rbxassetid://1234567890",
			},
		}
	},
	EndingChaos = {
		SpawnPosition = Vector3.new(6000, 3, 2),
		Scenes = {
			{
				Text = "趁天宫大乱，你卷走了蟠桃园里最后一筐仙桃...",
				ImageId = "rbxassetid://6035084653",
			},
			{
				Text = "三界从此多了一个无名散仙，没人知道你藏在哪里。",
				ImageId = "rbxassetid://1234567890",
			},
		}
	},
}

return SceneConfig