const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, '../ServerScriptService/server/Systems/ShopService.server.lua');
let content = fs.readFileSync(filePath, 'utf-8');

// 1. Replace HandleBargain with RequestBargainQuestion + SubmitBargainAnswer
const oldFunc = [
  'function ShopService:HandleBargain(player, itemKey, choiceIndex)',
  '\tlocal data = DataManager:GetData(player)',
  '\tif not data then return { Success = false, Message = "数据未加载" } end',
  '\tlocal item = DanConfig.Items[itemKey]',
  '\tif not item then return { Success = false, Message = "未知商品" } end',
  '',
  '\t-- 没传 choiceIndex = 客户端请求题目',
  '\tif not choiceIndex then',
  '\t\tlocal qId = math.random(1, #BARGAIN_QUESTIONS)',
  '\t\tlocal q = BARGAIN_QUESTIONS[qId]',
  '\t\treturn { Success = true, Question = q.Question, Options = q.Options, QuestionId = qId }',
  '\tend',
  '',
  '\tlocal q = BARGAIN_QUESTIONS[choiceIndex]',
  '\tif not q then return { Success = false, Message = "无效选项" } end',
  '',
  '\tlocal isCorrect = (choiceIndex == q.Correct) or (q.CorrectAlt and choiceIndex == q.CorrectAlt)',
  '\tif isCorrect then',
  '\t\tlocal uid = player.UserId',
  '\t\tif not pendingBargains[uid] then pendingBargains[uid] = {} end',
  '\t\tpendingBargains[uid][itemKey] = true',
  '\t\treturn { Success = true, Message = "老板很开心！给你打 8 折！" }',
  '\telse',
  '\t\treturn { Success = false, Message = "老板不高兴，还是原价吧" }',
  '\tend',
  'end',
].join('\n');

const newFunc = [
  'function ShopService:RequestBargainQuestion(player, itemKey)',
  '\tlocal uid = player.UserId',
  '\tif pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then',
  '\t\treturn { Question = nil }',
  '\tend',
  '\tlocal qId = math.random(1, #BARGAIN_QUESTIONS)',
  '\tlocal q = BARGAIN_QUESTIONS[qId]',
  '\treturn { Question = q.Question, Options = q.Options, QuestionId = qId }',
  'end',
  '',
  'function ShopService:SubmitBargainAnswer(player, itemKey, choiceIndex)',
  '\tlocal q = BARGAIN_QUESTIONS[choiceIndex]',
  '\tif not q then return { Success = false, Message = "无效选项" } end',
  '',
  '\tlocal uid = player.UserId',
  '\tif pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then',
  '\t\treturn { Success = false, Message = "已砍过价了" }',
  '\tend',
  '',
  '\tlocal isCorrect = (choiceIndex == q.Correct) or (q.CorrectAlt and choiceIndex == q.CorrectAlt)',
  '\tif not pendingBargains[uid] then pendingBargains[uid] = {} end',
  '\tif isCorrect then',
  '\t\tpendingBargains[uid][itemKey] = true',
  '\t\treturn { Success = true, Message = "老板很开心！给你打 8 折！" }',
  '\telse',
  '\t\tpendingBargains[uid][itemKey] = false',
  '\t\treturn { Success = false, Message = "老板不高兴，还是原价吧" }',
  '\tend',
  'end',
].join('\n');

if (content.includes(oldFunc)) {
  content = content.replace(oldFunc, newFunc);
  console.log('OK: HandleBargain replaced');
} else {
  console.log('ERROR: HandleBargain oldFunc not matched');
  let idx = content.indexOf('HandleBargain');
  if (idx >= 0) console.log('Found at', idx, 'chars around:', JSON.stringify(content.substring(idx, idx+200)));
  process.exit(1);
}

// 2. Fix GetBargainDiscount — check == true
const oldDiscount = 'if pendingBargains[uid] and pendingBargains[uid][itemKey] then';
const newDiscount = 'if pendingBargains[uid] and pendingBargains[uid][itemKey] == true then';
if (content.includes(oldDiscount)) {
  content = content.replace(oldDiscount, newDiscount);
  console.log('OK: GetBargainDiscount fixed');
} else {
  console.log('ERROR: GetBargainDiscount pattern not found');
  process.exit(1);
}

