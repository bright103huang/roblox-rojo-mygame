const fs = require('fs');
const path = require('path');
const filePath = path.resolve(__dirname, '../ServerScriptService/server/Systems/ShopService.server.lua');
let content = fs.readFileSync(filePath, 'utf-8');

// Replace "-- 发放效果" section with backpack
const startStr = '\t-- 发放效果\n';
const endStr = '\treturn "Success", "购买成功！获得 " .. (item.RealName or item.Name)\nend';
const sIdx = content.indexOf(startStr);
const eIdx = content.indexOf(endStr, sIdx) + endStr.length;
if (sIdx === -1 || eIdx === -1) { console.error('ERROR: boundaries'); process.exit(1); }
const newSection =
`\t-- 改为存入背包
\tlocal backpack = data.Backpack or {}
\tbackpack[itemKey] = (backpack[itemKey] or 0) + 1
\tdata.Backpack = backpack
\tDataManager:UpdateField(player, "Backpack", backpack)

\tprint("🛒 " .. player.Name .. " 购买了 " .. (item.RealName or item.Name) .. "（背包 +1）")
\treturn "Success", "购买成功！" .. (item.RealName or item.Name) .. " 已存入背包"
end`;
content = content.substring(0, sIdx) + newSection + content.substring(eIdx);
console.log('OK: Purchase -> Backpack');

// Add UseItem method before OnServerEvent section
const marker = '-- ============================================================\n-- 监听客户端请求\n-- ============================================================';
const iIdx = content.indexOf(marker);
if (iIdx === -1) { console.error('ERROR: marker'); process.exit(1); }
const useItem = `

-- ============================================================
-- 使用物品（从背包消耗，应用效果）
-- isMeditating: 打坐状态效果 x1.5
-- ============================================================
function ShopService:UseItem(player, itemKey, isMeditating)
\tlocal data = DataManager:GetData(player)
\tif not data then return { Success = false, Message = "数据未加载" } end
\tlocal backpack = data.Backpack or {}
\tlocal count = backpack[itemKey] or 0
\tif count <= 0 then return { Success = false, Message = "背包中没有该物品" } end
\tlocal item = DanConfig.Items[itemKey]
\tif not item then return { Success = false, Message = "未知物品" } end
\tbackpack[itemKey] = count - 1
\tif backpack[itemKey] <= 0 then backpack[itemKey] = nil end
\tdata.Backpack = backpack
\tDataManager:UpdateField(player, "Backpack", backpack)
\tlocal effectValue = item.EffectValue
\tif isMeditating then
\t\teffectValue = math.floor(effectValue * 1.5)
\tend
\tlocal effectType = item.EffectType
\tif effectType == "Stamina" or effectType == "Spirit"
\t\tor effectType == "Fatigue" or effectType == "FirePoison"
\t\tor effectType == "Malice" then
\t\tlocal costs = {}
\t\tcosts[effectType] = effectValue
\t\tStatusService:ApplyCosts(player, costs)
\telseif effectType == "AgilityExp" then
\t\tStatusService:AddExp(player, "Agility", effectValue)
\telseif effectType == "AlchemyExp" then
\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)
\telseif effectType == "CombatExp" then
\t\tStatusService:AddExp(player, "Combat", effectValue)
\telseif effectType == "RandomStat" then
\t\tlocal stats = { "Agility", "AlchemyLv", "Combat" }
\t\tlocal chosen = stats[math.random(1, #stats)]
\t\tStatusService:AddExp(player, chosen, effectValue)
\telseif effectType == "AllStats" then
\t\tStatusService:AddExp(player, "Agility", effectValue)
\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)
\t\tStatusService:AddExp(player, "Combat", effectValue)
\tend
\tprint("💊 " .. player.Name .. " 使用了 " .. (item.RealName or item.Name))
\treturn { Success = true, Message = "使用成功" }
end
`;
content = content.substring(0, iIdx) + useItem + '\n\n' + content.substring(iIdx);
console.log('OK: UseItem method added');

fs.writeFileSync(filePath, content, 'utf-8');
console.log('DONE: ShopService fully updated');
