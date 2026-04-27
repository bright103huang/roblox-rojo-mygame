-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.SceneConfig.luau
-- 功能：集中管理所有场景的叙事数据与出生坐标
-- ============================================================

local SceneConfig = {
	GoHomeStory = {
		SpawnPosition = Vector3.new(5000, 3, 2),
		Scenes = {
			{
				Text = "你拖着疲惫的身子离开后厨...",
				ImageId = "rbxassetid://6035084653",
			},
			{
				Text = "路旁一个蟠桃核闪闪发光，像是刚被谁啃过...",
				ImageId = "rbxassetid://1234567890",
			},
			{
				Text = "你只是个南天门的小仙，趁着混乱赶紧溜回家躺平...",
				ImageId = "rbxassetid://9876543210",
			},
		}
	},
}

return SceneConfig