// 3. Replace Purchase effect section with Backpack storage
const oldPurchaseEffect = [
  '\t-- 发放效果',
  '\tlocal effectType = item.EffectType',
  '\tlocal effectValue = item.EffectValue',
  '',
  '\tif effectType == "Stamina" or effectType == "Spirit"',
  '\t\tor effectType == "Fatigue" or effectType == "FirePoison"',
  '\t\tor effectType == "Malice" then',
  '\t\t-- 即时状态：通过 ApplyCosts 处理（支持正/负值）',
  '\t\tlocal costs = {}',
  '\t\tcosts[effectType] = effectValue',
  '\t\tStatusService:ApplyCosts(player, costs)',
  '',
  '\telseif effectType == "AgilityExp" then',
  '\t\tStatusService:AddExp(player, "Agility", effectValue)',
  '',
  '\telseif effectType == "AlchemyExp" then',
  '\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)',
  '',
  '\telseif effectType == "CombatExp" then',
  '\t\tStatusService:AddExp(player, "Combat", effectValue)',
  '',
  '\telseif effectType == "RandomStat" then',
  '\t\tlocal stats = { "Agility", "AlchemyLv", "Combat" }',
  '\t\tlocal chosen = stats[math.random(1, #stats)]',
  '\t\tStatusService:AddExp(player, chosen, effectValue)',
  '\t\tlocal nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }',
  '\t\treturn "Success", "购买成功！" .. (nameMap[chosen] or chosen) .. " +1"',
  '',
  '\telseif effectType == "AllStats" then',
  '\t\tStatusService:AddExp(player, "Agility", effectValue)',
  '\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)',
  '\t\tStatusService:AddExp(player, "Combat", effectValue)',
  '\t\treturn "Success", "购买成功！全属性 +1"',
  '\tend',
  '',
  '\tprint("🛒 " .. player.Name .. " 购买了 " .. (item.RealName or item.Name))',
  '\treturn "Success", "购买成功！获得 " .. (item.RealName or item.Name)',
].join('\n');

const newPurchaseEffect = [
  '\t-- 改为存入背包',
  '\tlocal backpack = data.Backpack or {}',
  '\tbackpack[itemKey] = (backpack[itemKey] or 0) + 1',
  '\tdata.Backpack = backpack',
  '\tDataManager:UpdateField(player, "Backpack", backpack)',
  '',
  '\tprint("🛒 " .. player.Name .. " 购买了 " .. (item.RealName or item.Name) .. "（背包 +1）")',
  '\treturn "Success", "购买成功！" .. (item.RealName or item.Name) .. " 已存入背包"',
].join('\n');

if (content.includes(oldPurchaseEffect)) {
  content = content.replace(oldPurchaseEffect, newPurchaseEffect);
  console.log('OK: Purchase effect section replaced with Backpack');
} else {
  console.log('ERROR: Purchase effect section not matched');
  process.exit(1);
}

// 4. Add UseItem method after Purchase function (before the OnServerEvent section)
const useItemMethod = [
  '',
  '-- ============================================================',
  '-- 使用物品（从背包消耗，应用效果）',
  '-- isMeditating: 打坐状态效果 ×1.5',
  '-- ============================================================',
  'function ShopService:UseItem(player, itemKey, isMeditating)',
  '\tlocal data = DataManager:GetData(player)',
  '\tif not data then return { Success = false, Message = "数据未加载" } end',
  '',
  '\tlocal backpack = data.Backpack or {}',
  '\tlocal count = backpack[itemKey] or 0',
  '\tif count <= 0 then return { Success = false, Message = "背包中没有该物品" } end',
  '',
  '\tlocal item = DanConfig.Items[itemKey]',
  '\tif not item then return { Success = false, Message = "未知物品" } end',
  '',
  '\t-- 消耗背包',
  '\tbackpack[itemKey] = count - 1',
  '\tif backpack[itemKey] <= 0 then backpack[itemKey] = nil end',
  '\tdata.Backpack = backpack',
  '\tDataManager:UpdateField(player, "Backpack", backpack)',
  '',
  '\t-- 应用效果（打坐时 ×1.5）',
  '\tlocal effectValue = item.EffectValue',
  '\tif isMeditating then',
  '\t\teffectValue = math.floor(effectValue * 1.5)',
  '\tend',
  '',
  '\tlocal effectType = item.EffectType',
  '\tif effectType == "Stamina" or effectType == "Spirit"',
  '\t\tor effectType == "Fatigue" or effectType == "FirePoison"',
  '\t\tor effectType == "Malice" then',
  '\t\tlocal costs = {}',
  '\t\tcosts[effectType] = effectValue',
  '\t\tStatusService:ApplyCosts(player, costs)',
  '',
  '\telseif effectType == "AgilityExp" then',
  '\t\tStatusService:AddExp(player, "Agility", effectValue)',
  '\telseif effectType == "AlchemyExp" then',
  '\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)',
  '\telseif effectType == "CombatExp" then',
  '\t\tStatusService:AddExp(player, "Combat", effectValue)',
  '\telseif effectType == "RandomStat" then',
  '\t\tlocal stats = { "Agility", "AlchemyLv", "Combat" }',
  '\t\tlocal chosen = stats[math.random(1, #stats)]',
  '\t\tStatusService:AddExp(player, chosen, effectValue)',
  '\telseif effectType == "AllStats" then',
  '\t\tStatusService:AddExp(player, "Agility", effectValue)',
  '\t\tStatusService:AddExp(player, "AlchemyLv", effectValue)',
  '\t\tStatusService:AddExp(player, "Combat", effectValue)',
  '\tend',
  '',
  '\tprint("💊 " .. player.Name .. " 使用了 " .. (item.RealName or item.Name))',
  '\treturn { Success = true, Message = "使用成功" }',
  'end',
].join('\n');

