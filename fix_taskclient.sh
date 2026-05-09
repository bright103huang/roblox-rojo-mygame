#!/bin/bash
FILE="C:/Users/lenovo/Desktop/MyGame/StarterPlayer/StarterPlayerScripts/Client/TaskClient.local.luau"
T=$'\t'

# Replace lines 287-293: single Pickup entry → array support
sed -i '287,293d' "$FILE"

# Insert new lines after line 286
sed -i '286a\
'"${T}${T}if areas.Pickup then"'
'"${T}${T}${T}-- 支持数组格式（多个同任务Pickup区域）和单表格式"'
'"${T}${T}${T}local pickupList = areas.Pickup.PartName and { areas.Pickup } or areas.Pickup"'
'"${T}${T}${T}for _, entry in ipairs(pickupList) do"'
'"${T}${T}${T}${T}partMap[entry.PartName] = {"'
'"${T}${T}${T}${T}${T}TaskName = taskName,"'
'"${T}${T}${T}${T}${T}ActionType = entry.FireAction or \"Pick\","'
'"${T}${T}${T}${T}${T}AreaCfg = entry,"'
'"${T}${T}${T}${T}}"'
'"${T}${T}${T}end"'
'"${T}${T}end"' "$FILE"

echo "Done"
