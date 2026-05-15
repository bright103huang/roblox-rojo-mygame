-- ReplicatedStorage/Shared/Events/HomeEvents.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local HomeEvent = eventsFolder:FindFirstChild("HomeEvent")
if not HomeEvent then
	HomeEvent = Instance.new("RemoteEvent")
	HomeEvent.Name = "HomeEvent"
	HomeEvent.Parent = eventsFolder
end

return HomeEvent
