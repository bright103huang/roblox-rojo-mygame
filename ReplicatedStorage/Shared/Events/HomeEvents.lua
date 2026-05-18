-- ReplicatedStorage/Shared/Events/HomeEvents.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	if RunService:IsServer() then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "Events"
		eventsFolder.Parent = ReplicatedStorage
	else
		eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	end
end

local HomeEvent = eventsFolder:FindFirstChild("HomeEvent")
if not HomeEvent then
	if RunService:IsServer() then
		HomeEvent = Instance.new("RemoteEvent")
		HomeEvent.Name = "HomeEvent"
		HomeEvent.Parent = eventsFolder
	else
		HomeEvent = eventsFolder:WaitForChild("HomeEvent", 10)
	end
end

return HomeEvent