const marker = '-- ============================================================\n-- 监听客户端请求\n-- ============================================================';
const insertPoint = content.indexOf(marker);
if (insertPoint >= 0) {
  content = content.slice(0, insertPoint) + useItemMethod + '\n\n' + content.slice(insertPoint);
  console.log('OK: UseItem method added');
} else {
  console.log('ERROR: OnServerEvent insert point not found');
  process.exit(1);
}

// 5. Add Backpack to OpenShop response
const oldOpenShop = [
  '\t\t\tShopEvent:FireClient(player, "OpenShop", {',
  '\t\t\t\tItems = items,',
  '\t\t\t\tDailyPurchases = data.DailyPurchases or {},',
  '\t\t\t\tXianJing = data.XianJing or 0,',
  '\t\t\t})',
].join('\n');
const newOpenShop = [
  '\t\t\tShopEvent:FireClient(player, "OpenShop", {',
  '\t\t\t\tItems = items,',
  '\t\t\t\tDailyPurchases = data.DailyPurchases or {},',
  '\t\t\t\tXianJing = data.XianJing or 0,',
  '\t\t\t\tBackpack = data.Backpack or {},',
  '\t\t\t})',
].join('\n');
if (content.includes(oldOpenShop)) {
  content = content.replace(oldOpenShop, newOpenShop);
  console.log('OK: Backpack added to OpenShop response');
} else {
  console.log('ERROR: OpenShop response not found');
  process.exit(1);
}

// 6. Rewrite Bargain:Shop handler
const oldBargainHandler = [
  '\t\t-- 砍价',
  '\t\tif action == "Bargain:Shop" then',
  '\t\t\tlocal itemKey = contextData and contextData.ItemKey',
  '\t\t\tlocal choiceIndex = contextData and contextData.ChoiceIndex',
  '\t\t\tif not itemKey then return end',
  '',
  '\t\t\tlocal result = ShopService:HandleBargain(player, itemKey, choiceIndex)',
  '',
  '\t\t\tShopEvent:FireClient(player, "BargainResult:Shop", {',
  '\t\t\t\tSuccess = result.Success,',
  '\t\t\t\tMessage = result.Message,',
  '\t\t\t\tQuestion = result.Question,',
  '\t\t\t\tOptions = result.Options,',
  '\t\t\t\tQuestionId = result.QuestionId,',
  '\t\t\t})',
  '\t\t\treturn',
  '\t\tend',
].join('\n');
const newBargainHandler = [
  '\t\t-- 砍价（2 步协议：先请求题目，再提交答案）',
  '\t\tif action == "Bargain:Shop" then',
  '\t\t\tlocal itemKey = contextData and contextData.ItemKey',
  '\t\t\tlocal choiceIndex = contextData and contextData.ChoiceIndex',
  '\t\t\tif not itemKey then return end',
  '',
  '\t\t\t-- 检查营业时间',
  '\t\t\tif player:GetAttribute("ShopOpen") == 0 then',
  '\t\t\t\tShopEvent:FireClient(player, "BargainResult", {',
  '\t\t\t\t\tSuccess = false,',
  '\t\t\t\t\tMessage = "仙丹阁已打烊",',
  '\t\t\t\t})',
  '\t\t\t\treturn',
  '\t\t\tend',
  '',
  '\t\t\tif not choiceIndex then',
  '\t\t\t\t-- Step 1: 请求题目',
  '\t\t\t\tlocal result = ShopService:RequestBargainQuestion(player, itemKey)',
  '\t\t\t\tShopEvent:FireClient(player, "BargainQuestion", {',
  '\t\t\t\t\tItemKey = itemKey,',
  '\t\t\t\t\tQuestion = result.Question,',
  '\t\t\t\t\tOptions = result.Options,',
  '\t\t\t\t\tQuestionId = result.QuestionId,',
  '\t\t\t\t})',
  '\t\t\telse',
  '\t\t\t\t-- Step 2: 提交答案',
  '\t\t\t\tlocal result = ShopService:SubmitBargainAnswer(player, itemKey, choiceIndex)',
  '\t\t\t\tShopEvent:FireClient(player, "BargainResult", {',
  '\t\t\t\t\tSuccess = result.Success,',
  '\t\t\t\t\tMessage = result.Message,',
  '\t\t\t\t\tItemKey = itemKey,',
  '\t\t\t\t})',
  '\t\t\tend',
  '\t\t\treturn',
  '\t\tend',
].join('\n');
if (content.includes(oldBargainHandler)) {
  content = content.replace(oldBargainHandler, newBargainHandler);
  console.log('OK: Bargain handler rewritten');
} else {
  console.log('ERROR: Bargain handler not found');
  process.exit(1);
}

// 7. Add UseItem:Shop handler after Bargain:Shop (before the end of OnServerEvent)
const useItemHandler = [
  '',
  '\t\t-- 使用物品',
  '\t\tif action == "UseItem:Shop" then',
  '\t\t\tlocal itemKey = contextData and contextData.ItemKey',
  '\t\t\tlocal isMeditating = contextData and contextData.IsMeditating or false',
  '\t\t\tif not itemKey then return end',
  '',
  '\t\t\tlocal result = ShopService:UseItem(player, itemKey, isMeditating)',
  '',
  '\t\t\tlocal data = DataManager:GetData(player)',
  '\t\t\tShopEvent:FireClient(player, "UseItemResult", {',
  '\t\t\t\tSuccess = result.Success,',
  '\t\t\t\tMessage = result.Message,',
  '\t\t\t\tBackpack = data and data.Backpack or {},',
  '\t\t\t})',
  '\t\t\treturn',
  '\t\tend',
].join('\n');

const useItemMarker = [
  '\t\t\treturn',
  '\t\tend',
  '\tend)',
  '',
  'print("✅ ShopService 已启动")',
].join('\n');
const useItemInsert = [
  '\t\t\treturn',
  '\t\tend',
  '',
  '\t\t-- 使用物品',
  '\t\tif action == "UseItem:Shop" then',
  '\t\t\tlocal itemKey = contextData and contextData.ItemKey',
  '\t\t\tlocal isMeditating = contextData and contextData.IsMeditating or false',
  '\t\t\tif not itemKey then return end',
  '',
  '\t\t\tlocal result = ShopService:UseItem(player, itemKey, isMeditating)',
  '',
  '\t\t\tlocal data = DataManager:GetData(player)',
  '\t\t\tShopEvent:FireClient(player, "UseItemResult", {',
  '\t\t\t\tSuccess = result.Success,',
  '\t\t\t\tMessage = result.Message,',
  '\t\t\t\tBackpack = data and data.Backpack or {},',
  '\t\t\t})',
  '\t\t\treturn',
  '\t\tend',
  '\tend)',
  '',
  'print("✅ ShopService 已启动")',
].join('\n');

if (content.includes(useItemMarker)) {
  content = content.replace(useItemMarker, useItemInsert);
  console.log('OK: UseItem handler added');
} else {
  console.log('ERROR: UseItem handler insert point not found');
  process.exit(1);
}

fs.writeFileSync(filePath, content, 'utf-8');
console.log('DONE: All changes applied to ShopService.server.lua');
